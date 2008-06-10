#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::ZenoIndexer;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("builZenoFileFromDirectory.pl");

# get the params
my $indexerPath;
my $htmlPath;
my $zenoFilePath;

## Get console line arguments
GetOptions('indexerPath=s' => \$indexerPath, 
	   'htmlPath=s' => \$htmlPath,
	   'zenoFilePath=s' => \$zenoFilePath
	   );

if (!$indexerPath || !$htmlPath || !$zenoFilePath) {
    print "usage: ./builZenoFileFromDirectory.pl --indexerPath=./zenoindexer --htmlPath=./html zenoFilePath=articles.zeno\n";
    exit;
}

my $indexer = Kiwix::ZenoIndexer->new();
$indexer->logger($logger);
$indexer->indexerPath($indexerPath);
$indexer->htmlPath($htmlPath);
$indexer->zenoFilePath($zenoFilePath);
$indexer->exploreHtmlPath();
