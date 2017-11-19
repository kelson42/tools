#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../classes/";
use lib "$FindBin::Bin/../../dumping_tools/classes/";

use utf8;
use strict;
use warnings;

use Getopt::Long;

my $showHelp;
my $directory;
my $source;

sub usage() {
    print "manageLibraryKiwixOrg.pl\n";
    print "\t--source=DIRECTORY\n";
    print "\t--directory=DIRECTORY\n";
    print "\t--help\n";
}

GetOptions(
    'help' => \$showHelp,
    'directory=s' => \$directory,
    'source=s' => \$source,
);

if ($showHelp) {
    usage();
    exit 0;
}

if (!$directory || !$source) {
    usage();
    exit 0;
}

# Create new library
`cat $source/library/library_zim.xml | sed -e "s/http:\\/\\/download.kiwix.org\\///" | sed -e "s/.meta4//" | sed -e "s/url=/path=/" | sed -e "s/tags=.*description/description/" | grep -v nodet | grep -v nopic | egrep -v "wikipedia.*all_2" > $directory/library.kiwix.org.xml`;

exit 0;

