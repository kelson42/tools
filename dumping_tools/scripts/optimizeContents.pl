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
my $removeTitleTag;
my $ignoreHtml;
my $threadCount=2;

# Get console line arguments
GetOptions(
    'contentPath=s' => \$contentPath,
    'removeTitleTag' => \$removeTitleTag,
    'ignoreHtml' => \$ignoreHtml,
    'threadCount=s' => \$threadCount,
    );

if (!$contentPath) {
    print "usage: ./optimizeContents.pl --contentPath=./html [--removeTitleTag] [--ignoreHtml] [--threadCount=2]\n";
    exit;
}

# initialization
my $optimizer = Kiwix::FileOptimizer->new();
$optimizer->logger($logger);
$optimizer->contentPath($contentPath);
$optimizer->threadCount($threadCount);
$optimizer->removeTitleTag($removeTitleTag);
$optimizer->ignoreHtml($ignoreHtml);
$optimizer->optimize();
