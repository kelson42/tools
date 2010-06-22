#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;

use lib "../classes/";

use DBI;
use strict;
use warnings;
use List::Compare;
use Getopt::Long;
use Data::Dumper;
use Encode;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("listSharedImageToMirror.pl");

# get the params
my $databaseHost = "localhost";
my $databasePort = "3306";
my $databaseName = "";
my $databaseUsername = "";
my $databasePassword = "";
my $commonDatabaseName = "";

# Variables
my $sql;
my @missingImages;
my @commonImages;
my @imagesToMirror;

# Get console line arguments
GetOptions(
	   'databaseHost=s' => \$databaseHost,
	   'databasePort=s' => \$databasePort,
	   'databaseName=s' => \$databaseName,
	   'commonDatabaseName=s' => \$commonDatabaseName,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword
	   );

if (!$databaseName || !$commonDatabaseName) {
    print "usage: ./listSharedImagesToMirror.pl --databaseName=mirror_foo --commonDatabaseName=foofoo [--databaseHost=localhost] [--databasePort=3306] [--databaseUsername=tom] [--databasePassword=fff]\n";
    exit;
}

# Build the db connections
my $dsn = "DBI:mysql:$databaseName;host=$databaseHost:$databasePort";
my $dbh = DBI->connect($dsn, $databaseUsername, $databasePassword) or die ("Unable to connect to the database.");
my $sth;

# Get missing images
$sql = "SELECT DISTINCT imagelinks.il_to FROM imagelinks, page WHERE page.page_id = imagelinks.il_from AND il_to NOT IN (SELECT img_name FROM image)";
$sth = $dbh->prepare($sql);
$sth->execute();

while (my @data = $sth->fetchrow_array()) {
    my $image = $data[0];
    
    unless (Encode::is_utf8($image)) {
	$image = decode_utf8($image);
    }
    
    push(@missingImages, $image);
}

# Database disconnection an reconnection to common Database
$dbh->disconnect();
$dsn = "DBI:mysql:$commonDatabaseName;host=$databaseHost:$databasePort";
$dbh = DBI->connect($dsn, $databaseUsername, $databasePassword) or die ("Unable to connect to the database.");

# Get commons images
$sql = "SELECT img_name FROM image";
$sth = $dbh->prepare($sql);
$sth->execute();

while (my @data = $sth->fetchrow_array()) {
    my $image = $data[0];
    
    unless (Encode::is_utf8($image)) {
	$image = decode_utf8($image);
    }
    
    push(@commonImages, $image);
}

# Compare the two list
my $lc = List::Compare->new( {
    lists    => [\@missingImages, \@commonImages],
    unsorted => 1,
                           } );
@imagesToMirror = $lc->get_unique();

# Print the imges
foreach my $image (@imagesToMirror) {
    print "File:".$image."\n";
}

exit;
