#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use strict;
use Getopt::Long;
use File::Basename;

# Variables 
my @zimPaths;
my $filePath;
my $tmpDirectory = "/tmp/";
my $downloadMirror = "download.kiwix.org";
my $liveInstance;
my $lang = "en";
my $type;
my $verbose;
my $cmd;
my $cmdOutput;

# Get arguments
GetOptions('zimPath=s' => \@zimPaths,
	   'tmpDirectory=s' => \$tmpDirectory,
	   'filePath=s' => \$filePath,
	   'liveInstance' => \$liveInstance,
	   'downloadMirror=s' => \$downloadMirror,
	   'type=s' => \$type,
	   'lang=s' => \$lang,
	   'verbose' => \$verbose
    );

# Check if we have all the mandatory variable set
if (!scalar(@zimPaths) || !$filePath || (!($type eq "iso") && !($type eq "portable"))) {
    print "usage: ./buildDistributionFile.pl --filePath=dvd.iso --zimPath=articles.zim --type=[iso|portable] [--tmpDirectory=/tmp/] [--lang=en|fr] [--liveInstance] [--downloadMirror=themirror] [--verbose]\n";
    exit
}

# Check if the zim files exist
printLog("Will check if the ZIM file exists...");
foreach my $zimPath (@zimPaths) {
    printLog("Check ZIM file $zimPath");
    unless (-f $zimPath) {
	exit 1;
    }
}

# Clear and create the directory to build the iso
my $distributionDirectory = $tmpDirectory."/kiwix_iso_tmp_directory/";
printLog("Deleting and creating $distributionDirectory");
$cmd = "rm -rf $distributionDirectory"; `$cmd`; 
$cmd = "mkdir -p $distributionDirectory"; `$cmd`; 

# Checkout the default ISO directory tree structure
printLog("Checkout the git 'dvd' directory template");
$cmd = "cd $distributionDirectory ; git clone --depth=1 https://github.com/kiwix/kiwix_mirror.git dvd ; cd dvd ; git filter-branch --prune-empty --subdirectory-filter dvd HEAD ; rm -rf .git"; `$cmd`;
$cmd = "cd $distributionDirectory ; mv dvd/autorun.inf ."; `$cmd`;

# Download the source code
printLog("Download Kiwix source code");
$cmd = "cd $distributionDirectory ; wget --trust-server-names http://$downloadMirror/src/kiwix-0.9-src.tar.xz"; `$cmd`;

# Download and unzip linux binary
printLog("Download and unzip Linux binary");
$cmd = "wget http://$downloadMirror/bin/0.9/\` curl --silent http://$downloadMirror/bin/0.9/ | grep bz2 | grep 64 | sed 's/.*href=\"//' | sed 's/\".*//' \` -O $distributionDirectory/kiwix-linux.tar.bz2"; `$cmd`;
$cmd = "cd $distributionDirectory ; tar -xvf kiwix-linux.tar.bz2 ; rm kiwix-linux.tar.bz2 ; mv kiwix kiwix-linux ; tar -cvjf kiwix-linux.tar.bz2 kiwix-linux; rm -rf kiwix-linux"; `$cmd`;

# Download and unzip Windows binary
printLog("Download and unzip Windows binary");
$cmd = "wget http://$downloadMirror/bin/0.9/\` curl --silent http://$downloadMirror/bin/0.9/ | grep zip | sed 's/.*href=\"//' | sed 's/\".*//' \` -O $distributionDirectory/kiwix.zip"; `$cmd`;
$cmd = "cd $distributionDirectory/ ; unzip -n kiwix.zip" ; `$cmd`;
$cmd = "rm $distributionDirectory/kiwix.zip" ; `$cmd`;

# Download and unzip OSX binary
printLog("Download and unzip OSX binary");
$cmd = "wget http://$downloadMirror/bin/0.9/\` curl --silent http://$downloadMirror/bin/0.9/ | grep '.app' | sed 's/.*href=\"//' | sed 's/\".*//' \` -O $distributionDirectory/Kiwix.app.tar.xz"; `$cmd`;
$cmd = "cd $distributionDirectory/ ; tar -xvf Kiwix.app.tar.xz" ; `$cmd`;
$cmd = "rm $distributionDirectory/Kiwix.app.tar.xz" ; `$cmd`;

# Compute and compact the indexes
printLog("Compute and compact the indexes");
foreach my $zimPath (@zimPaths) {

    # Extract the zimFile
    my $zimFile = basename( $zimPath );

    # Create the index and library
    printLog("Create new library file ro $zimFile.");
    $cmd = "kiwix-install --verbose --buildIndex ADDCONTENT $zimPath $distributionDirectory/";
    printLog($cmd);
    open(CMD, $cmd."|");
    while (<CMD>) {
	print ">>> $_";
    }
    close(CMD);

    # Compact index
    my $zimFileIndex = "$distributionDirectory/data/index/$zimFile.idx";
    printLog("Compact index $zimFileIndex");
    $cmd = "kiwix-compact $zimFileIndex"; `$cmd`;
}

# Update @zimPaths
$cmd = "find \"$distributionDirectory/data/content/\" -name \"*.zim\" 2>&1";
my $output = `$cmd`;
@zimPaths = split (/\n/, $output);

# Splitting the ZIMs
printLog("Splitting the ZIM files");
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

# Download the autorun
printLog("Download autorun");
$cmd = "cd $distributionDirectory/ ; rm -rf autorun ; wget http://$downloadMirror/dev/launcher/autorun.zip; unzip autorun.zip ; rm autorun.zip"; `$cmd`;
$cmd = "cd $distributionDirectory/ ; sed -i -e 's/autorun\.exe/autorun\.exe \-\-lang=$lang/' autorun.inf"; `$cmd`;

# live instance
if ($liveInstance) {
    $cmd = "touch $distributionDirectory/kiwix/live"; `$cmd`;
}

# Build ISO
if ($type eq "iso") {
    printLog("Build ISO $filePath");
    $cmd = "mkisofs -r -J -o  $filePath $distributionDirectory"; `$cmd`;
} else { # portable
    printLog("Build the portable compacted file");
    $cmd = "7za a -tzip -mx9 -mmt6 $filePath $distributionDirectory/* -mmt"; `$cmd`;
}

sub writeFile {
    my $file = shift;
    my $data = shift;
    
    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

# Logging function
sub printLog {
    my $message = shift;
    if ($verbose) {
	utf8::encode($message);
	print "$message\n";
    }
}

exit 0;

