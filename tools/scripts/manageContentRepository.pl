#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use utf8;
use strict;
use warnings;
use Kiwix::PathExplorer;
use Getopt::Long;
use Data::Dumper;
use File::stat;
use Time::localtime;

my %content;

# Configuration variables
my $contentDirectory = "/var/www/download.kiwix.org";
my $zimDirectoryName = "zim";
my $zimDirectory = $contentDirectory."/".$zimDirectoryName;
my $portableDirectoryName = "portable";
my $portableDirectory = $contentDirectory."/".$portableDirectoryName;
my $htaccessPath = $contentDirectory."/.htaccess";
 
# Task
my $writeHtaccess = 0;
my $showHelp = 0;

sub usage() {
    print "manageContentRepository\n";
    print "\t--help\n";
    print "\t--writeHtaccess\n";
}

# Parse command line
GetOptions(
    'writeHtaccess' => \$writeHtaccess,
    'help' => \$showHelp,
);

if ($showHelp) {
    usage();
    exit 0;
}

if (!$writeHtaccess) {
    $writeHtaccess = 1;
}

# Parse the "zim" and "portable" directories
my $explorer = new Kiwix::PathExplorer();
$explorer->path($zimDirectory);
while (my $file = $explorer->getNext()) {
    if ($file =~ /^.*\/([^\/]+)\.zim$/i) {
	my $basename = $1;
	my $core = $basename;
	my $month;
	my $year;

	# Old/new date format
	if ($basename =~ /^(.+?)(_|)([\d]{2}|)_([\d]{4})$/i) {
	    $core = $1;
	    $month = $3;
	    $year = $4;
	} elsif ($basename =~ /^(.+?)(_|)([\d]{4}|)\-([\d]{2})$/i) {
	    $core = $1;
	    $year = $3;
	    $month = $4;
	}
	
	$content{$basename} = {
	    zim => $file,
	    basename => $basename,
	    core => $core,
	    month => $month,
	    year => $year,
	};
    }
}

$explorer->reset();
$explorer->path($portableDirectory);
while (my $file = $explorer->getNext()) {
    if ($file =~ /^.*?\+([^\/]+)\.zip$/i) {
	my $basename = $1;
	if  (exists($content{$basename})) {
	    if ((exists($content{$basename}->{portable}) && 
		 getFileCreationDate($file) > getFileCreationDate($content{$basename}->{portable})) ||
		!exists($content{$basename}->{portable})
		) {
		$content{$basename}->{portable} = $file;
	    }
	} else {
	    print STDERR "Unable to find corresponding ZIM file to $file\n";
	}
    }
}

# Create Htaccess
my %recentContent;
my %deprecatedContent;
my %intemporalContent;
foreach my $key (keys(%content)) {
    my $entry = $content{$key};
    my $year = $entry->{year};
    my $core = $entry->{core};

    if ($year) {
	if (exists($recentContent{$core})) {
	    my $otherEntry = $recentContent{$core};
	    if ($year == $otherEntry->{year}) {
		my $month = $entry->{month};
		if ($month > $otherEntry->{month} && $entry->{portable}) {
		    $deprecatedContent{$core} = $otherEntry;
		    $recentContent{$core} = $entry;
		} else {
		    $deprecatedContent{$core} = $entry;
		}
	    } else {
		if ($year < $otherEntry->{year}) {
		    $deprecatedContent{$core} = $entry;
		} else {
		    if ($entry->{portable}) {
			$deprecatedContent{$core} = $otherEntry;
			$recentContent{$core} = $entry;
		    } else {
			$deprecatedContent{$core} = $entry;
		    }
		}
	    }
	} else {
	    $recentContent{$core} = $entry;
	}
    } else {
	$intemporalContent{$core} = $entry;
    }
}

my $content = "#\n";
$content .= "# Please do not edit this file manually\n";
$content .= "#\n\n";
$content .= "RewriteEngine On\n\n";

foreach my $key (keys(%recentContent)) {
    my $entry = $recentContent{$key};
    $content .= "Redirect /".$zimDirectoryName."/".$entry->{core}.".zim ".substr($entry->{zim}, length($contentDirectory))."\n";
    $content .= "Redirect /".$zimDirectoryName."/".$entry->{core}.".zim.torrent ".substr($entry->{zim}, length($contentDirectory)).".torrent\n";
    if ($entry->{portable}) {
	$content .= "Redirect /".$portableDirectoryName."/".$entry->{core}.".zip ".substr($entry->{portable}, length($contentDirectory))."\n";
	$content .= "Redirect /".$portableDirectoryName."/".$entry->{core}.".zip.torrent ".substr($entry->{portable}, length($contentDirectory)).".torrent\n";
    }
    $content .= "\n";
}
writeFile($htaccessPath, $content);

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

sub getFileCreationDate {
    return stat(shift)->ctime;
}

exit 0;
