#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use HTML::Template;
use File::Basename;

my $directory;
my $help;
my $delay = 0;
my $verbose;
my $templateCode = "";

sub usage() {
    print "downloadC2C.pl is a script to download free pictures of http://www.camptocamp.org/.\n";
    print "\tdownloadC2C --directory=<PICTURE_DIRECTORY>\n\n";
    print "In addition, you can specify a few additional arguments:\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two downloads\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console\n";
}

GetOptions('directory=s' => \$directory,
	   'delay=s' => \$delay,
	   'verbose' => \$verbose,
	   'help' => \$help,
);

if ($help) {
    usage();
    exit 0;
}

# Make a few security checks
if (!$directory) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--directory=<PICTURE_DIRECTORY>\n";
    exit;
};

unless (-d $directory) {
    die "'$directory' seems not to be a valid directory.";
}

# Read/Write functions
sub writeFile {
    my $file = shift;
    my $data = shift;
    open (FILE, ">", "$file") or die "Couldn't open file: $file";
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

# Logging function
sub printLog {
    my $message = shift;
    if ($verbose) {
	print "$message\n";
    }
}
