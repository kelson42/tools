#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::ZimWriter;
use Whereis;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("builZimFileFromDirectory.pl");

# get the params
my $writerPath;
my $htmlPath;
my $welcomePage;
my $zimFilePath="./articles";
my $dbType="postgres";
my $dbUser="kiwix";
my $dbHost="localhost";
my $dbPort="5433";
my $dbPassword="";
my $rewriteCDATA;
my $mediawikiOptim;
my $dbName=time();

# Get console line arguments
GetOptions('writerPath=s' => \$writerPath, 
	   'htmlPath=s' => \$htmlPath,
	   'zimFilePath=s' => \$zimFilePath,
	   'dbName=s' => \$dbName,
	   'dbPort=s' => \$dbPort,
	   'dbHost=s' => \$dbHost,
	   'dbUser=s' => \$dbUser,
	   'dbPassword=s' => \$dbPassword,
	   'mediawikiOptim' => \$mediawikiOptim,
	   'rewriteCDATA' => \$rewriteCDATA,
	   'welcomePage=s' => \$welcomePage,
	   );

if (!$htmlPath || !$welcomePage ) {
    print "usage: ./builZimFileFromDirectory.pl --htmlPath=./html --welcomePage=index.html [--dbUser=foobar] [--dbPassword=testpass] [--writerPath=./zimWriter] [--zimFilePath=articles.zim] [--dbName=kiwix_db] [--dbPort=5433] [==dbHost=localhost] [--rewriteCDATA] [--mediawikiOptim]\n";
    exit;
}

# try to detect the zimwriter path or test it (if given)
if ($writerPath) {
    unless (-x $writerPath) {
	$logger->error("The zim writer '$writerPath' does not exist or is not executable.");
	exit;
    }
} else {
    $writerPath = whereis("zimwriter");
}

# test the html directory
unless (-d $htmlPath) {
    $logger->error("The html directory '$htmlPath' does not exist.");
    exit;
}

# remove the ".zim" at the end of the zimFilePath
$zimFilePath =~ s/\.zim$//;

# check welcome page format
if (substr($welcomePage, 0, 1) eq '.' || substr($welcomePage, 0, 1) eq '/') {
    print(STDERR "The welcomePage parameter is a path relative to the htmlPath parameter. It can not start with '.' or a '/'.\n");
    exit;
}

# check if the welcomePage exists
unless ( -f $htmlPath."/".$welcomePage) {
    print(STDERR "The file '$htmlPath$welcomePage' does not exist.\n");
    exit;    
}

# initialization
my $writer = Kiwix::ZimWriter->new();
$writer->logger($logger);
$writer->writerPath($writerPath);
$writer->htmlPath($htmlPath);
$writer->zimFilePath($zimFilePath);
$writer->dbType($dbType);
$writer->dbName($dbName);
$writer->dbUser($dbUser);
$writer->dbPort($dbPort);
$writer->dbHost($dbHost);
$writer->dbPassword($dbPassword);
$writer->welcomePage($welcomePage);
$writer->mediawikiOptim($mediawikiOptim);
$writer->rewriteCDATA($rewriteCDATA);

# prepare urls rewreting
$logger->info("Starting ZIM building process.");
$writer->prepareUrlRewriting();

# loads the data from the directory to the db
$writer->buildDatabase();
$writer->buildZimFile();

# delete database
$writer->deleteDb();

