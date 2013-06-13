#!/usr/bin/perl

use utf8;
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;
use File::Path qw(make_path remove_tree);
use File::Basename;
use URI::Escape;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorImageFiles.pl");

# get the params
my $host = "";
my $path = "";
my $directory = "";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'directory=s' => \$directory,
	   );

unless ($host || $directory) {
    print "usage: ./mirrorImageFiles.pl --host=my.wiki.org [--path=w] --directory=/var/www/wiki/\n";
    exit;
}

unless ( -d $directory && -f "$directory/LocalSettings.php" ) {
    print "$directory is not a valid mediawiki directory path.\n";
    exit;
}

# Get images to mirror
my $cmd = "cd $directory/maintenance ; php checkImages.php | grep missing | sed -e \"s/: .*//\" | sed -e \"s/^/File:/\" | sed '\$d'";
my @files = `$cmd`;
my @titles = map { my $tmp = $_ ; $tmp =~ s/\r|\n//g; $_ = $tmp } @files;

# Login to the remote mediawiki
my $site = Mediawiki::Mediawiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);

foreach my $title (@titles) {
    foreach my $imageInfo ($site->imageInfos($title)) {
	my $url = $imageInfo->{'url'};
	my $target = uri_unescape($url);
	$target =~ s/^(.+\/)([^\/]{1}\/[^\/]{2}\/[^\/]+$)/$2/;
	$target = $directory."/images/".$target;
	my $targetDir = dirname($target);
	print "$url -> $target\n";
	make_path($targetDir);
	$cmd = "wget '$url' -O '$target'"; `$cmd`;
    }
}

exit;
