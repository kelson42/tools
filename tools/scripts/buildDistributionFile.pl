#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use strict;
use Getopt::Long;

# Variables 
my @zimPaths;
my $filePath;
my $tmpDirectory = "/tmp/";
my $liveInstance;
my $lang = "en";
my $type;
my $cmd;
my $cmdOutput;

# Instance logger
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("buildDistributionFile.pl");

# Get arguments
GetOptions('zimPath=s' => \@zimPaths,
	   'tmpDirectory=s' => \$tmpDirectory,
	   'filePath=s' => \$filePath,
	   'liveInstance' => \$liveInstance,
	   'type=s' => \$type,
	   'lang=s' => \$lang,
    );

# Check if we have all the mandatory variable set
if (!scalar(@zimPaths) || !$filePath || (!($type eq "iso") && !($type eq "portable"))) {
    print "usage: ./buildDistributionFile.pl --filePath=dvd.iso --zimPath=articles.zim --type=[iso|portable] [--tmpDirectory=/tmp/] [--lang=en|fr] [--liveInstance]\n";
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
my $distributionDirectory = $tmpDirectory."kiwix_iso_tmp_directory/";
$logger->info("Deleting and creating $distributionDirectory");
$cmd = "rm -rf $distributionDirectory"; `$cmd`; 
$cmd = "mkdir $distributionDirectory"; `$cmd`; 

# Checkout the default ISO directory tree structure
$logger->info("Checkout the SVN dvd directory template");
$cmd = "svn co https://kiwix.svn.sourceforge.net/svnroot/kiwix/moulinkiwix/dvd $distributionDirectory"; `$cmd`;
$cmd = "rm -rf \`find $distributionDirectory -name \"*.svn\"\`"; `$cmd`;

# Download the source code
$logger->info("Download Kiwix source code");
$cmd = "cd $distributionDirectory ; wget --trust-server-names http://download.kiwix.org/src/kiwix-0.9~rc2-src.tar.gz"; `$cmd`;

# Download and unzip linux binary
$logger->info("Download and unzip Linux binary");
$cmd = "wget http://download.kiwix.org/bin/unstable/\` curl --silent http://download.kiwix.org/bin/unstable/ | grep bz2 | grep 686 | sed 's/.*href=\"//' | sed 's/\".*//' \` -O $distributionDirectory/kiwix-linux.tar.bz2"; `$cmd`;
print STDERR $cmd;
$cmd = "cd $distributionDirectory/ ; mkdir tmp ; tar --directory=tmp -xvjf kiwix-linux.tar.bz2 ; cd tmp ; mv kiwix ../kiwix-linux ; cd .. ; rm -rf tmp" ; `$cmd`;
$cmd = "rm $distributionDirectory/kiwix-linux.tar.bz2" ; `$cmd`;

# Download and unzip Windows binary
$logger->info("Download and unzip Windows binary");
$cmd = "wget http://download.kiwix.org/bin/unstable/\` curl --silent http://download.kiwix.org/bin/unstable/ | grep zip | sed 's/.*href=\"//' | sed 's/\".*//' \` -O $distributionDirectory/kiwix.zip"; `$cmd`;
$cmd = "cd $distributionDirectory/ ; unzip -n kiwix.zip" ; `$cmd`;
$cmd = "rm $distributionDirectory/kiwix.zip" ; `$cmd`;

# Compute and compact the indexes
$logger->info("Compute and compact the indexes");
foreach my $zimPath (@zimPaths) {

    # Extract the zimFile
    $zimPath =~ /.*\/([^\/]*)$/;
    my $zimFile = $1;

    # Create the index and library
    $logger->info("Create new library file ro $zimFile.");
    $cmd = "kiwix-install --verbose --buildIndex --backend=xapian ADDCONTENT $zimPath $distributionDirectory/";
    $logger->info($cmd);
    open(CMD, $cmd."|");
    while (<CMD>) {
	print ">>> $_";
    }
    close(CMD);

    # Compact index
    my $zimFileIndex = "$distributionDirectory/data/index/$zimFile.idx";
    $logger->info("Compact index $zimFileIndex");
    $cmd = "kiwix-compact $zimFileIndex"; `$cmd`;
}

if ( -d "$distributionDirectory/data/index/wikipedia_sw_all_04_2011.zim.idx") {
    print STDERR "OK1\n";
}

# Update @zimPaths
my $output = `find /tmp/kiwix_iso_tmp_directory/data/content/ -name \"*.zim\" 2>&1`;
@zimPaths = split (/\n/, $output);

if ( -d "$distributionDirectory/data/index/wikipedia_sw_all_04_2011.zim.idx") {
    print STDERR "OK2\n";
}

# Splitting the ZIMs
$logger->info("Splitting the ZIM files");
foreach my $zimPath (@zimPaths) {
    my $zimSize = -s $zimPath;
    if ($zimSize > 2097152000) {
	my $prefix = $zimPath; $prefix =~ s/.*\///g;
	$cmd = "cd $distributionDirectory/data/content/; split --bytes=2000M $zimPath $prefix"; `$cmd`;
    }

    if (-e $zimPath."aa") {
	$cmd = "cd $distributionDirectory/data/content/ ; rm $zimPath"; `$cmd`;
    }
}

if ( -d "$distributionDirectory/data/index/wikipedia_sw_all_04_2011.zim.idx") {
    print STDERR "OK3\n";
}

# Download the autorun
$logger->info("Download autorun");
$cmd = "cd $distributionDirectory/ ; rm -rf autorun ; wget http://download.kiwix.org/dev/launcher/autorun.zip; unzip autorun.zip ; rm autorun.zip"; `$cmd`;
$cmd = "cd $distributionDirectory/ ; sed -i -e 's/autorun\.exe/autorun\.exe \-\-lang=$lang/' autorun.inf"; `$cmd`;

# live instance
if ($liveInstance) {
    $cmd = "touch $distributionDirectory/kiwix/live"; `$cmd`;
}

# Build ISO
if ($type eq "iso") {
    $logger->info("Build ISO $filePath");
    $cmd = "mkisofs -r -J -o  $filePath $distributionDirectory"; `$cmd`;
} else { # portable
    $logger->info("Build the portable compacted file");
    $cmd = "7za a -tzip -mx9 $filePath $distributionDirectory/* -mmt"; `$cmd`;
}

if ( -d "$distributionDirectory/data/index/wikipedia_sw_all_04_2011.zim.idx") {
    print STDERR "OK4\n";
}

sub writeFile {
    my $file = shift;
    my $data = shift;
    
    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

exit 0;

