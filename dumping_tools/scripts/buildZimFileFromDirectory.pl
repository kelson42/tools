#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::ZimIndexer;
use Whereis;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("builZimFileFromDirectory.pl");

# get the params
my $indexerPath;
my $htmlPath;
my $welcomePage;
my $zimFilePath="./articles";
my $dbType="postgres";
my $dbUser="kiwix";
my $dbPassword="";
my $mediawikiOptim;
my $dbName=time();

# Get console line arguments
GetOptions('indexerPath=s' => \$indexerPath, 
	   'htmlPath=s' => \$htmlPath,
	   'zimFilePath=s' => \$zimFilePath,
	   'dbName=s' => \$dbName,
	   'dbUser=s' => \$dbUser,
	   'dbPassword=s' => \$dbPassword,
	   'mediawikiOptim' => \$mediawikiOptim,
	   'welcomePage=s' => \$welcomePage,
	   );

if (!$htmlPath || !$welcomePage ) {
    print "usage: ./builZimFileFromDirectory.pl --htmlPath=./html --welcomePage=index.html [--dbUser=foobar] [--dbPassword=testpass] [--indexerPath=./zimindexer] [--zimFilePath=articles.zim] [--dbName=kiwix_db] [--mediawikiOptim]\n";
    exit;
}

# try to detect the zimindexer path or test it (if given)
if ($indexerPath) {
    unless (-x $indexerPath) {
	$logger->error("The zim indexer '$indexerPath' does not exist or is not executable.");
	exit;
    }
} else {
    $indexerPath = whereis("zimwriter");
}

# test the html directory
unless (-d $htmlPath) {
    $logger->error("The html directory '$htmlPath' does not exist.");
    exit;
}

# remove the ".zim" at the end of the zimFilePath
$zimFilePath =~ s/\.zim$//;

# initialization
my $indexer = Kiwix::ZimIndexer->new();
$indexer->logger($logger);
$indexer->indexerPath($indexerPath);
$indexer->htmlPath($htmlPath);
$indexer->zimFilePath($zimFilePath);
$indexer->dbType($dbType);
$indexer->dbName($dbName);
$indexer->dbUser($dbUser);
$indexer->dbPassword($dbPassword);
$indexer->welcomePage($welcomePage);
$indexer->mediawikiOptim($mediawikiOptim);

# prepare urls rewreting
$indexer->prepareUrlRewriting();

# loads the data from the directory to the db
$indexer->buildDatabase();
$indexer->buildZimFile();

# delete database
$indexer->deleteDb();

