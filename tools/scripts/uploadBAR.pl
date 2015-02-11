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
my $commons;
my $templateCode = "=={{int:filedesc}}==
{{CH-BAR-picture
|wiki description =
|short title      = <TMPL_VAR NAME=TITLE>
|archive title    =
|original title   = <TMPL_VAR NAME=ORIGINAL_TITLE>
|biased           =
|medium           = <TMPL_VAR NAME=MEDIUM>
|depicted place   = <TMPL_VAR NAME=PLACE>
|depicted people  = <TMPL_VAR NAME=PEOPLE>
|photographer     = <TMPL_VAR NAME=AUTHOR>
|date             = <TMPL_VAR NAME=DATE>
|year             = 
|ID               = <TMPL_VAR NAME=SYSID>
|inventory        = 
|other versions   = 
|source           = Swiss Federal Archives
|permission       = CC-BY-SA 3.0/CH
}}

=={{int:license}}==
{{cc-by-sa-3.0-ch|
attribution=DE: Schweizerisches Bundesarchiv, CH-BAR#<TMPL_VAR NAME=SIGNATURE> / CC-BY-SA 3.0/CH<br/>
EN: Swiss Federal Archives, CH-SFA#<TMPL_VAR NAME=SIGNATURE> / CC-BY-SA 3.0/CH<br/>
FR: Archives fédérales suisses, CH-AFS#<TMPL_VAR NAME=SIGNATURE> / CC-BY-SA 3.0/CH<br/>
IT : Archivio federale svizzero, CH-AFS#<TMPL_VAR NAME=SIGNATURE> / CC-BY-SA 3.0/CH
}}
{{Swiss Federal Archive}}

[[Category:CH-BAR Collection First World War Switzerland]]
[[Category:CH-BAR Collection First World War Switzerland uncategorized]]
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
	|| $id eq "14095_1151a_A1.tif"
	) {
	next;
    }
    unless (-e $pictureDirectory."/lr/".$id) {
	print STDERR "Unable to find file $pictureDirectory/lr/$id\n";
	exit(1);
    }

    my $hrId = $id;
    $hrId =~ s/A1/S1/;
    unless (-e $pictureDirectory."/hr/".$hrId) {
	print STDERR "Unable to find file $pictureDirectory/hr/$hrId\n";
	exit(1);
    }
    $image{'hrId'} = $hrId;

    my $filename = $sheet->{Cells}[$row][2]->{Val};
    unless($filename) {
	print STDERR "Unable to find new filename for $pictureDirectory/$id\n";
	exit(1);
    }
    $filename =~ s/[ ]+/_/g;
    $filename =~ s/&amp;/-/g;
    $image{'filename'} = $filename;

    my $originalTitle = $sheet->{Cells}[$row][3]->{Val} || "";
    utf8::decode($originalTitle);
    $originalTitle =~ s/\r\n/<br\/>/gm;
    $originalTitle =~ s/\n/<br\/>/gm;
    $image{'originalTitle'} = $originalTitle;

    my $people = $sheet->{Cells}[$row][4]->{Val} || "";
    utf8::decode($people);
    $image{'people'} = $people;

    my $place = $sheet->{Cells}[$row][5]->{Val} || "";
    utf8::decode($place);
    $image{'place'} = $place;

    my $author = $sheet->{Cells}[$row][6]->{Val} || "";
    utf8::decode($author);
    $image{'author'} = $author;

    my $date = $sheet->{Cells}[$row][7]->{Val} || "";
    $date = ($date =~ m/^\d+$/ && $date > 2000) ? "" : $date;
    $image{'date'} = $date;

    my $sysid = $sheet->{Cells}[$row][8]->{Val} || "";
    $image{'sysid'} = $sysid;

    my $signature = $sheet->{Cells}[$row][9]->{Val} || "";
    $signature =~ s/CH\-BAR//g;
    $image{'signature'} = $signature;

    my $title = $sheet->{Cells}[$row][11]->{Val} || "";
    utf8::decode($title);
    $image{'title'} = $title;

    my $medium = "{{de|".($sheet->{Cells}[$row][14]->{Val} || "").", ".($sheet->{Cells}[$row][15]->{Val} || "")."}}";
    utf8::decode($medium);
    $image{'medium'} = $medium;

    $images{$id} = \%image;
}

# Go through all images
my $ok = 1;
foreach my $imageId (keys(%images)) {
    my $image = $images{$imageId};

    # Check the filter
    if (!$imageId && !scalar(@filters) || 
	$imageId && scalar(@filters) && !(grep {$_ eq $imageId} @filters)) {
	next;
    }

    # Get image path
    my $filename = "$pictureDirectory/lr/$imageId";
    my $hrFilename = "$pictureDirectory/hr/".$image->{'hrId'};
    my $newFilename = $image->{'filename'};
    utf8::decode($newFilename);

    unless($ok) {
	if ($newFilename eq "Vorbereitete_Mitrailleureailleurstellung_-_CH-BAR_-_3237556.tif") {
	    $ok = 1;
	}
	next;
    }

    # Preparing description
    my $template = HTML::Template->new(scalarref => \$templateCode);
    $template->param(ORIGINAL_TITLE=>$image->{'originalTitle'});
    $template->param(TITLE=>$image->{'title'});
    $template->param(AUTHOR=>$image->{'author'});
    $template->param(DATE=>$image->{'date'});
    $template->param(SYSID=>$image->{'sysid'});
    $template->param(SIGNATURE=>$image->{'signature'});
    $template->param(MEDIUM=>$image->{'medium'});
    $template->param(PLACE=>$image->{'place'});
    $template->param(PEOPLE=>$image->{'people'});
    my $description = $template->output();
    utf8::decode($description);

    # local check if already done
    my $doneFile = $filename.".done";
    if (-f $doneFile) {
	if ( !$overwrite && !$overwriteDescriptionOnly ) {
	    printLog("'File:$newFilename' already exists in Wikimedia Commons, it was ignores. Use --overwrite to force the re-upload ($doneFile).");
	    next;
	}
    }

    # Connect to Wikimedia Commons
    $commons = connectToCommons();
    printLog("Successfuly connected to Wikimedia Commons.");

    my $doesExist = $commons->exists("File:$newFilename");
    if (!$doesExist || $overwrite || $overwriteDescriptionOnly) {

	my $status;
	my $content;

	# Check connections to remote services
	connectToCommons();

	if (!$doesExist || $overwrite) {
	    $content = readFile($hrFilename);
	    printLog("Reading $hrFilename");
	    printLog("'$newFilename' uploading original version...");
	    uploadImage($newFilename, $content, $description, "GLAM - Swiss Federal Archives picture' ".$image->{'sysid'}."' - Original - (WMCH)");

	    $content = readFile($filename);
	    printLog("Reading $filename");
	    printLog("'$newFilename' uploading improved version...");
	    uploadImage($newFilename, $content, $description, "GLAM - Swiss Federal Archives picture' ".$image->{'sysid'}."' - Improved - (WMCH)");
	} elsif ($doesExist && $overwriteDescriptionOnly) {
	    printLog("'$newFilename' already uploaded but will description will be overwritten...");
	    $status = $commons->uploadPage("File:".$newFilename, $description, "Description update...");

	    if ($status) {
		printLog("'$newFilename' description successfuly uploaded to Wikimedia Commons.");
		writeFile($doneFile, "");
	    } else {
		die "'$newFilename' description failed to be uploaded to Wikimedia Commons.\n";
	    }
	}
	
    } else {
	printLog("'File:$newFilename' already exists in Wikimedia Commons, it was ignores. Use --overwrite to force the re-upload.");
    }
    
    # Write check file
    writeFile($doneFile, "");
    
    if ($newFilename eq "Mitrailleure_beim_Schulschiessen_-_CH-BAR_-_3237730.tif") {
	exit 1;
    }
    
    # Wait a few seconds
    if ($delay) {
	printLog("Waiting $delay s...");
	sleep($delay);
    }
}

sub uploadImage {
    my $newFilename = shift;
    my $content = shift;
    my $description = shift;
    my $comment = shift;

    my$status = $commons->uploadImage($newFilename, $content, $description, $comment, 1);

    if ($status) {
	printLog("'$newFilename' was successfuly uploaded to Wikimedia Commons.");
    } else {
	die "'$newFilename' failed to be uploaded to Wikimedia Commons.\n";
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
