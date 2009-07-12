#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::NoIndexer;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("setNoIndexMetaTag.pl");

# get the params
my @files;
my $readFromStdin;

# Get console line arguments
GetOptions(
	   'file=s' => \@files,
	   'readFromStdin' => \$readFromStdin
	   );

if (!scalar(@files) && !$readFromStdin) {
    print "usage: ./setNoIndexMetaTag.pl --file=test.html [--readFromStdin]\n";
    exit;
}

# readFromSTdin
if ($readFromStdin) {
    while (my $file = <STDIN>) {
	$file =~ s/\n//;
	push(@files, $file);
    }
}

# initialization
my $noIndexer = Kiwix::NoIndexer->new();
$noIndexer->logger($logger);
$noIndexer->files(@files);
$noIndexer->apply();
