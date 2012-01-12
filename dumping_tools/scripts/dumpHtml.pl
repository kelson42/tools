#!/usr/bin/perl
use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::HtmlDumper;

# log
use Kiwix::Logger;
my $logger = Kiwix::Logger->new("dumpHtml.pl");

# get the params
my $htmlPath;
my $mediawikiPath;
my $restartAtCheckpoint;

# Get console line arguments
GetOptions('mediawikiPath=s' => \$mediawikiPath, 
	   'htmlPath=s' => \$htmlPath,
	   'restartAtCheckpoint' => \$restartAtCheckpoint,
	   );

if (!$htmlPath || !$mediawikiPath) {
    print "usage: ./dumpHtml.pl --htmlPath=./html --mediawikiPath=/var/www/my_mediawiki [--restartAtCheckpoint]\n";
    exit;
}

# initialization
my $dumper = Kiwix::HtmlDumper->new();
$dumper->logger($logger);
$dumper->mediawikiPath($mediawikiPath);
$dumper->htmlPath($htmlPath);
$dumper->restartAtCheckpoint($restartAtCheckpoint);
$dumper->dump();
