#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use HTML::Template;
use HTML::Entities;
use LWP::UserAgent;
use Encode;

my $directory;
my $help;
my $delay = 0;
my $verbose;
my $templateCode = "";
my $ua = LWP::UserAgent->new();

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

# Go through all images
my $lastResultPageIndex;
my $resultPageIndex = 1;
my $resultPage;
my $infoPage;
my $req;
my $res;
do { 
    $resultPage = getUrlContent("http://www.camptocamp.org/images/list/ityp/1/page/$resultPageIndex");
    while ($resultPage =~ /\/images\/(\d+)\/fr\//gm) {
	my $uid = $1;
	my $more = "http://www.camptocamp.org/images/$uid";
	my $title;
	my $url;
	my $author;

	# Get detailed page
	$infoPage = getUrlContent($more);

	# Get title
	if ($infoPage =~ /id="article_title".*?><a.*?>(.*?)<\/a>/) {
	    $title = encode_utf8(decode_entities($1));
	}
	
	# Get url
	if ($infoPage =~ /href="(http:\/\/s.camptocamp.org\/uploads\/images\/.*?)" itemprop="contentUrl"/) {
	    $url = $1;
	}

	# Get author
	if ($infoPage =~ /itemprop="author" href="\/users\/\d+">(.*?)<\/a>/) {
	    $author = $1;
	}

	printLog("UID: $uid");
	printLog("MORE: $more");
	printLog("TITLE: $title");
	printLog("URL: $url");
	printLog("AUTHOR: $author");
    }

    # Get $lastResultPageIndex
    if ($resultPageIndex == 1) {
	if ($resultPage =~ /\/images\/list\/ityp\/1\/page\/(\d+)"><span class=\"picto action_last/) {
	    $lastResultPageIndex = $1;
	} else {
	    die("Unable to find lastResultPageIndex.")
	}
    }
} while ($resultPageIndex++ < $lastResultPageIndex);

# Request url
sub getUrlContent {
    my $url = shift;

    $req = HTTP::Request->new(GET => $url);
    $res = $ua->request($req);
    if ($res->is_success) {
	return $res->content;
    } else {
	die("Unable to request '$url': ".$res->status_line);
    }
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
