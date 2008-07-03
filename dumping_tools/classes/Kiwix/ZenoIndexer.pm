package Kiwix::ZenoIndexer;

use strict;
use warnings;
use Data::Dumper;
use File::Find;
use Kiwix::MimeDetector;
use DBI qw(:sql_types);
use Cwd 'abs_path';
use IO::Compress::Deflate;
use HTML::Clean;

my $logger;
my $indexerPath;
my $htmlPath;
my $zenoFilePath;
my $textCompression;

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

sub exploreHtmlPath {
    my $self = shift;

    $self->log("info", "List files in the directory ".$self->htmlPath());
    find(\&getFiles, $self->htmlPath());

    $self->log("info", "Remove unwanted files in the directory ".$self->htmlPath());
    $self->removeUnwantedFiles();

    my @filesWithInformations;
    $self->log("info", "Analyze file by file");
    foreach my $file (@files) {
	push (@filesWithInformations, $self->analyzeFile($file));
    }

    @files = @filesWithInformations;
}

sub buildDatabase {
    my $self = shift;
    my $db = shift;

    sub executeSql {
	my $dbh = shift;
	my $sql = shift;

	$dbh->do($sql);
	if ($dbh->err()) { die "$DBI::errstr\n"; }
    }

    $self->log("info", "Write to Database ".$db);
    # remove old database
    unlink($db);

    # connect to the db
    my $dbh = DBI->connect("dbi:SQLite:dbname=".$db,"","", {AutoCommit => 0, PrintError => 1});
    $dbh->{unicode} = 1;

    # create article table
    executeSql($dbh, "
create table article
(
  aid          integer primary key autoincrement,
  namespace    text    not null,
  title        text    not null,
  url          text    not null,
  redirect     text,     -- title of redirect target
  mimetype     integer,
  data         bytea,
  compression  integer   -- 0: unknown/not specified, 1: none, 2: zip
 )");
    executeSql($dbh, "create index article_ix1 on article(namespace, title)");

    # create zenofile table
    executeSql($dbh, "
create table zenofile
(
  zid          integer primary key autoincrement,
  filename     text    not null,
  count        integer
 )");

    # create zenoarticles table
    executeSql($dbh, "
create table zenoarticles
(
  zid          integer not null,
  aid          integer not null,
  direntpos    bigint,
  datapos      bigint,

  primary key (zid, aid),
  foreign key (zid) references zenofile,
  foreign key (aid) references article
 )");

    # fill the zenofile table
    executeSql($dbh, "insert into zenofile (filename) values ('".$self->zenoFilePath()."')");

    # fill the article table
    foreach my $hash (@files) {

       my $sql = "insert into article (namespace, title, url, redirect, mimetype, data, compression) 
    values (?, ?, ?, ?, ?, ?, ?)";
       my $sth = $dbh->prepare($sql);

       $sth->bind_param(1, $hash->{namespace});
       $sth->bind_param(2, $hash->{title});
       $sth->bind_param(3, $hash->{url});
       $sth->bind_param(4, $hash->{redirect});
       $sth->bind_param(5, $mimeTypes{ $hash->{mimetype} });
       $sth->bind_param(6, $hash->{data}, SQL_BLOB);
       $sth->bind_param(7, $hash->{compression});

       $sth->execute();

       if ($dbh->err()) { die "$DBI::errstr\n"; }
    }

    # fill the zenoarticle table
    executeSql($dbh, "insert into zenoarticles (zid, aid) select 1, aid from article");

    # commit und disconnect
    $dbh->commit();
    $dbh->disconnect();
}

sub getFiles {
    push(@files, $File::Find::name);
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

    # compression
    if ($self->textCompression eq "gzip") {
	if ($hash{mimetype} =~ /^text\/.*/) {
	    $hash{compression} = 2;
	}
	else {
	    $hash{compression} = 1;
	}
    } else {
	$hash{compression} = 1;
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
    if ($hash{mimetype} eq "text/html") {
	my $oldData = $data;
	my $cleaner = new HTML::Clean(\$oldData);
	if ($cleaner) {
	    $cleaner->compat();

	    if ($data =~ /\<pre\>/gmi ) {
		$cleaner->strip( { "whitespace"  => 0 } );
	    } else {
		$cleaner->strip();
	    }
	    $data = $cleaner->data();
	}
    }

    if ($hash{compression} == 1) {
	$hash{data} = $data;
    } elsif ($hash{compression} == 2) {
	my $compressor = new IO::Compress::Deflate(\$hash{data}, {-Level => IO::Compress::Deflate::Z_BEST_COMPRESSION } );
	$compressor->write($data);
	$compressor->flush();
    } else {
	$hash{data} = $data;
    }

    # redirect
    # $hash{redirect} = 0;
    
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

sub indexerPath {
    my $self = shift;
    if (@_) { $indexerPath = shift } 
    return $indexerPath;
}

sub textCompression {
    my $self = shift;
    if (@_) { $textCompression = shift } 
    return $textCompression;
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
