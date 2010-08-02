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

# Copy the ZIMs
$logger->info("Copying the ZIM files");
foreach my $zimPath (@zimPaths) {
    $logger->info("Check ZIM file $zimPath");
    $cmd = "cp $zimPath $isoDirectory/data/content/"; `$cmd`;
}

# Update @zimPaths
my $output = `find /tmp/kiwix_iso_tmp_directory/data/content/ -name \"*.zim\" 2>&1`;
@zimPaths = split (/\n/, $output);

# Compute and compact the indexes
$logger->info("Compute and compact the indexes");
foreach my $zimPath (@zimPaths) {

    # Extract the zimFile
    $zimPath =~ /.*\/([^\/]*)$/;
    my $zimFile = $1;

    # Index
    my $zimFileIndex = "$isoDirectory/data/index/$zimFile.idx";
    $logger->info("Compute index for $zimFile");
    $cmd = "kiwix-index $zimPath $zimFileIndex"; `$cmd`;

    # Compact
    $logger->info("Compact index $zimFileIndex");
    $cmd = "kiwix-compact $zimFileIndex"; `$cmd`;

    # Compute the zimId
    $cmd = "zimdump -F /tmp/kiwix_iso_tmp_directory/data/content/ubuntudoc_fr_01_2009.zim  | grep uuid | sed 's/uuid: //'";
    my $zimFileId = `$cmd 2>&1`;
    $zimFileId =~ s/\r|\n//g;

    # Create the library
    my $libraryPath = "$isoDirectory/data/library/$zimFile.library";
    $logger->info("Create the library for $zimFile : ");
    my $xmlContent = "<library current=\"$zimFileId\"><book id=\"$zimFileId\" path=\"$zimFile\" indexPath=\"$zimFile.idx\" indexType=\"xapian\"/></library>\n";
    writeFile($libraryPath, $xmlContent);
}

sub writeFile {
    my $file = shift;
    my $data = shift;
    
    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

exit 0;

