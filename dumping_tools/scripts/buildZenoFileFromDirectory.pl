#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::ZenoIndexer;

# sqlite DB path
my $dbFile="/tmp/dbname=".time();

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("builZenoFileFromDirectory.pl");

# get the params
my $indexerPath;
my $htmlPath;
my $zenoFilePath;
my $textCompression="none";

# Get console line arguments
GetOptions('indexerPath=s' => \$indexerPath, 
	   'htmlPath=s' => \$htmlPath,
	   'zenoFilePath=s' => \$zenoFilePath,
	   'textCompression=s' => \$textCompression
	   );

if (!$indexerPath || !$htmlPath || !$zenoFilePath) {
    print "usage: ./builZenoFileFromDirectory.pl --indexerPath=./zenoindexer --htmlPath=./html --zenoFilePath=articles.zeno [--textCompression={none|gzip}]\n";
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

# call the zeno indexer
`$indexerPath --db "sqlite:$dbFile" wikipedia.zeno`;

# delete temporary dbFile
if ( unlink($dbFile) == 0 ) {
    $logger->info("File $dbFile deleted successfully.");
} else {
    $logger->error("File $dbFile was not deleted.");
}

