package Kiwix::ZenoIndexer;

use strict;
use warnings;
use Data::Dumper;
use Kiwix::PathExplorer;
use Kiwix::MimeDetector;
use Kiwix::UrlRewriter;
use HTML::LinkExtor;
use HTML::LinkExtractor;
use URI::Escape;
use Math::BaseArith;
use DBI qw(:sql_types);
use Cwd 'abs_path';
use DBD::Pg;

my $logger;
my $indexerPath;
my $htmlPath;
my $zenoFilePath;
my $dbHandler;
my $dbType = "postgres"; # or sqlite
my $dbName;
my %urls;
my @files;
my $file;
my $htmlFilterRegexp = "^.*\.(html|htm)\$";
my $jsFilterRegexp = "^.*\.(js)\$";
my $cssFilterRegexp = "^.*\.(css)\$";

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

sub prepareUrlRewriting {
    my $self = shift;
    $self->getUrlCounts();
    $self->checkDeadUrls();
    $self->computeNewUrls();
}

sub getUrlCounts {
    my $self = shift;

    my $explorer = new Kiwix::PathExplorer();
    $explorer->path($self->htmlPath());

    while (my $file = $explorer->getNext()) {
	# push the file itself
	$self->incrementCount(substr($file, length($self->htmlPath())));

	unless ($file =~ /$htmlFilterRegexp/i ) {
	    next;
	}

	$self->log("info", "Count links in the (x)html file ".$file);

	# push the link contained in the file
	my $linkExtractor = HTML::LinkExtor->new();
	my $links = $linkExtractor->parse_file($file)->{links};
	foreach my $link (@$links) {
	    my $url = $link->[2];
	    if (isLocalUrl($url) && !isSelfUrl($url)) {
		$url = removeLocalTagFromUrl($url);
		$self->incrementCount(getAbsoluteUrl($file, $self->htmlPath(), $url));
	    }
	}
    }

    $explorer->reset();
}

sub checkDeadUrls {
    my $self = shift;
    
    foreach my $url (keys(%urls)) {
	unless (-f $self->htmlPath().$url) {
	    $self->log("error", "[".$self->htmlPath()."]".$url." is a dead url. It should be removed.");
	}
    }
}

sub computeNewUrls {
    my $self = shift;
    my @urls = keys(%urls);

    # Sort urls
    $self->log("info", "Sorting ".scalar(@urls)." urls.");
    my @sortedUrls = sort { $urls{$b} <=> $urls{$a} } (@urls);

    # new url base
    my $baseString = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    my $baseSize = length($baseString);

    my @baseString;
    for (my $i=0; $i<$baseSize; $i++) {
	push(@baseString, substr($baseString, $i, 1));
    }

    my @base;
    for (my $i=0; $i<$baseSize; $i++) {
	push(@base, $baseSize);
    }

    # compute the new url
    $self->log("info", "Computing new urls.");
    my $nameIndex=0;
    foreach my $url (@sortedUrls) {
	$nameIndex++;
	my @newUrl = encode( $nameIndex, \@base );
	my $newUrl = "";
	my $trail = 1;

	foreach (@newUrl) {
	    if ($trail) {
		if ($_ == 0) {
		    next;
		} else {
		    $trail = 0;
		}
	    }

	    $newUrl .= $baseString[$_];
	}

	$urls{$url} = $newUrl;
    }
}

sub getNamespace {
    my $file = shift;

    if ($file =~ /$htmlFilterRegexp/i) {
	return "0";
    } elsif ($file =~ /$cssFilterRegexp/i || $file =~ /$jsFilterRegexp/i) {
	return "8";
    } else {
	return "6";
    }
}

sub getAbsoluteUrl {
    my $file = shift;
    my $path = shift;
    my $url = shift;
    my $i;

    if ( $url =~ /^\/.*$/ ) {
	return $url;
    }

    $file = substr($file, length($htmlPath) );
    $url =~ s/^\.\///mg ;
    $url =~ s/\/\///mg ;
    
    my @fileParts = split(/\//, $file);
    my @urlParts = split(/\//, $url);
    
    my $offset = scalar(@fileParts) - 1;

    $i = 0;
    while ($i < scalar(@urlParts) && $urlParts[$i++] eq "..") {
	$offset -= 1;
    }

    my $newUrl = "";
    for ($i=0; $i<$offset; $i++) {
	$newUrl .= $fileParts[$i] . "/";
    }

    for ($i=0; $i<scalar(@urlParts); $i++) {
	unless ($urlParts[$i] eq ".." ) {
	    $newUrl .= $urlParts[$i];

	    if ($i < scalar(@urlParts) - 1) {
		$newUrl .=  "/";
	    }
	}
    }
    
    return $newUrl;
}

sub incrementCount {
    my $self = shift;
    my $url = shift;

    $url = uri_unescape($url);

    if (exists($urls{$url})) {
	$urls{$url} += 1;
    } else {
	$urls{$url} = 1;
    }
}

sub isLocalUrl {
    my $url = shift;
    $url =~ /^[\w]{1,8}\:\/\/.*$/ ? 0 : 1 ;
}

sub removeLocalTagFromUrl {
    my $url = shift;

    $url =~ s/^[^\#]*(\#.*)$// ;

    return $url;
}

sub isSelfUrl {
    my $url = shift;
    $url =~ /^\#.*$/ ? 1 : 0 ;
}

sub fillDb {
    my $self = shift;
    my $file;

    $self->log("info", "List files in the directory ".$self->htmlPath());
    my $explorer = new Kiwix::PathExplorer();
    $explorer->path($self->htmlPath());
    $explorer->filterRegexp("");
  
    while ($file = $explorer->getNext()) {
	push(@files, $file);
    }

    $self->log("info", "Remove unwanted files in the directory ".$self->htmlPath());
    $self->removeUnwantedFiles();

    $self->log("info", "Copying files to the DB (".scalar(@files)." files)");

    my $count = 0;
    foreach $file (@files) {
	$self->copyFileToDb($file);
    }

    $self->dbHandler()->commit();
}

sub buildZenoFile {
    my $self = shift;
    my $dbName = $self->dbName();
    my $indexerPath = $self->indexerPath();
    my $zenoFilePath = $self->zenoFilePath();

    my $command;
    if ($self->isSqliteDb()) {
	$command = "$indexerPath -s 1024 -C 100000 --db \"sqlite:$dbName\" $zenoFilePath";
    } else {
	$command = "$indexerPath -s 1024 -C 100000 --db \"postgresql:dbname=$dbName user=kiwix\" $zenoFilePath";
    }

    # call the zeno indexer
    $self->log("info", "Creating the zeno file : $command");
    `$command`;
}

sub executeSql {
    my $self = shift;
    my $sql = shift;
    
    $self->dbHandler()->do($sql);
    if ($self->dbHandler()->err()) { die "$DBI::errstr\n"; }
}

# identify database type
sub isPostgresDb {
    my $self = shift;
    return $self->dbType() eq "postgres";
}

sub isSqliteDb {
    my $self = shift;
    return $self->dbType() eq "sqlite";
}

# create database
sub createSqliteDbSchema {
    my $self = shift;

    # create article table
    $self->executeSql("
create table article
(
  aid          integer primary key autoincrement,
  namespace    text    not null,
  title        text    not null,
  url          text,
  redirect     text,     -- title of redirect target
  mimetype     integer,
  data         bytea
)
");
    $self->executeSql("create index article_ix1 on article(namespace, title)");

    # create category tables
$self->executeSql("
create table category
(
  cid          integer primary key autoincrement,
  title        text    not null,
  description  bytea   not null
)
");

$self->executeSql("
create table categoryarticles
(
  cid          integer not null,
  aid          integer not null,
  primary key  (cid, aid),
  foreign key  (cid) references category,
  foreign key  (aid) references article
)
");

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
  parameter    bytea,

  primary key (zid, aid),
  foreign key (zid) references zenofile,
  foreign key (aid) references article
 )");

    # create indexes
    $self->executeSql("create index zenoarticles_ix1 on zenoarticles(zid, direntlen)");
    $self->executeSql("create index zenoarticles_ix2 on zenoarticles(zid, sort)");

    # create search engine tables
    $self->executeSql("
create table indexarticle
(
  zid          integer not null,
  xid          integer not null,
  namespace    text    not null,
  title        text    not null,
  data         bytea,
  sort         integer,
  direntlen    bigint,
  datapos      bigint,
  dataoffset   bigint,
  datasize     bigint,
  did          bigint,
  parameter    bytea,

  primary key (zid, namespace, title),
  foreign key (zid) references zenofile
)
");

$self->executeSql("create index indexarticle_ix1 on indexarticle(zid, xid)") ;
$self->executeSql("create index indexarticle_ix2 on indexarticle(zid, sort)");

$self->executeSql("
create table words
(
  word     text not null,
  pos      integer not null,
  aid      integer not null,
  weight   integer not null,

  primary key (word, aid, pos),
  foreign key (aid) references article
)") ;

$self->executeSql("create index words_ix1 on words(aid)");

$self->executeSql("
create table trivialwords
(
  word     text not null primary key
)");


}

sub createPostgresDbSchema {
    my $self = shift;

    # create article table
    $self->executeSql("
create table article
(
  aid          serial  not null primary key,
  namespace    text    not null,
  title        text    not null,
  url          text,
  redirect     text,     -- title of redirect target
  mimetype     integer,
  data         bytea
)");

$self->executeSql("create unique index article_ix1 on article(namespace, title)");

$self->executeSql("
create table category
(
  cid          serial  not null primary key,
  title        text    not null,
  description  bytea   not null
)");

$self->executeSql("
create table categoryarticles
(
  cid          integer not null,
  aid          integer not null,
  primary key (cid, aid),
  foreign key (cid) references category,
  foreign key (aid) references article
)");

$self->executeSql("
create table zenofile
(
  zid          serial  not null primary key,
  filename     text    not null
)");

$self->executeSql("
create table zenodata
(
  zid          integer not null,
  did          integer not null,
  data         bytea not null,
  primary key (zid, did)
)");

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
  parameter    bytea,

  primary key (zid, aid),
  foreign key (zid) references zenofile,
  foreign key (aid) references article
)");

$self->executeSql("create index zenoarticles_ix1 on zenoarticles(zid, direntlen)");
$self->executeSql("create index zenoarticles_ix2 on zenoarticles(zid, sort)");

$self->executeSql("
create table indexarticle
(
  zid          integer not null,
  xid          serial  not null,
  namespace    text    not null,
  title        text    not null,
  data         bytea,
  sort         integer,
  direntlen    bigint,
  datapos      bigint,
  dataoffset   bigint,
  datasize     bigint,
  did          bigint,
  parameter    bytea,

  primary key (zid, namespace, title),
  foreign key (zid) references zenofile
)");

$self->executeSql("create index indexarticle_ix1 on indexarticle(zid, xid)");
$self->executeSql("create index indexarticle_ix2 on indexarticle(zid, sort)");

$self->executeSql("
create table words
(
  word     text not null,
  pos      integer not null,
  aid      integer not null,
  weight   integer not null, -- 0: title/header, 1: subheader, 3: paragraph

  primary key (word, aid, pos),
  foreign key (aid) references article
)");

$self->executeSql("create index words_ix1 on words(aid)");

$self->executeSql("
create table trivialwords
(
  word     text not null primary key
)");

}

sub createDbSchema {
    my $self = shift;

    if ($self->isPostgresDb()) {
	$self->createPostgresDbSchema();
    } elsif ($self->isSqliteDb) {
	$self->createSqliteDbSchema();
    } else {
	die ("'".$self->dbType()."' is not a valid dbtype, should be 'postgresql' or 'sqlite'."); 
    }
}

# create database
sub createDb {
    my $self = shift;
    my $dbName = $self->dbName();
    
    if ($self->isPostgresDb()) {
	`createdb -U kiwix $dbName`;
    }
}

# delete database
sub deleteSqliteDb {
    my $self = shift;
    unlink($self->dbName());
}

sub deletePostgresDb {
    my $self = shift;
    my $dbName = $self->dbName();
    `dropdb -U kiwix $dbName`;
}

sub deleteDb {
    my $self = shift;

    if ($self->isSqliteDb()) {
	$self->deleteSqliteDb();
    } else {
	$self->deletePostgresDb();
    }
}

# connect to database
sub connectToDb {
    my $self = shift;
    my $dbName = $self->dbName();

    if ($self->isSqliteDb()) {
	$self->dbHandler(DBI->connect("dbi:SQLite:dbname=".$dbName,"","", {AutoCommit => 0, PrintError => 1}));
    } else {
	$self->dbHandler(DBI->connect("dbi:Pg:dbname=".$dbName, "kiwix","", {AutoCommit => 0, PrintError => 1}));
    }

    # set unicode flag
    $self->dbHandler()->{unicode} = 1;
}

sub buildDatabase {
    my $self = shift;
    my $dbName = $self->dbName();

    $self->log("info", "Will create and fill the '".$self->dbType()."' database '".$dbName."'.");

    # remove old database
    $self->deleteDb();

    # create database
    $self->createDb();
    
    # connect to the db
    $self->connectToDb();

    # create db schema
    $self->createDbSchema();
    $self->dbHandler()->commit();

    # fill the zenofile table
    $self->executeSql("insert into zenofile (filename) values ('".$self->zenoFilePath()."')");
    $self->dbHandler()->commit();

    # fill the article table
    $self->fillDb();
    $self->dbHandler()->commit();

    # fill the zenoarticle table
    $self->executeSql("insert into zenoarticles (zid, aid) select 1, aid from article");
    $self->dbHandler()->commit();

    # commit und disconnect
    $self->dbHandler()->disconnect();
}

sub copyFileToDb {
    my $self = shift;
    $file = shift;

    my %hash;
    my $data = $self->readFile($file);

    # url
    if (scalar(%urls)) {
	$hash{url} = $urls{substr($file, length($self->htmlPath()))};
	unless ($hash{url}) {
	    die ("Not url found for file".$file);
	}
    } else {
	$hash{url} = substr($file, length($self->htmlPath()));
    }

    # mime-type
    $hash{mimetype} = $self->mimeDetector()->getMimeType($file);

    # namespace
    $hash{namespace} = getNamespace($file);
    
    # title
    if ($hash{mimetype} eq "text/html") {
	if ($data =~ /<title>(.*)<\/title>/mi ) {
	    $hash{title} = $1;
	}
    }

    if (!$hash{title}) {
	$hash{title} = $hash{url};
    }

    # url is deprecated
    $hash{title} = $hash{url};

    # url rewrite callback
    sub urlRewriterCallback {
	my $url = shift;
	$url = uri_unescape($url);
	
	if (isLocalUrl($url) && !isSelfUrl($url)) {
	    my $absUrl;
	    
	    if ($url =~ /\#/ ) {
		$absUrl = getAbsoluteUrl($file, $htmlPath, removeLocalTagFromUrl($url));
	    } else  {
		$absUrl = getAbsoluteUrl($file, $htmlPath, $url);
	    }
	    
	    my $newUrl = "/".getNamespace($absUrl)."/".$urls{$absUrl};
	    
	    if ($url =~ /\#/ ) {
		my @urlParts = split( /\#/, $url );
		$newUrl .= "#".$urlParts[1];
	    }
	    
	    return $newUrl;
       } else {
	   return $url;
       }
    }
    
    # redirect
    my $linkExtractor = HTML::LinkExtractor->new();
    $linkExtractor->parse(\$data);
    my $links = $linkExtractor->links();
    foreach my $link (@$links) {
	next unless (exists($link->{'http-equiv'}) && $link->{'http-equiv'} =~ /Refresh/i );
	my $target = urlRewriterCallback($link->{'url'});
	$target =~ s/\/[\d]+\/// ;
	$hash{redirect} = $target;
	last;
    }

    # rewriting (for HTML)
    if (!$hash{redirect} && $hash{mimetype} eq "text/html" && scalar(%urls)) {
	$self->log("info", "Rewriting url in ".$file);
	
	my $rewriter = new Kiwix::UrlRewriter(\&urlRewriterCallback);
	$data = $rewriter->resolve($data);
    }

    # data
    if (!$hash{redirect}) {
	$hash{data} = $data;
    }
    
    $self->log("info", "Adding to DB ".$file);
    my $sql = "insert into article (namespace, title, url, redirect, mimetype, data) values (?, ?, ?, ?, ?, ?)";
    my $sth = $self->dbHandler()->prepare($sql);

    # check empty data for non redirect articles
    if (!$hash{redirect} && !$hash{data}) {
	$self->log("info", "'".$file."' is an empty file, will be skiped.");
	return;
    }

    $sth->bind_param(1, $hash{namespace});
    $sth->bind_param(2, $hash{title});
    $sth->bind_param(3, $hash{url});
    $sth->bind_param(4, $hash{redirect});
    $sth->bind_param(5, $mimeTypes{ $hash{mimetype} });
    
    if ($self->isSqliteDb()) {
	$sth->bind_param(6, $hash{data}, SQL_BLOB);
    } elsif ($self->isPostgresDb()) {
	$sth->bind_param(6, $hash{data}, { pg_type => DBD::Pg::PG_BYTEA } );
    }
    
    $sth->execute();
    if ($self->dbHandler()->err()) { die "$DBI::errstr\n"; }
    
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
	if (! (substr($htmlPath, length($htmlPath)-1) eq "/" )) {
	    $htmlPath .= "/";
	}
    } 
    return $htmlPath;
}

sub zenoFilePath {
    my $self = shift;
    if (@_) { $zenoFilePath = shift } 
    return $zenoFilePath;
}

sub dbName {
    my $self = shift;
    if (@_) { $dbName = shift } 
    return $dbName;
}

sub dbHandler {
    my $self = shift;
    if (@_) { $dbHandler = shift } 
    return $dbHandler;
}

sub dbType {
    my $self = shift;
    if (@_) { $dbType = shift } 
    return $dbType;
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
