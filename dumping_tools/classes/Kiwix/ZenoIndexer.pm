package Kiwix::ZenoIndexer;

use strict;
use warnings;
use Data::Dumper;
use Kiwix::PathExplorer;
use Kiwix::MimeDetector;
use DBI qw(:sql_types);
use Cwd 'abs_path';
use HTML::Clean;

my $logger;
my $indexerPath;
my $htmlPath;
my $zenoFilePath;
my $dbh;

my @files;

my $mimeDetector;

my %mimeTypes = (
    "text/html" => 0,
    "text/plain" => 1,
    "image/jpeg" => 2,
    "image/png" => 3,
    "image/tiff" => 4,
    "text/css" => 5,
    "image/gif" => 6,
    "application/javascript" => 8,
    "image/icon" => 9 
    );

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    $self->mimeDetector(new Kiwix::MimeDetector());

    return $self;
}

sub fillDatabase {
    my $self = shift;

    $self->log("info", "List files in the directory ".$self->htmlPath());
    my $explorer = new Kiwix::PathExplorer();
    $explorer->path($self->htmlPath());
    while (my $file = $explorer->getNext()) {
	push(@files, $file);
    }

    $self->log("info", "Remove unwanted files in the directory ".$self->htmlPath());
    $self->removeUnwantedFiles();

    my @filesWithInformations;
    $self->log("info", "Analyze file by file");
    foreach my $file (@files) {
	push (@filesWithInformations, $self->analyzeFile($file));
    }

    @files = @filesWithInformations;
}

sub buildZenoFile {
    my $self = shift;
    my $dbFile = shift;
    my $indexerPath = $self->indexerPath();
    my $zenoFilePath = $self->zenoFilePath();

    # call the zeno indexer
    `$indexerPath -s 1024 -C 100000 --db "sqlite:$dbFile" $zenoFilePath`;
}

sub executeSql {
    my $self = shift;
    my $sql = shift;
    
    $self->dbh()->do($sql);
    if ($self->dbh()->err()) { die "$DBI::errstr\n"; }
}

sub buildDatabase {
    my $self = shift;
    my $db = shift;

    $self->log("info", "Write to Database ".$db);

    # remove old database
    unlink($db);

    # connect to the db
    $self->dbh(DBI->connect("dbi:SQLite:dbname=".$db,"","", {AutoCommit => 0, PrintError => 1}));
    $self->dbh()->{unicode} = 1;

    # create article table
    $self->executeSql("
create table article
(
  aid          integer primary key autoincrement,
  namespace    text    not null,
  title        text    not null,
  url          text    not null,
  redirect     text,     -- title of redirect target
  mimetype     integer,
  data         bytea
 )");
    $self->executeSql("create index article_ix1 on article(namespace, title)");

    # create zenofile table
    $self->executeSql("
create table zenofile
(
  zid          integer primary key autoincrement,
  filename     text    not null
 )");

    # create table zenodata
    $self->executeSql("
create table zenodata
(
  zid          integer not null,
  did          integer not null,
  data         bytea not null,
  primary key (zid, did)
)");

    # create zenoarticles table
    $self->executeSql("
create table zenoarticles
(
  zid          integer not null,
  aid          integer not null,
  sort         integer,
  direntlen    bigint,
  datapos      bigint,
  dataoffset   bigint,
  datasize     bigint,
  did          bigint,

  primary key (zid, aid),
  foreign key (zid) references zenofile,
  foreign key (aid) references article
 )");

    # create indexes
    $self->executeSql("create index zenoarticles_ix1 on zenoarticles(zid, direntlen)");
    $self->executeSql("create index zenoarticles_ix2 on zenoarticles(zid, sort)");

    # fill the zenofile table
    $self->executeSql("insert into zenofile (filename) values ('".$self->zenoFilePath()."')");

    # fill the article table
    $self->fillDatabase();

    # fill the zenoarticle table
    $self->executeSql("insert into zenoarticles (zid, aid) select 1, aid from article");

    # commit und disconnect
    $self->dbh()->commit();
    $self->dbh()->disconnect();
}

sub analyzeFile {
    my $self = shift;
    my $file = shift;

    $self->log("info", "Analyze ".$file);

    my %hash;
    my $data = $self->readFile($file);

    # url
    $hash{url} = substr($file, length($self->htmlPath()) + 1);
   
    # mime-type
    $hash{mimetype} = $self->mimeDetector()->getMimeType($file);

    # namespace
    if ($hash{mimetype} eq "text/html") {
	$hash{namespace} = 0;
    } else {
	$hash{namespace} = 6;
    }
    
    # title
    if ($hash{mimetype} eq "text/html") {
	if ($data =~ /<title>(.*)<\/title>/mi ) {
	    $hash{title} = $1;
	}
    }
    if (!$hash{title}) {
	$hash{title} = $hash{url};
    }

    # data
    if ($hash{mimetype} eq "text/html__") {
	my $oldData = $data;
	my $cleaner = new HTML::Clean(\$oldData);
	if ($cleaner) {
	    $cleaner->compat();

	    if ($data =~ /\<pre\>/gmi ) {
		$cleaner->strip( { "whitespace"  => 0 } );
	    } else {
		$cleaner->strip();
	    }
	    $data = \$cleaner->data();
	}
    }
    $hash{data} = $data;

    my $sql = "insert into article (namespace, title, url, redirect, mimetype, data) values (?, ?, ?, ?, ?, ?)";
    my $sth = $self->dbh()->prepare($sql);

    $sth->bind_param(1, $hash{namespace});
    $sth->bind_param(2, $hash{title});
    $sth->bind_param(3, $hash{url});
    $sth->bind_param(4, $hash{redirect});
    $sth->bind_param(5, $mimeTypes{ $hash{mimetype} });
    $sth->bind_param(6, $hash{data}, SQL_BLOB);
    
    $sth->execute();
    if ($self->dbh()->err()) { die "$DBI::errstr\n"; }
    
    return \%hash;
}

sub removeUnwantedFiles {
    my $self = shift;
    my @selectedFiles;
    foreach my $file (@files) {
	unless ($self->ignoreFile($file)) {
	    push(@selectedFiles, $file);
	}
    }
    @files = @selectedFiles;
}

sub ignoreFile {
    my $self = shift;
    my $file = shift;

    if ( $file =~ /^.*\.htm$/i || $file =~ /^.*\.html$/i || 
	 $file =~ /^.*\.jpeg$/i || $file =~ /^.*\.jpg$/i ||
	 $file =~ /^.*\.png$/i || $file =~ /^.*\.css$/i ||
	 $file =~ /^.*\.svg$/i || $file =~ /^.*\.js$/i 
	 ) 
    {
	return 0;
    }

    return 1;
}

sub readFile {
    my $self = shift;
    my $path = shift;
    my $data = "";

    open FILE, $path or die "Couldn't open file: $path"; 
    while (<FILE>) {
	$data .= $_;
    }
    close FILE;

    return $data;
}

sub htmlPath {
    my $self = shift;
    if (@_) { 
	$htmlPath = abs_path(shift) ;
	if (! substr($htmlPath, length($htmlPath)-1) eq "/" ) {
	    $htmlPath = $htmlPath + "/";
	}
    } 
    return $htmlPath;
}

sub zenoFilePath {
    my $self = shift;
    if (@_) { $zenoFilePath = shift } 
    return $zenoFilePath;
}

sub dbh {
    my $self = shift;
    if (@_) { $dbh = shift } 
    return $dbh;
}

sub indexerPath {
    my $self = shift;
    if (@_) { $indexerPath = shift } 
    return $indexerPath;
}

sub logger {
    my $self = shift;
    if (@_) { 
	$logger = shift;
	$self->mimeDetector->logger($logger);
    } 
    return $logger;
}

sub mimeDetector {
    my $self = shift;
    if (@_) { $mimeDetector = shift } 
    return $mimeDetector;
}

sub log {
    my $self = shift; 
   return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
