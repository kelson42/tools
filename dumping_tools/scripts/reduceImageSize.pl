#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::ImageResizer;

# log
use Kiwix::Logger;
my $logger = Kiwix::Logger->new("reduceImageSize.pl");

# get the params
my $contentPath;
my $maxWidth;
my $maxHeight;
my $threadCount=2;

# Get console line arguments
GetOptions(
    'contentPath=s' => \$contentPath,
    'maxWidth=s' => \$maxWidth,
    'maxHeight=s' => \$maxHeight,
    'threadCount=s' => \$threadCount,
    );

if (!$contentPath || !$maxWidth || !$maxHeight) {
    print "usage: ./reduceImageSize.pl --contentPath=./html --maxWidth=1000 --maxHeght=1000 [--threadCount=2]\n";
    exit;
}

if ($maxWidth < 1000 || $maxHeight < 1000) {
    print "maxWidth or maxHeight < 1000. Are you sure? Waiting 10 seconds...\n";
    sleep(10);
}

# initialization
my $optimizer = Kiwix::ImageResizer->new();
$optimizer->logger($logger);
$optimizer->contentPath($contentPath);
$optimizer->threadCount($threadCount);
$optimizer->maxWidth($maxWidth);
$optimizer->maxHeight($maxHeight);
$optimizer->findAndResize();
