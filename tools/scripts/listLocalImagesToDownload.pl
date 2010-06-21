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

## Get console line arguments
GetOptions(
	   'directory=s' => \$directory, 
           );

if (!$directory) {
    print "Usage: listLocalImagesToDownload.pl --directory=/var/www/mirror/en\n";
    exit;
}

# List iamges
exec("cd $directory/maintenance ; php checkImages.php | sed -e \"s/: .*//\" | sed -e \"s/^/File:/\" | sed '\$d'");

exit;
