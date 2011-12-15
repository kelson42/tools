#!/usr/bin/perl

use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Kiwix::ZimWriter;
use Kiwix::Logger;
use Whereis;

# log
my $logger = Kiwix::Logger->new("builZimFileFromDirectory.pl");

# get the params
my $writerPath;
my $htmlPath;
my $welcomePage;
my $favicon;
my $compressAll;
my $zimFilePath="./articles";
my $dbUser="kiwix";
my $dbHost="localhost";
my $dbPort="5432";
my $dbPassword="";
my $rewriteCDATA;
my $strict;
my $mediawikiOptim;
my $shortenUrls;
my $removeUnusedRedirects;
my $avoidForceHtmlCharsetToUtf8;
my $doNotDeleteDbAtTheEnd;
my $doNotIgnoreFiles;
my $dbName=time();
my %metadata;
my $writer = Kiwix::ZimWriter->new();

# Get console line arguments
GetOptions('writerPath=s' => \$writerPath, 
	   'htmlPath=s' => \$htmlPath,
	   'zimFilePath=s' => \$zimFilePath,
	   'dbName=s' => \$dbName,
	   'dbPort=s' => \$dbPort,
	   'dbHost=s' => \$dbHost,
	   'dbUser=s' => \$dbUser,
	   'dbPassword=s' => \$dbPassword,
	   'mediawikiOptim' => \$mediawikiOptim,
	   'rewriteCDATA' => \$rewriteCDATA,
	   'doNotDeleteDbAtTheEnd' => \$doNotDeleteDbAtTheEnd,
	   'doNotIgnoreFiles' => \$doNotIgnoreFiles,
	   'strict' => \$strict,
	   'compressAll' => \$compressAll,
	   'shortenUrls' => \$shortenUrls,
	   'removeUnusedRedirects' => \$removeUnusedRedirects,
	   'welcomePage=s' => \$welcomePage,
	   'favicon=s' => \$favicon,
	   'avoidForceHtmlCharsetToUtf8' => \$avoidForceHtmlCharsetToUtf8,
	   'language=s' => \$metadata{'Language'},
	   'title=s' => \$metadata{'Title'},
	   'creator=s' => \$metadata{'Creator'},
	   'description=s' => \$metadata{'Description'},
	   );

if (!$htmlPath || !$welcomePage || !$favicon || !$metadata{'Language'} || !$metadata{'Title'} || !$metadata{'Creator'} || !$metadata{'Description'}) {
    print "usage: builZimFileFromDirectory.pl --htmlPath=./html --welcomePage=index.html --favicon=images/favicon.png --language=fr --title=foobar --creator=foobar --decription=mydescription [--dbUser=foobar] [--dbPassword=testpass] [--writerPath=./zimWriter] [--zimFilePath=articles.zim] [--dbName=kiwix_db] [--dbPort=5432] [--dbHost=localhost] [--rewriteCDATA] [--mediawikiOptim] [--shortenUrls] [--removeUnusedRedirects] [--strict] [--avoidForceHtmlCharsetToUtf8] [--compressAll] [--doNotDeleteDbAtTheEnd] [--doNotIgnoreFiles]\n";
    exit;
}

# try to detect the zimwriter path or test it (if given)
unless ($writerPath) {
    $writerPath = whereis('zimwriterdb') || whereis("zimwriter");
}
unless ($writerPath) {
    print STDERR "Unable to find zimwriter or zimwriterdb\n";
    exit;
}

# Check if with have a writerpath
unless (-x $writerPath) {
    $logger->error("The zim writer '$writerPath' does not exist or is not executable.");
    exit;
}

# test the html directory
unless (-d $htmlPath) {
    $logger->error("The html directory '$htmlPath' does not exist.");
    exit;
}

# remove the ".zim" at the end of the zimFilePath
$zimFilePath =~ s/\.zim$//;

# check welcome page format
if (substr($welcomePage, 0, 1) eq '.' || substr($welcomePage, 0, 1) eq '/') {
    print(STDERR "The welcomePage parameter is a path relative to the htmlPath parameter. It can not start with '.' or a '/'.\n");
    exit;
}

# check if the welcomePage exists
unless ( -f $htmlPath."/".$welcomePage) {
    print(STDERR "The file ".$htmlPath."/".$welcomePage." does not exist.\n");
    exit;    
}

# check if the favicon exists
unless ( -f $htmlPath."/".$favicon) {
    print(STDERR "The file ".$htmlPath."/".$favicon." does not exist.\n");
    exit;    
}

# Favicon must be png
unless ($writer->mimeDetector->getMimeType($htmlPath."/".$favicon) eq "image/png") {
    print(STDERR "The favicon file ".$htmlPath."/".$favicon." must be a PNG file.\n");
    exit;
}

# Add auto. the date metadata
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$metadata{"Date"} = (1900+$year)."-".sprintf("%02d", $mon+1)."-".sprintf("%02d", $mday);

# initialization
$writer->logger($logger);
$writer->writerPath($writerPath);
$writer->htmlPath($htmlPath);
$writer->compressAll($compressAll);
$writer->zimFilePath($zimFilePath);
$writer->dbName($dbName);
$writer->dbUser($dbUser);
$writer->dbPort($dbPort);
$writer->dbHost($dbHost);
$writer->dbPassword($dbPassword);
$writer->welcomePage($welcomePage);
$writer->favicon($favicon);
$writer->mediawikiOptim($mediawikiOptim);
$writer->rewriteCDATA($rewriteCDATA);
$writer->strict($strict);
$writer->avoidForceHtmlCharsetToUtf8($avoidForceHtmlCharsetToUtf8);
$writer->shortenUrls($shortenUrls);
$writer->removeUnusedRedirects($removeUnusedRedirects);
$writer->metadata(\%metadata);
$writer->doNotIgnoreFiles($doNotIgnoreFiles);

# Create database
$writer->createDatabase();

# prepare urls rewreting
$logger->info("Starting ZIM building process.");
$writer->prepareUrlRewriting();

# loads the data from the directory to the db
$writer->fillDatabase();
$writer->buildZimFile();

# delete database
unless ($doNotDeleteDbAtTheEnd) {
    $writer->deleteDatabase();
}
