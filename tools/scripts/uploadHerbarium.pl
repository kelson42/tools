#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use strict;
use warnings;
use Getopt::Long;
use Getopt::Long;
use Data::Dumper;
use Encode;
use Kiwix::PathExplorer;
use Mediawiki::Mediawiki;

my $username;
my $password;
my $baseDirectory;
my @filters;
my $help;
my $delay = 0;
my $verbose;
my $fsSeparator = '/';
sub usage() {
    print "uploadHerbarium.pl is a script to upload the Neuchatel herbarium pictures to Wikimedia Commons library.\n";
    print "\tuploadHerbarium --username=<COMMONS_USERNAME> --password=<COMMONS_PASSWORD> --directory=<PICTURE_DIRECTORY>\n\n";
    print "In addition, you can specify a few additional arguments:\n";
    print "--filter=<GENIUS_OR_SPECIE>      Upload only this/these genius/species\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two uploads\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console\n";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'directory=s' => \$baseDirectory,
	   'delay=s' => \$delay,
	   'verbose' => \$verbose,
	   'filter=s' => \@filters,
	   'help' => \$help,
);

if ($help) {
    usage();
    exit 0;
}

# Make a few security checks
if (!$username || !$password || !$baseDirectory) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--username=<COMMONS_USERNAME>\n\t--password=<COMMONS_PASSWORD>\n\t--directory=<PICTURE_DIRECTORY>\n";
    exit;
};

unless (-d $baseDirectory) {
    print STDERR "'$baseDirectory' seems not to be a valid directory.\n";
    exit 1;
}

unless ($delay =~ /^[0-9]+$/) {
    print STDERR "The delay '$delay' seems not valid. This should be a number.\n";
    exit 1;
}

# Setup the connection to commons.wikimedia.org
my $site = Mediawiki::Mediawiki->new();

$site->hostname("commons.wikimedia.org.zimfarm.kiwix.org");

#$site->hostname("commons.wikimedia.org");
#$site->path("w");

$site->user($username);
$site->password($password);
my $connected = $site->setup();
if ($connected) {
    if ($verbose) {
	print "Successfuly connected to commons.wikimedia.org\n";
    }
} else {
    print STDERR "Unable to connect with this username/password to commons.wikimedia.org\n";
    exit 1;
}

# Compute paths to go through
my @directories;
if (scalar(@filters)) {
    if ($verbose) {
	print scalar(@filters)." filters detected.\n";
    }
    foreach my $filter (@filters) {
	my $filterDirectory = $filter;
	$filterDirectory =~ s/( |_)/$fsSeparator/;
	my $wholeFilterDirectory = $baseDirectory.$fsSeparator.$filterDirectory;
	if (-d $wholeFilterDirectory) {
	    push(@directories, $wholeFilterDirectory);
	} else {
	    print STDERR "'$wholeFilterDirectory' is not a directory, please check your --filter argument(s).\n";
	    exit 1;
	}
    }
} else {
    if ($verbose) {
	print "No filter detected.\n";
    }
    push(@directories, $baseDirectory);
}
if ($verbose) {
    print "Following directory(ies) will be parsed:\n";
    foreach my $directory (@directories) {
	print "* $directory\n";
    }
}

# Get pictures to upload
my @pictures;
my $patternRegex = "(\\w+)\\$fsSeparator(\\w+)\\$fsSeparator(\\w+)\\.tiff\$";
foreach my $directory (@directories) {
    my $explorer = new Kiwix::PathExplorer();
    $explorer->filterRegexp('\.tiff$');
    $explorer->path($directory);
    while (my $file = $explorer->getNext()) {
	if (substr($file, length($baseDirectory)) =~ /$patternRegex/) {
	    push(@pictures, $file);
	} else {
	    print STDERR "'$file' does not match the /GENIUS/SPECIE/ID.tiff pattern.\n";
	    exit 1;
	}
    }
}
if ($verbose) {
    print scalar(@pictures)." file(s) to upload (*.tiff) where detected.\n";
}

# Upload pictures
my $pictureNameRegex = "^.*\\$fsSeparator";
foreach my $picture (@pictures) {
    $picture =~ /$patternRegex/;
    my $genius = $1;
    my $specie = $2;
    my $id = $3;
    my $pictureName = "Neuchâtel_Herbarium_-_".ucfirst($genius)."_".lcfirst($specie)."_-_$id.tiff";

    # Check if already done
    my $doneFile = $picture.".done";
    my $done;
    if (-f $doneFile) {
	$done = 42;
    } else {
	my $exists = $site->exists("File:$pictureName");
	if ($exists) {
	    $done = 42;
	    writeFile($doneFile, "");
	}
    }
    if ($done) {
	if ($verbose) {
	    print "'$pictureName' already uploaded...\n";
	}
	next;
    }

    if ($verbose) {
	print "Uploading '$pictureName'...\n";
    }
    
    my $content = readFile($picture);
    my $status = $site->uploadImage($pictureName, $content, "Upload...");
    
    if ($status) {
	if ($verbose) {
	    print "'$pictureName' was successfuly uploaded.\n";
	}
	writeFile($picture.".done", "");
    } else {
	print STDERR "'$pictureName' failed to be uploaded.\n";
	exit 1;
    }
}

# Read/Write functions
sub writeFile {
    my $file = shift;
    my $data = shift;
    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    open FILE, $file or die $!;
    binmode FILE;
    my ($buf, $data, $n);
    while (($n = read FILE, $data, 4) != 0) { 
	$buf .= $data;
    }
    close(FILE);
    return $buf;
}
