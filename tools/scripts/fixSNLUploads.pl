#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use utf8;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;
use File::Basename;

my $commonsHost = "commons.wikimedia.org";
my $username;
my $password;
my $pictureDirectory;
my $category = "";
my $help;
my $delay = 0;
my $verbose;
my $site;

sub usage() {
    print "fixSNLUploads.pl is a script to fix the Gugelmann collection uploads (in particular the 'double upload'.\n";
    print "\tfixSNLUploads --username=<COMMONS_USERNAME> --password=<COMMONS_PASSWORD> --directory=<PICTURE_DIRECTORY> --category=<COLLECTION_CATEGORY>\n\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two uploads\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console\n";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'directory=s' => \$pictureDirectory,
	   'delay=s' => \$delay,
	   'category=s' => \$category,
	   'verbose' => \$verbose,
	   'help' => \$help
);

if ($help) {
    usage();
    exit 0;
}

# encoding
utf8::decode($category);

# Make a few security checks
if (!$username || !$password || !$pictureDirectory) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--username=<COMMONS_USERNAME>\n\t--password=<COMMONS_PASSWORD>\n\t--directory=<PICTURE_DIRECTORY>\n";
    exit;
};

unless (-d $pictureDirectory) {
    die "'$pictureDirectory' seems not to be a valid directory.";
}

unless ($delay =~ /^[0-9]+$/) {
    die "The delay '$delay' seems not valid. This should be a number.";
}

# Category calls must be ucfirst
$category=ucfirst($category);

# Check connections to remote services
connectToCommons();

# Get all pictures in the category
foreach my $entry ($site->listCategoryEntries($category, 2, 6)) {
    $entry =~ s/ /_/g;

    # Check how many version of the picture we have
    my @images = $site->getImageHistory($entry);
    my $imagesCount = scalar(@images);

    # try to upload new cropped version if only one image
    if ($imagesCount == 1) {
	printLog("Need to upload new version of the image ".$entry);
	if ($entry =~ /.*(GS-GUGE.*)/) {
	    my $id = $1;
	    my $filename = $pictureDirectory."/".$id;
	    printLog("ID is $id");
	    if (-f $filename) {
		printLog("New version found for $entry at $filename");
		my $content = readFile($filename);
		$site->uploadImage($entry, $content, "", "cropped version", 1);
		exit;
	    } else {
		printLog("No picture found for $entry");
	    }
	} else {
	    print STDERR "Unable to match $entry\n";
	}
    }
}

# Read/Write functions
sub writeFile {
    my $file = shift;
    my $data = shift;
    utf8::encode($data);
    utf8::encode($file);
    open (FILE, ">", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    utf8::encode($file);
    open FILE, $file or die $!;
    binmode FILE;
    my ($buf, $data, $n);
    while (($n = read FILE, $data, 4) != 0) { 
	$buf .= $data;
    }
    close(FILE);
    utf8::decode($data);
    return $buf;
}

# Setup the connection to Mediawiki
sub connectToCommons {
    $site = Mediawiki::Mediawiki->new();
    $site->hostname($commonsHost);
    $site->path("w");
    $site->user($username);
    $site->password($password);

    my $connected = $site->setup();
    unless ($connected) {
	die "Unable to connect with this username/password to $commonsHost.";
    }

    return $site;
}

# Logging function
sub printLog {
    my $message = shift;
    if ($verbose) {
	utf8::encode($message);
	print "$message\n";
    }
}
