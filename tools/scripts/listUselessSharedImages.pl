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
my $logger = Log::Log4perl->get_logger("listUselessSharedImage.pl");

# get the params
my $databaseHost = "localhost";
my $databasePort = "3306";
my $databasePrefix = "";
my $databaseUsername = "";
my $databasePassword = "";
my $commonDatabaseName = "";

# Variables
my ($sql, $dsn, $dbh, $sth);
my @databases;
my @uselessImages;

# Get console line arguments
GetOptions(
	   'databaseHost=s' => \$databaseHost,
	   'databasePort=s' => \$databasePort,
	   'databasePrefix=s' => \$databasePrefix,
	   'commonDatabaseName=s' => \$commonDatabaseName,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword
	   );

if (!$databasePrefix || !$commonDatabaseName) {
    print "usage: ./listSharedImagesToMirror.pl --databasePrefix=mirror_ --commonDatabaseName=foofoo [--databaseHost=localhost] [--databasePort=3306] [--databaseUsername=tom] [--databasePassword=fff]\n";
    exit;
}

# Get table list
$dsn = "dbi:mysql:information_schema;host=$databaseHost:$databasePort";
$dbh = DBI->connect($dsn, $databaseUsername, $databasePassword) or die ("Unable to connect to the database.");
$sql = "SHOW DATABASES";
$sth = $dbh->prepare($sql);
$sth->execute();

while (my @data = $sth->fetchrow_array()) {
    my $database = $data[0];
    if ($database =~ /^$databasePrefix*/ && ! ($database eq $commonDatabaseName) ) {
	push(@databases, $database);
    }
}

print STDERR Dumper(@databases);

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
    
    push(@uselessImages, $image);
}

print STDERR "Images count in commons: ". scalar(@uselessImages)."\n";

foreach my $databaseName (@databases) {

    # Build the db connections
    $dbh->disconnect();
    $dsn = "DBI:mysql:$databaseName;host=$databaseHost:$databasePort";
    $dbh = DBI->connect($dsn, $databaseUsername, $databasePassword) or die ("Unable to connect to the database.");
    
    # Get missing images
    $sql = "SELECT DISTINCT imagelinks.il_to FROM imagelinks, page WHERE page.page_id = imagelinks.il_from AND il_to NOT IN (SELECT img_name FROM image)";
    $sth = $dbh->prepare($sql);
    $sth->execute();
    
    my @sharedImages;
    while (my @data = $sth->fetchrow_array()) {
	my $image = $data[0];
	
	unless (Encode::is_utf8($image)) {
	    $image = decode_utf8($image);
	}
	
	push(@sharedImages, $image);
    }

    # Compare the two list
    my $lc = List::Compare->new( {
	lists    => [\@uselessImages, \@sharedImages],
	unsorted => 1,
    } );

    my @tmp = $lc->get_unique();
    @uselessImages = @tmp;

    print STDERR "Useless images after $databaseName: ". scalar(@uselessImages)."\n";
}

# Print the imges
foreach my $image (@uselessImages) {
    print "File:".$image."\n";
}

exit;
