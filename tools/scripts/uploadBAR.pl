#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use utf8;
use strict;
use warnings;
use Spreadsheet::XLSX;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;
use HTML::Template;
use File::Basename;

my $commonsHost = "commons.wikimedia.org";
my $overwrite = 0;
my $overwriteDescriptionOnly = 0;
my $username;
my $password;
my $pictureDirectory;
my $metadataPath;
my $metadataFile;
my @filters;
my $help;
my $delay = 0;
my $verbose;
my $templateCode = "=={{int:filedesc}}==
== {{int:filedesc}} ==
{{CH-BAR-picture
|wiki description =
|short title      =
|archive title    =
|original title   = <TMPL_VAR NAME=TITLE>
|biased           =
|medium           = <TMPL_VAR NAME=MEDIUM>
|depicted people  = <TMPL_VAR NAME=PLACE>
|depicted place   = <TMPL_VAR NAME=PEOPLE>
|photographer     = <TMPL_VAR NAME=AUTHOR>
|date             = <TMPL_VAR NAME=DATE>
|year             = 
|ID               = <TMPL_VAR NAME=SYSID>
|inventory        = 
|other versions   = 
|source           = 
|permission       = CC-BY-SA
}}

=={{int:license}}==
{{cc-by-sa-3.0-ch|attribution=Schweizerisches Bundesarchiv (BAR), <TMPL_VAR NAME=SIGNATURE> / CC-BY-SA }}
{{Swiss Federal Archive}}

[[Category:CH-BAR Collection First World War Switzerland]]
";

sub usage() {
    print "uploadBAR.pl is a script to upload files from the Swiss Federal Archive.\n";
    print "\tuploadZBS --username=<COMMONS_USERNAME> --password=<COMMONS_PASSWORD> --directory=<PICTURE_DIRECTORY> --metadata=<XLSX_PATH>\n\n";
    print "In addition, you can specify a few additional arguments:\n";
    print "--filter=<ID>                    Upload only this/these image(s)\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two uploads\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console\n";
    print "--overwrite                      Force re-upload of picture\n";
    print "--overwriteDescriptionOnly       Force re-upload of the description\n";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'metadata=s' => \$metadataPath,
	   'directory=s' => \$pictureDirectory,
	   'delay=s' => \$delay,
	   'verbose' => \$verbose,
	   'overwrite' => \$overwrite,
	   'overwriteDescriptionOnly' => \$overwriteDescriptionOnly,
	   'filter=s' => \@filters,
	   'help' => \$help,
);

if ($help) {
    usage();
    exit 0;
}

# Make a few security checks
if (!$username || !$password || !$pictureDirectory || !$metadataPath) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--username=<COMMONS_USERNAME>\n\t--password=<COMMONS_PASSWORD>\n\t--directory=<PICTURE_DIRECTORY>\n\t--metadata=<XLSX_PATH>\n";
    exit;
};

unless (-d $pictureDirectory) {
    die "'$pictureDirectory' seems not to be a valid directory.";
}

unless (-f $metadataPath) {
    die "'$metadataPath' seems not to be a valid XLSX path.";
}

unless ($delay =~ /^[0-9]+$/) {
    die "The delay '$delay' seems not valid. This should be a number.";
}

# Check connections to remote services
connectToCommons();

# Select all images from the XLSX file
my %images; 
my $excel = Spreadsheet::XLSX->new($metadataPath);
my $sheet = shift(@{$excel->{Worksheet}});
$sheet = shift(@{$excel->{Worksheet}});
$sheet->{MaxRow} ||= $sheet->{MinRow};
foreach my $row (1 .. $sheet->{MaxRow}) {
    my %image;

    my $id = $sheet->{Cells}[$row][0]->{Val};
    unless ($id) {
	next;
    }

    $id =~ s/A_/a_/;
    $id =~ s/A_/b_/;
    if ($id eq "14095_0715_A1.tif" 
	|| $id eq "14095_1151b_A1.tif" 
	|| $id eq "14095_3644_A1.tif"
	|| $id eq "14095_3930_A1.tif"
	|| $id eq "14095_4256_A1.tif"
	|| $id eq "14095_4868_A1.tif"
	|| $id eq "14095_4903_A1.tif"
	) {
	next;
    }
    unless (-e $pictureDirectory."/".$id) {
	print STDERR "Unable to find file $pictureDirectory/$id\n";
	exit(1);
    }

    my $filename = $sheet->{Cells}[$row][2]->{Val};
    unless($filename) {
	print STDERR "Unable to find new filename for $pictureDirectory/$id\n";
	exit(1);
    }
    $filename =~ s/[ ]+/_/g;
    $image{'filename'} = $filename;

    my $place = $sheet->{Cells}[$row][5]->{Val} || "";
    $image{'place'} = $place;

    my $author = $sheet->{Cells}[$row][6]->{Val} || "";
    $image{'author'} = $author;

    my $date = $sheet->{Cells}[$row][7]->{Val} || "";
    $date = ($date =~ m/^\d+$/ && $date > 2000) ? "" : $date;
    $image{'date'} = $date;

    my $sysid = $sheet->{Cells}[$row][8]->{Val} || "";
    $image{'sysid'} = $sysid;

    my $signature = $sheet->{Cells}[$row][9]->{Val} || "";
    $image{'signature'} = $signature;

    my $title = $sheet->{Cells}[$row][11]->{Val} || "";
    $image{'title'} = $title;

    my $medium = "{{de|".($sheet->{Cells}[$row][14]->{Val} || "").", ".($sheet->{Cells}[$row][15]->{Val} || "")."}}";
    $image{'medium'} = $medium;

    $images{$id} = \%image;
}

# Go through all images
foreach my $imageId (keys(%images)) {
    my $image = $images{$imageId};

    # Check the filter
    if (!$imageId && !scalar(@filters) || 
	$imageId && scalar(@filters) && !(grep {$_ eq $imageId} @filters)) {
	next;
    }

    # Get image path
    my $filename = "$pictureDirectory/$imageId";
    my $newFilename = $image->{'filename'};
    utf8::decode($newFilename);

    # Preparing description
    my $template = HTML::Template->new(scalarref => \$templateCode);
    $template->param(TITLE=>$image->{'title'});
    $template->param(AUTHOR=>$image->{'author'});
    $template->param(DATE=>$image->{'date'});
    $template->param(SYSID=>$image->{'sysid'});
    $template->param(SIGNATURE=>$image->{'signature'});
    $template->param(MEDIUM=>$image->{'medium'});
    $template->param(PLACE=>$image->{'place'});
    my $description = $template->output();
    utf8::decode($description);

    # local check if already done
    my $doneFile = $filename.".done";
    if (-f $doneFile) {
	if ( !$overwrite && !$overwriteDescriptionOnly ) {
	    printLog("'File:$newFilename' already exists in Wikimedia Commons, it was ignores. Use --overwrite to force the re-upload.");
	    next;
	}
    }

    # Connect to Wikimedia Commons
    my $commons = connectToCommons();
    printLog("Successfuly connected to Wikimedia Commons.");

    my $doesExist = $commons->exists("File:$newFilename");
    if (!$doesExist || $overwrite || $overwriteDescriptionOnly) {

	my $status;
	my $content = readFile($filename);

	if (!$doesExist) {
	    printLog("'$newFilename' uploading...");
	    $status = $commons->uploadImage($newFilename, $content, $description, "GLAM - Swiss Federal Archives picture' ".$image->{'sysid'}."' (WMCH)", 0);
	} elsif ($doesExist && $overwrite) {
	    printLog("'$newFilename' already uploaded but will be overwritten...");
	    $status = $commons->uploadImage($newFilename, $content, $description, "GLAM - Swiss Federal Archives picture' ".$image->{'sysid'}."' (WMCH)");
	} elsif ($doesExist && $overwriteDescriptionOnly) {
	    printLog("'$newFilename' already uploaded but will description will be overwritten...");
	    $status = $commons->uploadPage("File:".$newFilename, $description, "Description update...");
	}
	
	print $status."\n";

	if ($status) {
	    printLog("'$newFilename' was successfuly uploaded to Wikimedia Commons.");
	    writeFile($doneFile, "");
	} else {
	    die "'$newFilename' failed to be uploaded to Wikimedia Commons.\n";
	}
    } else {
	printLog("'File:$newFilename' already exists in Wikimedia Commons, it was ignores. Use --overwrite to force the re-upload.");
	writeFile($doneFile, "");
    }
    
    # Wait a few seconds
    if ($delay) {
	printLog("Waiting $delay s...");
	sleep($delay);
    }
}

# Read/Write functions
sub writeFile {
    my $file = shift;
    my $data = shift;
    utf8::encode($data);
    utf8::encode($file);
    open (FILE, ">", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    utf8::encode($file);
    open FILE, $file or die $!;
    binmode FILE;
    my ($buf, $data, $n);
    while (($n = read FILE, $data, 4) != 0) { 
	$buf .= $data;
    }
    close(FILE);
    utf8::decode($data);
    return $buf;
}

# Setup the connection to Mediawiki
sub connectToCommons {
    my $site = Mediawiki::Mediawiki->new();
    $site->hostname($commonsHost);
    $site->path("w");
    $site->user($username);
    $site->password($password);

    my $connected = $site->setup();
    unless ($connected) {
	die "Unable to connect with this username/password to $commonsHost.";
    }

    return $site;
}

# Logging function
sub printLog {
    my $message = shift;
    if ($verbose) {
	utf8::encode($message);
	print "$message\n";
    }
}
