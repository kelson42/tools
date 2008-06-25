package Kiwix::ZenoIndexer;

use Data::Dumper;
use File::Find;
use Kiwix::MimeDetector;
use DBI;
use Cwd 'abs_path';

my $logger;
my $indexerPath;
my $htmlPath;
my $zenoFilePath;

my @files;

my $mimeDetector;

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
       my $sql = "insert into article (namespace, title, url, compression, data) 
    values (?, ?, ?, ?, ?)";
       my $sth = $dbh->prepare($sql);
       $sth->execute($hash->{namespace}, $hash->{title}, $hash->{url}, $hash->{compression}, $hash->{data});
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
    $hash{path} = $file;
    $hash{data} = $self->readFile($file)."\n";
    $hash{mimetype} = $self->mimeDetector()->getMimeType($file);

    if ($hash{mimetype} eq "text/html") {
	$hash{namespace} = 0;
    } else {
	$hash{namespace} = 6;
    }

    $hash{compression} = 0;

    if ($hash{mimetype} eq "text/html") {
	if ($hash{data} =~ /<title>(.*)<\/title>/mi ) {
	    $hash{title} = $1;
	}
    }
    if (!$hash{title}) {
	    $hash{title} = $file;
    }

    $hash{url} = substr($file, length($self->htmlPath()) + 1);

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

sub logger {
    my $self = shift;
    if (@_) { $logger = shift } 
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
