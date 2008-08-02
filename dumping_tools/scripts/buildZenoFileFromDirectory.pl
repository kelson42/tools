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
my $textCompression="gzip";
my $tmpDirectoryPath;

# Get console line arguments
GetOptions('indexerPath=s' => \$indexerPath, 
	   'htmlPath=s' => \$htmlPath,
	   'zenoFilePath=s' => \$zenoFilePath,
	   'textCompression=s' => \$textCompression,
	   'tmpDirectoryPath=s' => \$tmpDirectoryPath
	   );

if (!$htmlPath) {
    print "usage: ./builZenoFileFromDirectory.pl --htmlPath=./html [--indexerPath=./zenoindexer] [--zenoFilePath=articles.zeno] [--textCompression={none|gzip}] [--tmpDirectoryPath=/tmp]\n";
    exit;
}

# sqlite DB path
my $dbFile;
if ($tmpDirectoryPath && -w $tmpDirectoryPath ) {
    $dbFile= $tmpDirectoryPath."/.dbname=".time();
} elsif (-w "/tmp") {
    $dbFile="/tmp/.dbname=".time();
} elsif (-w "./") {
    $dbFile="./.dbname=".time();
} else {
    $logger->error("You need a writable temp directory, please specify one.");
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
$indexer->textCompression($textCompression);

# loads the data from the directory to the db
$indexer->exploreHtmlPath();
$indexer->buildDatabase($dbFile);
exit;
# call the zeno indexer
`$indexerPath --db "sqlite:$dbFile" $zenoFilePath`;

# delete temporary dbFile
if ( unlink($dbFile) == 0 ) {
    $logger->info("File $dbFile deleted successfully.");
} else {
    $logger->error("File $dbFile was not deleted.");
}

