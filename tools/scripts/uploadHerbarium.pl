#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";
binmode STDERR, ":utf8";

use utf8;
use lib '../classes/';

use strict;
use warnings;
use Getopt::Long;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;

my $username;
my $password;
my $directory;
my @genius;
my $help;
my $delay = 0;
my $verbose;
my $fsSeparator = '/';
sub usage() {
    print "uploadHerbarium.pl is a script to upload the Neuchatel herbarium pictures to Wikimedia Commons library.\n";
    print "\tuploadHerbarium --username=<COMMONS_USERNAME> --password=<COMMONS_PASSWORD> --directory=<PICTURE_DIRECTORY>\n\n";
    print "In addition, you can specify a few additional arguments:\n";
    print "--genius=<GENIUS>                Upload only this/these genius\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two uploads\n\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'directory=s' => \$directory,
	   'delay=s' => \$delay,
	   'verbose' => \$verbose,
	   'genius=s' => \@genius,
	   'help' => \$help,
);

if ($help) {
    usage();
    exit 0;
}

# Make a few security checks
if (!$username || !$password || !$directory) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--username=<COMMONS_USERNAME>\n\t--password=<COMMONS_PASSWORD>\n\t--directory=<PICTURE_DIRECTORY>\n";
    exit;
};

unless (-d $directory) {
    print STDERR "'$directory' seems not to be a valid directory.\n";
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
if (scalar(@genius)) {
    if ($verbose) {
	print scalar(@genius)." filter(s) detected.\n";
    }
    foreach my $genius (@genius) {
	push(@directories, $directory.$fsSeparator.$genius);
    }
} else {
    if ($verbose) {
	print "No filter detected.\n";
    }
    push(@directories, $directory);
}

print Dumper(@directories);

# Get pictures to upload

# Upload pictures

