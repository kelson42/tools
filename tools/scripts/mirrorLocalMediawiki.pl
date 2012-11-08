#!/usr/bin/perl

use lib "../";
use lib "../Mediawiki/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Term::Query qw( query query_table query_table_set_defaults query_table_process );
use DBI;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("mirrorLocalMediawik.pl");

# get the params
my $sourcePath = "";
my $destinationPath = "";
my $languageCode = "";
my $databaseName = "";
my $tmpDir = "/tmp";
my $cmd;

# Get console line arguments
GetOptions('sourcePath=s' => \$sourcePath,
	   'destinationPath=s' => \$destinationPath,
	   'languageCode=s' => \$languageCode,
	   'databaseName=s' => \$databaseName,
	   'tmpDir=s' => \$tmpDir
	   );

# Print usage() if necessary
if (!$sourcePath || !$destinationPath || !$databaseName || !$languageCode) {
    print "usage: ./mirrorLocalMediawiwki.pl --sourcePath=./enwiki --destinationPath=./frwiki --databaseName=MYDB --languageCode=es [--tmpDir=/tmp]\n";
    exit;
}

# Check paths
if (! -e $sourcePath) {
    print STDERR "Source path '$sourcePath' does not exist.\n";
    exit 1;
}

# Read conf file
my $conf = readFile("$sourcePath/LocalSettings.php");

# Replicate database
my $sourceDatabaseName;
my $databaseUsername;
my $databasePassword;

if ($conf =~ /\$wgDBname[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $sourceDatabaseName = $1;
} else {
    print STDERR "Impossible to detect source database name."
}

if ($conf =~ /\$wgDBuser[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databaseUsername = $1;
} else {
    print STDERR "Impossible to detect database username."
}

if ($conf =~ /\$wgDBpassword[\t ]*=[\t ]*[\'\"](.*)[\'\"]/) {
    $databasePassword = $1;
} else {
    print STDERR "Impossible to detect database password."
}

$cmd = "mysqldump -u $databaseUsername -p$databasePassword --databases $sourceDatabaseName | grep -v $sourceDatabaseName > $tmpDir/$sourceDatabaseName.sql"; `$cmd`;
$cmd = "echo 'CREATE DATABASE $databaseName' | mysql -u $databaseUsername -p$databasePassword"; `$cmd`;
$cmd = "cat $tmpDir/$sourceDatabaseName.sql | mysql -u $databaseUsername -p$databasePassword $databaseName"; `$cmd`;

# Copy the files
$cmd = "for FILE in `find \"$sourcePath\" -mindepth 1 -maxdepth 1 | grep -v images | grep -v static | grep -v html | grep -v \".svn\"` ; do cp -rf \$FILE \"$destinationPath\" ; done"; `$cmd`;

# Deal with images
if (! -e $destinationPath."/images/") {
    $cmd = "mkdir \"$destinationPath/images\""; `$cmd`;
    $cmd = "mkdir \"$destinationPath/images/archive\""; `$cmd`;
    $cmd = "mkdir \"$destinationPath/images/deleted\""; `$cmd`;
    $cmd = "mkdir \"$destinationPath/images/math\""; `$cmd`;
    $cmd = "mkdir \"$destinationPath/images/thumb\""; `$cmd`;
    $cmd = "mkdir \"$destinationPath/images/timeline\""; `$cmd`;
    $cmd = "mkdir \"$destinationPath/images/tmp\""; `$cmd`;
    $cmd = "ln -s \"$destinationPath/images\" \"$destinationPath/images/local\""; `$cmd`;
    
    if (-l "$sourcePath/images/shared") {
	$cmd = "ln -s \`readlink \"$sourcePath/images/shared\"\` \"$destinationPath/images/shared\""; `$cmd`;
    } else {
	$cmd = "mkdir \"$destinationPath/images/shared\""; `$cmd`;
    }
}

# Change conf file
$conf =~ s/(\$wgDBname[\t ]*=[\t ]*[\'\"])(.*)([\'\"])/$1$databaseName$3/;
$conf =~ s/(\$wgLanguageCode[\t ]*=[\t ]*[\'\"])(.*)([\'\"])/$1$languageCode$3/;
writeFile("$destinationPath/LocalSettings.php", $conf);

sub writeFile {
    my $file = shift;
    my $data = shift;

    $logger->info("Writing file $file ...");

    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    my $content = "";

    $logger->info("Reading file $file ...");

    open(FILE, '<:utf8', $file);
    while (my $line = <FILE>) {
	$content .= $line;
    }
 
    return $content;
}

exit;
