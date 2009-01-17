#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::ZenoIndexer;
use Whereis;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("builZenoFileFromDirectory.pl");

# get the params
my $indexerPath;
my $htmlPath;
my $zenoFilePath="./articles.zeno";
my $dbType="postgres";
my $dbName=time();

# Get console line arguments
GetOptions('indexerPath=s' => \$indexerPath, 
	   'htmlPath=s' => \$htmlPath,
	   'zenoFilePath=s' => \$zenoFilePath,
	   'dbName=s' => \$dbName,
	   );

if (!$htmlPath) {
    print "usage: ./builZenoFileFromDirectory.pl --htmlPath=./html [--indexerPath=./zenoindexer] [--zenoFilePath=articles.zeno] [--dbName=kiwix_db]\n";
    exit;
}

# try to detect the zenoindexer path or test it (if given)
if ($indexerPath) {
    unless (-x $indexerPath) {
	$logger->error("The zeno indexer '$indexerPath' does not exist or is not executable.");
	exit;
    }
} else {
    $indexerPath = whereis("zenowriter");
}

# test the html directory
unless (-d $htmlPath) {
    $logger->error("The html directory '$htmlPath' does not exist.");
    exit;
}

# initialization
my $indexer = Kiwix::ZenoIndexer->new();
$indexer->logger($logger);
$indexer->indexerPath($indexerPath);
$indexer->htmlPath($htmlPath);
$indexer->zenoFilePath($zenoFilePath);
$indexer->dbType($dbType);
$indexer->dbName($dbName);

# prepare urls rewreting
$indexer->prepareUrlRewriting();

# loads the data from the directory to the db
$indexer->buildDatabase();
$indexer->buildZenoFile();

# delete database
$indexer->deleteDb();

