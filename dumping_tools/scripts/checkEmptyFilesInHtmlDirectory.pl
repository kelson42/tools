#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::PathExplorer;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("checkEmptyFilesInHtmlDirectory.pl");

# get the params
my $contentPath;
my $remove;

# Get console line arguments
GetOptions(
	   'contentPath=s' => \$contentPath,
           'remove' => \$remove
	   );

if (!$contentPath) {
    print "usage: ./checkEmptyFilesInHtmlDirectory.pl --contentPath=./html [--remove]\n";
    exit;
}

# initialization
my $explorer = new Kiwix::PathExplorer();
$explorer->path($contentPath);

while (my $file = $explorer->getNext()) {
    # check now size
    my $filesize = -s $file;

    unless ($filesize) {
	print $file."\n";

	# delete file
	if ($remove) {
	    unlink($file);
	}
    }

}
