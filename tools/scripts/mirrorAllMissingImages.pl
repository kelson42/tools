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
my $logger = Log::Log4perl->get_logger("mirrorAllMissingImages.pl");

# get the params
my $sourceHost = "";
my $sourcePath = "";
my $destinationHost = "";
my $destinationPath = "";
my $destinationUsername = "";
my $destinationPassword = "";
my $destinationLocalPath = "";
my $destinationDatabaseName = "";
my $commonHost = "";
my $commonUsername = "";
my $commonPassword = "";
my $commonDatabaseName = "";
my $databaseUsername = "";
my $databasePassword = "";
my $tmpDir = "/tmp";
my $rand=time;
my $cmd;

# Get console line arguments
GetOptions('sourceHost=s' => \$sourceHost,
	   'sourcePath=s' => \$sourcePath,
	   'destinationHost=s' => \$destinationHost,
	   'destinationPath=s' => \$destinationPath,
	   'destinationUsername=s' => \$destinationUsername,
	   'destinationPassword=s' => \$destinationPassword,
	   'destinationLocalPath=s' => \$destinationLocalPath,
	   'destinationDatabaseName=s' => \$destinationDatabaseName,
	   'commonHost=s' => \$commonHost,
	   'commonDatabaseName=s' => \$commonDatabaseName,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword,
	   'tmpDir=s' => \$tmpDir
	   );

# Print usage() if necessary
if (!$sourceHost || !$destinationHost || !$destinationLocalPath) {
    print "usage: ./mirrorAllMissingImages.pl --sourceHost=fr.wikipedia.org --destinationHost=fr.wikipedia.org.zimfarm.kiwix.org --destinationLocalPath=/var/www/fr.wikipedia.org [--sourcePath=w] [--destinationPath=w] [--destinationUsername=foo] [--destinationPassword=bar] [--commonHost=commons.wikimedia.org.zimfarm.kiwix.org] [--commonDatabaseName=mirror_common] [--databaseUsername=foo] --databasePassword=bar] [--destinationDatabaseName=foobar] [--tmpDir=/tmp]\n";
    exit;
}

# Few asumptions
$commonUsername = $destinationUsername;
$commonPassword = $destinationPassword;

# Init
my $imageListPath="$tmpDir/$rand";

# List local images to mirror
$cmd="./listLocalImagesToMirror.pl --directory=\"$destinationLocalPath\" > $imageListPath"; `$cmd`;

# Mirror local images
$cmd="cat $imageListPath | ./mirrorMediawikiPages.pl --readFromStdin --sourceHost=$sourceHost --sourcePath=$sourcePath --destinationHost=$destinationHost --destinationUsername=$destinationUsername --destinationPassword=$destinationPassword --dontFollowRedirects --noResume --ignoreTemplateDependences --ignoreImageDependences --noTextMirroring --ignoreEmbeddedInPagesCheck"; `$cmd`;

# List shared images to mirror
$cmd="./listSharedImagesToMirror.pl --databaseName=$destinationDatabaseName --commonDatabaseName=$commonDatabaseName --databaseUsername=$databaseUsername --databasePassword=$databasePassword > $imageListPath"; `$cmd`;

# Mirror shared images
$cmd="cat $imageListPath | ./mirrorMediawikiPages.pl --readFromStdin --sourceHost=commons.wikimedia.org --sourcePath=w --destinationHost=$commonHost --destinationUsername=$commonUsername --destinationPassword=$commonPassword --dontFollowRedirects --noResume --ignoreTemplateDependences --ignoreImageDependences --noTextMirroring --ignoreEmbeddedInPagesCheck"; `$cmd`;

# Clean
$cmd="rm $imageListPath"; `$cmd`;

exit;
