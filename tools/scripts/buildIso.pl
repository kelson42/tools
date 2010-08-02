#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use strict;
use Getopt::Long;

# Variables 
my @zimPaths;
my $isoPath;
my $tmpDirectory = "/tmp/";
my $cmd;

# Instance logger
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("buildIso.pl");

# Get arguments
GetOptions('zimPath=s' => \@zimPaths,
	   'tmpDirectory=s' => \$tmpDirectory,
	   'isoPath=s' => \$isoPath,
    );

# Check if we have all the mandatory variable set
if (!scalar(@zimPaths) || !$isoPath) {
    print "usage: ./buildIso.pl --isoPath=dvd.iso --zimPath=articles.zim [--tmpDirectory=/tmp/]\n";
    exit
}

# Check if the zim files exist
$logger->info("Will check if the ZIM file exists...");
foreach my $zimPath (@zimPaths) {
    $logger->info("Check ZIM file $zimPath");
    unless (-f $zimPath) {
	exit 1;
    }
}

# Clear and create the directory to build the iso
my $isoDirectory = $tmpDirectory."kiwix_iso_tmp_directory/";
$logger->info("Deleting and creating $isoDirectory");
$cmd = "rm -rf $isoDirectory"; `$cmd`; 
$cmd = "mkdir $isoDirectory"; `$cmd`; 

# Checkout the default ISO directory tree structure
$logger->info("Checkout the SVN dvd directory template");
$cmd = "svn co https://kiwix.svn.sourceforge.net/svnroot/kiwix/moulinkiwix/dvd $isoDirectory"; `$cmd`;
$cmd = "rm -rf \`find $isoDirectory -name \"*.svn\"\`"; `$cmd`;

exit 0;

