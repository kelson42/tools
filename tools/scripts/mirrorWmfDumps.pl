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
my $logger = Log::Log4perl->get_logger("mirrorMediawikiWmfDumps.pl");

# get the params
my $databaseHost = "localhost";
my $databasePort = "3306";
my $databaseName = "";
my $databaseUsername = "";
my $databasePassword = "";
my $projectCode = "";
my $withoutImages;
my $tmpDir = "/tmp";
my $version = "latest";
my $cmd;

## Get console line arguments
GetOptions('databaseHost=s' => \$databaseHost,
	   'databasePort=s' => \$databasePort,
	   'databaseName=s' => \$databaseName,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword,
	   'projectCode=s' => \$projectCode,
	   'withoutImages' => \$withoutImages,
	   'version=s' => \$version,
	   'tmpDir=s' => \$tmpDir,
	   );

if (!$databaseName || !$projectCode) {
    print "usage: ./mirrorWmfDumps.pl --projectCode=enwiki --databaseName=MYDB [--tmpDir=/tmp] [--databaseHost=localhost] [--databasePort=3306] [--databaseUsername=tom] [--databasePassword=fff] [--withoutImages] [--version=latest]\n";
    exit;
}

if ($databaseUsername && !$databasePassword) {
    $databasePassword = query("Database password:", "");
}

# Create temporary directory
$tmpDir = $tmpDir."/wmfDumps";
`mkdir $tmpDir`;

# Download the XML & SQL files
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-pages-articles.xml.bz2"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-interwiki.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-imagelinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-pagelinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-redirect.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-templatelinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-externallinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-categorylinks.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-category.sql.gz"; `$cmd`;
$cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-langlinks.sql.gz"; `$cmd`;

unless ($withoutImages) {
    $cmd = "cd $tmpDir ; wget -c http://download.wikimedia.org/$projectCode/$version/$projectCode-$version-image.sql.gz"; `$cmd`;
}

# Install and compile the mwdumper
my $mwDumperDir = $tmpDir."/mwdumper/";
$cmd = "cd $tmpDir; svn co http://svn.wikimedia.org/svnroot/mediawiki/trunk/mwdumper/"; `$cmd`;
$cmd = "cd $mwDumperDir/src; javac org/mediawiki/dumper/Dumper.java"; `$cmd`; 

# Prepare DB connection
my $dsn = "DBI:mysql:$databaseName;host=$databaseHost:$databasePort";
my $dbh;
my $req;
my $sth;
$dbh = DBI->connect($dsn, $databaseUsername, $databasePassword) or die ("Unable to connect to the database.");

# Truncate necessary tables
foreach my $table ("revision", "page", "text", "imagelinks", "templatelinks", "interwiki", "redirect", "externallinks", "image", "langlinks", "math", "logging", "recentchanges", "searchindex", "pagelinks", "l10n_cache", "job", "category", "categorylinks", "archive", "filearchive" ) {
    $req = "TRUNCATE $table";
    $sth = $dbh->prepare($req)  or die ("Unable to prepare request.");
    $sth->execute() or die ("Unable to execute request.");
}

# Upload the XML
my $mysqlCmd = "mysql --user=$databaseUsername --password=$databasePassword $databaseName";

$cmd = "cd $mwDumperDir; java -classpath ./src org.mediawiki.dumper.Dumper --format=sql:1.5 ../$projectCode-$version-pages-articles.xml.bz2 | bzip2 > $projectCode-sql.bz2";
system "$cmd";

$cmd = "cd $mwDumperDir; bzip2 -c -d $projectCode-sql.bz2 | $mysqlCmd";
system "$cmd";

# Upload the SQL
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-interwiki.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-image.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-imagelinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-pagelinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-redirect.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-templatelinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-externallinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-categorylinks.sql.gz | $mysqlCmd"; `$cmd`;
$cmd = "gzip -d -c $tmpDir/$projectCode-$version-langlinks.sql.gz | $mysqlCmd"; `$cmd`;

unless ($withoutImages) {
    $cmd = "gzip -d -c $tmpDir/$projectCode-$version-image.sql.gz | $mysqlCmd"; `$cmd`;
}

exit;
