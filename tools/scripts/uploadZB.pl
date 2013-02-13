#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;
use HTML::Template;
use MARC::File::XML;
use Image::Magick;
use Net::FTP;
use File::Basename;

my $jpegFile = "/tmp/uploadZB.tmp.jpg";
my $jpegDescriptionFile = "/tmp/uploadZB.tmp.jpg.desc";
my $commonsHost = "commons.wikimedia.org";
my $ftpHost = "zb.kiwix.org";
my $ftpPassword;
my $ftpUsername;
my $username;
my $password;
my $pictureDirectory;
my $metadataFile;
my @filters;
my $help;
my $delay = 0;
my $verbose;
my $simulate;
my $fsSeparator = '/';
my %metadatas;
my $templateCode = "=={{int:filedesc}}==
{{Artwork     
  |artist           = <TMPL_VAR NAME=AUTHOR>
  |title            = <TMPL_VAR NAME=TITLE>
  |description      = {{de|1=<TMPL_VAR NAME=DESCRIPTION>}} 
  |date             = <TMPL_VAR NAME=DATE>
  |medium           = <TMPL_IF NAME=MEDIUM>{{de|1=<TMPL_VAR NAME=MEDIUM>}}</TMPL_IF>
  |dimensions       = <TMPL_IF NAME=DIMENSIONS>{{de|1=<TMPL_VAR NAME=DIMENSIONS>}}</TMPL_IF>
  |institution      = {{institution:Zentralbibliothek Zürich}}
  |location         = <!-- location within the gallery/museum -->     
  |references       =
  |object history   =
  |credit line      =
  |inscriptions     =
  |notes            = 
  |accession number =
  |source           = {{Zentralbibliothek_Zürich_backlink|<TMPL_VAR NAME=UID>}}
  |permission       = Public domain
  |other_versions   = [[:File:<TMPL_VAR NAME=OTHER_VERSION>]]
    }}
{{Zentralbibliothek_Zürich}}

=={{int:license-header}}==
{{PD-old}}

[[Category:Media_contributed_by_Zentralbibliothek_Zürich]]";

sub usage() {
    print "uploadZB.pl is a script to upload files from the Zurich central library.\n";
    print "\tuploadZB --username=<COMMONS_USERNAME> --password=<COMMONS_PASSWORD> --directory=<PICTURE_DIRECTORY> --metadata=<XML_FILE> --ftpUsername=<FTP_USERNAME> --ftpPassword=<FTP_PASSWORD>\n\n";
    print "In addition, you can specify a few additional arguments:\n";
    print "--filter=<ID>                    Upload only this/these image(s)\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two uploads\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console\n";
    print "--simulate                       Avoid uploading the data\n";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'ftpUsername=s' => \$ftpUsername,
	   'ftpPassword=s' => \$ftpPassword,
	   'directory=s' => \$pictureDirectory,
	   'metadataFile=s' => \$metadataFile,
	   'delay=s' => \$delay,
	   'verbose' => \$verbose,
	   'simulate' => \$simulate,
	   'filter=s' => \@filters,
	   'help' => \$help,
);

if ($help) {
    usage();
    exit 0;
}

# Make a few security checks
if (!$username || !$password || !$pictureDirectory || !$metadataFile || !$ftpHost || !$ftpUsername || !$ftpPassword) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--username=<COMMONS_USERNAME>\n\t--password=<COMMONS_PASSWORD>\n\t--directory=<PICTURE_DIRECTORY>\n\t--metadata=<XML_FILE>\n\t--ftpUsername=<FTP_USERNAME>\n\t--ftpPassword=<FTP_PASSWORD>\n";
    exit;
};

unless (-d $pictureDirectory) {
    die "'$pictureDirectory' seems not to be a valid directory.";
}

unless (-f $metadataFile) {
    die "'$metadataFile' seems not to be a valid file.";
}

unless ($delay =~ /^[0-9]+$/) {
    die "The delay '$delay' seems not valid. This should be a number.";
}

# Check connections to remote services
connectToCommons();
connectToFtp(); 

# Read the metadata file
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'UNIMARC' );
MARC::File::XML->default_record_format('USMARC');
my $metadataFileHandler = MARC::File::XML->in( $metadataFile );

my $skippedCount = 0;
while (my $record = $metadataFileHandler->next()) {
    my $uid = $record->field('092') ? $record->field('092')->subfield("a") : "";
    my $title = $record->field('245') ? $record->field('245')->subfield("a") : $record->title_proper();
    my $date = $record->field('260') ? $record->field('260')->subfield("c") : ""; unless ($date) { $date = $record->field('250') ? $record->field('250')->subfield("a") : "{{Unknown}}" };
    my $author = "";
    foreach my $record ($record->field('700')) {
	my $authorLine = "";

	$authorLine .= $record->subfield("a") || "";
	if ($authorLine) {
	    $authorLine .= ", ";
	}
	$authorLine .= $record->subfield("c") || "";
	if ($authorLine) {
	    $authorLine .= ", ";
	}
	$authorLine .= $record->subfield("d") || "";

	if ($author && $authorLine) {
	    $author .= "<br/>\n";
	}
	$author .= $authorLine;
    }; 
    unless ($author) { $author = "{{Anonymous}}" };     
    my $description = $record->field('245') ? $record->field('245')->subfield("a") : "";
    my $dimensions = $record->field('300') ? $record->field('300')->subfield("c") : "";
    my $medium = $record->field('300') ? $record->field('300')->subfield("a") : "";

    # Check the filter
    if ($uid && scalar(@filters) && !(grep {$_ eq $uid} @filters)) {
	$skippedCount++;
	next;
    }

    # Make a few checks
    unless ($uid) {
	die "Unable to get the UID for a record.";
    }
    unless ($title) {
	die "Unable to get the title for the record with UID $uid.";
    }
    unless ($date) {
	die "Unable to get the creation date for the record with UID $uid.";
    }
    unless ($author) {
	die "Unable to get the author for the record with UID $uid.";
    }
    unless ($description) {
	die "Unable to get the description for the record with UID $uid.";
    }
    if (exists($metadatas{$uid})) {
	die "We have a duplicate entry for the entry with UID $uid.";
    }

    # Compute new filename
    my $modifiedTitle = $title;
    $modifiedTitle =~ s/ /_/g;
    $modifiedTitle =~ s/[^\w]//g;
    my $newFilenameBase = "Zentralbibliothek_Zürich_-_".$modifiedTitle."_-_".$uid;
    $newFilenameBase =~ s/[_]+/_/g;
    if (length($newFilenameBase) > 245) {
	die "Title/Filename is too long (>255 bytes) for entry with UID $uid.";
    }

    # Add to the metadata hash table
    $metadatas{$uid} = { 
	'title' => $title,
	'date' => $date,
	'author' => $author,
	'description' => $description,
	'dimensions' => $dimensions,
	'medium' => $medium,
	'newFilenameBase' => $newFilenameBase,
    };

    # Print metadata
    printLog("Computed Medadatas for UID $uid:");
    printLog("- Title: ".$title);
    printLog("- Date: ".$date);
    printLog("- Author: ".$author);
    printLog("- Description: ".$description);
    printLog("- Dimensions: ".$dimensions);
    printLog("- Medium: ".$medium);
    printLog("- Filename: ".$newFilenameBase.".tif");
}
printLog(scalar(keys(%metadatas))." metadata entry(ies) read and $skippedCount skipped.");

# Try to find corresponding file for each metadata
foreach my $uid (keys(%metadatas)) {
    my $filename = $uid.".tif";
    $filename =~ s/^0+//g;
    while ((! -f $pictureDirectory.$fsSeparator.$filename) && !($filename eq "00000".$uid.".tif")) {
	$filename = "0".$filename;
    }
    if ($filename eq "00000".$uid.".tif") {
	die "Unable to find on the filesystem the TIFF file corresponding to UID $uid.";
    } else {
	if (-r $pictureDirectory.$fsSeparator.$filename) {
	    $metadatas{$uid}->{'filename'} = $pictureDirectory.$fsSeparator.$filename;
	} else {
	    die "File $pictureDirectory.$fsSeparator.$filename is not readable.";
	}
    }
}

# Conversion and upload processes
my $image = Image::Magick->new();
my $error;
foreach my $uid (keys(%metadatas)) {
    my $metadata = $metadatas{$uid};
    my $filename = $metadata->{'filename'};
    my $newFilenameBase = $metadata->{'newFilenameBase'};

    # Preparing description
    my $template = HTML::Template->new(scalarref => \$templateCode);
    $template->param(DESCRIPTION=>$metadata->{'description'});
    $template->param(DATE=>$metadata->{'date'});
    $template->param(AUTHOR=>$metadata->{'author'});
    $template->param(UID=>$uid);
    $template->param(OTHER_VERSION=>$newFilenameBase.".jpg");

    # Uploading image and description to the FTP
    uploadFileToFTP($filename, $newFilenameBase.".tif");
    writeFile($jpegDescriptionFile, $template->output());
    uploadFileToFTP($jpegDescriptionFile, $newFilenameBase.".tif.desc");

    # Connect to Wikimedia Commons
    my $commons = connectToCommons();
    printLog("Successfuly connected to Wikimedia Commons.");

    # Check if already done
    my $pictureName = $newFilenameBase.".jpg";
    my $exists = $commons->exists("File:$pictureName");
    if ($exists) {
	printLog("'$pictureName' already uploaded.");
    } else {
	# Stop if error in imagemagick, except for: Incompatible type for "RichTIFFIPTC"
	printLog("Checking $filename...");
	$error = $image->Read($filename);
	if ($error && !$error =~ /Exception 350/) { 
	    die "Error by reading ".$filename.": ".$error.".";
	}

	# JPEG compression
	if (-f $jpegFile) {
	    unlink $jpegFile;
	}
	printLog("Compressing in JPEG...");
	unless ($simulate) {
	    $image->Write(filename=>$jpegFile, compression=>'JPEG', quality => "85");
	    if (-f $jpegFile) {
		printLog("TIFF file compressed in JPEG tmp file '$jpegFile'.");
	    } else {
		die ("The JPEG file was not correctly generated at '$jpegFile'.");
	    }
	}

	# Upload JPEG version to Wikimedia commons
	$template->param(OTHER_VERSION=>$newFilenameBase.".tif");
	my $content = $simulate ? "" : readFile($jpegFile);
	printLog("Uploading $pictureName to Wikimedia Commons...");

	my $status;
	if ($simulate) {
	    $status = 1;
	} else {
	    $status = $commons->uploadImage($pictureName, $content, $template->output(), "GLAM Zurich central library picture $uid (WMCH)", 0);
	}
	
	if ($status) {
	    printLog("'$pictureName' was successfuly uploaded to Wikimedia Commons.");
	} else {
	    die "'$pictureName' failed to be uploaded to Wikimedia Commons.\n";
	}
    }

    # Wait a few seconds
    if (-f $jpegFile) {
	unlink $jpegFile;
    }
    if ($delay) {
      printLog("Waiting $delay s...");
      sleep($delay);
    }
}

# Upload file to tmp FTP
sub uploadFileToFTP {
    my $filename = shift;
    my $fileBasename = basename($filename);
    my $newFilename = shift(@_) || $fileBasename;
    my $ftp = connectToFtp();

    # Check if file is already there
    my $remoteSize = $ftp->size($newFilename);
    my $localSize =  -s $filename;
    if ($remoteSize && $localSize == $remoteSize) {
	printLog("$newFilename already uploaded to ftp://".$ftpHost);
	$ftp->quit();
	return;
    }
    if ($remoteSize && $localSize != $remoteSize) {
	printLog("Deleting incomplete previously uploaded $newFilename");
	unless ($simulate) {
	    $ftp->delete($fileBasename);
	}
    }

    printLog("Uploading $filename (as $newFilename) to ftp://".$ftpHost."...");
    unless ($simulate) {
	$ftp->put($filename, $newFilename)
	    or die "Unable to upload $filename to $ftpHost:", $ftp->message;
    }
    printLog("Successful upload of $filename (as $newFilename) to ftp://".$ftpHost);

    $ftp->quit();
}

# Connect to FTP {
sub connectToFtp {
    my $ftp = Net::FTP->new($ftpHost, Debug => 0, Passive =>1)
	or die "Cannot connect to ftp://$ftpHost: $@";
    $ftp->login($ftpUsername, $ftpPassword)
	or die "Cannot login to ftp://$ftpHost: ", $ftp->message;
    $ftp->binary();
    $ftp->pasv();
    return $ftp;
}

# Read/Write functions
sub writeFile {
    my $file = shift;
    my $data = shift;
    open (FILE, ">", "$file") or die "Couldn't open file: $file";
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
	print "$message\n";
    }
}
