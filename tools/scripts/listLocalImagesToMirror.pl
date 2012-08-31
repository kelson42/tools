#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;

use lib "../classes/";

use Encode;
use strict;
use warnings;
use Getopt::Long;
use Mediawiki::Mirror;
use Data::Dumper;

# get the params
my $directory;
my $checkSize;

## Get console line arguments
GetOptions(
	   'directory=s' => \$directory, 
           'checkSize' => \$checkSize
           );

if (!$directory) {
    print "Usage: listLocalImagesToMirror.pl --directory=/var/www/mirror/en [--checkSize]\n";
    exit;
}

my $cmd;
if ($checkSize) {
$cmd = "cd $directory/maintenance ; php checkImages.php | sed -e \"s/: .*//\" | sed -e \"s/^/File:/\" | sed '\$d'"
} else {
$cmd = "cd $directory/maintenance ; php checkImages.php | grep missing | sed -e \"s/: .*//\" | sed -e \"s/^/File:/\" | sed '\$d'"
}

# List images
exec($cmd);

exit;
