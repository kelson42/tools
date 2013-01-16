#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use strict;
use warnings;
use Getopt::Long;
use Getopt::Long;
use Data::Dumper;
use Encode;
use Kiwix::PathExplorer;
use Mediawiki::Mediawiki;
use HTML::Template;
use MARC::File::XML;

## Loading with USE options
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'UNIMARC' );

## Setting the record format without USE options
MARC::File::XML->default_record_format('USMARC');
    
## or reading with MARC::File::XML explicitly
my $file = MARC::File::XML->in( "/tmp/wikim1_marcxml_z39s_out2-1.xml" );

while (my $record = $file->next()) {
    print "Title:\t\t".$record->title_proper()."\n";
    print "Date:\t\t".$record->publication_date()."\n";
    print "Author:\t\t".$record->author()."\n";
    print "-------------\n";
}

my $username;
my $password;
my $pictureDirectory;
my $metadataFile;
my @filters;
my $help;
my $delay = 0;
my $verbose;
my $fsSeparator = '/';
sub usage() {
    print "uploadZB.pl is a script to upload files from the Zurich central library.\n";
    print "\tuploadZB --username=<COMMONS_USERNAME> --password=<COMMONS_PASSWORD> --directory=<PICTURE_DIRECTORY> --metadata=<XML_FILE>\n\n";
    print "In addition, you can specify a few additional arguments:\n";
    print "--filter=<ID>                    Upload only this/these image(s)\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two uploads\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console\n";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'directory=s' => \$pictureDirectory,
	   'metadataFile=s' => \$metadataFile,
	   'delay=s' => \$delay,
	   'verbose' => \$verbose,
	   'filter=s' => \@filters,
	   'help' => \$help,
);

if ($help) {
    usage();
    exit 0;
}

# Make a few security checks
if (!$username || !$password || !$pictureDirectory || !$metadataFile) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--username=<COMMONS_USERNAME>\n\t--password=<COMMONS_PASSWORD>\n\t--directory=<PICTURE_DIRECTORY>\n\t--metadata=<XML_FILE>\n";
    exit;
};

unless (-d $pictureDirectory) {
    print STDERR "'$pictureDirectory' seems not to be a valid directory.\n";
    exit 1;
}

unless (-f $metadataFile) {
    print STDERR "'$metadataFile' seems not to be a valid file.\n";
    exit 1;
}

unless ($delay =~ /^[0-9]+$/) {
    print STDERR "The delay '$delay' seems not valid. This should be a number.\n";
    exit 1;
}

# Read/Write functions
sub writeFile {
    my $file = shift;
    my $data = shift;
    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    open FILE, $file or die $!;
    binmode FILE;
    my ($buf, $data, $n);
    while (($n = read FILE, $data, 4) != 0) { 
	$buf .= $data;
    }
    close(FILE);
    return $buf;
}

# Setup the connection to Mediawiki
sub connectToMediawiki {
    my $host = shift;
    my $path = shift || "";
    my $noAuthentication = shift;
    my $site = Mediawiki::Mediawiki->new();
    $site->hostname($host);
    $site->path($path);
    unless ($noAuthentication) {
	$site->user($username);
	$site->password($password);
    }
    my $connected = $site->setup();
    if ($connected) {
	if ($verbose) {
	    printLog("Successfuly connected to $host");
	}
    } else {
	print STDERR "Unable to connect with this username/password to commons.wikimedia.org\n";
	exit 1;
    }

    return $site;
}

# Logging function
sub printLog {
    my $message = shift;
    if ($verbose) {
	print "$message\n";
    }
}
