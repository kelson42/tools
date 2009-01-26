#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("launchTntreader.pl");

# get the params
my $directory;
my $onlyLocal = 0;
my $port = "8080";

# Get console line arguments
GetOptions(
	   'directory=s' => \$directory,
	   'port=i' => \$port,
           'onlyLocal' => \$onlyLocal,
	   );

if (!$directory) {
    print "usage: ./launchTntreader.pl --directory=./ [--port=8080] [--onlyLocal]\n";
    exit;
}

# get the home of the user running the script
my $home = $ENV{HOME}; 

# write the TntReader config file
my $configTxt = "[TntReader]
port=$port
";

if ($onlyLocal) {
    $configTxt .= "localonly=1\n";
}
$configTxt .= "directory=$directory\n";

writeFile($home."/.TntReader", \$configTxt);

# launch TntReader
my $cmd = "TntReader";
`$cmd`;

sub writeFile {
    my $file = shift;
    my $data = shift;

    open (FILE, ">$file") or die "Couldn't open file: $file";
    print FILE $$data;
    close (FILE);
}
