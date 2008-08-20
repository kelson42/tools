#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::FileOptimizer;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("optimizeContents.pl");

# get the params
my $contentPath;

# Get console line arguments
GetOptions(
	   'contentPath=s' => \$contentPath
	   );

if (!$contentPath) {
    print "usage: ./optimizeContents.pl --contentPath=./html\n";
    exit;
}

# initialization
my $dumper = Kiwix::FileOptimizer->new();
$dumper->logger($logger);
$dumper->contentPath($contentPath);
$dumper->optimize();
