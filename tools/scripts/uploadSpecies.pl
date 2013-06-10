#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use utf8;
use strict;
use warnings;
use Getopt::Long;
use Getopt::Long;
use Data::Dumper;
use Encode;
use Kiwix::PathExplorer;
use Mediawiki::Mediawiki;
use HTML::Template;

my $username;
my $password;
my $baseDirectory;
my @filters;
my $help;
my $delay = 0;
my $verbose;
my $fsSeparator = '/';
my $allowOverride;
my $doEverything;
my $templatePath;
my $namePrefix;

sub usage() {
    print "uploadSpecies is a script to upload pictures sorted by binomial species to Wikimedia Commons library.\n";
    print "\tuploadSpecies --username=<COMMONS_USERNAME> --password=<COMMONS_PASSWORD> --directory=<PICTURE_DIRECTORY> --templatePath=uploadHerbarium.tmpl --namePrefix=\n\n";
    print "In addition, you can specify a few additional arguments:\n";
    print "--filter=<GENIUS_OR_SPECIE>      Upload only this/these genius/species\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two uploads\n";
    print "--allowOverride                  Allow to re-upload a picture over an old one with the same name.\n";
    print "--doEverything                   Ignore *.done files and recheck against Wikimedia online.\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console\n";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'directory=s' => \$baseDirectory,
	   'templatePath=s' => \$templatePath,
	   'namePrefix=s' => \$namePrefix,
	   'delay=s' => \$delay,
	   'allowOverride' => \$allowOverride,
	   'doEverything' => \$doEverything,
	   'verbose' => \$verbose,
	   'filter=s' => \@filters,
	   'help' => \$help,
);
$allowOverride = $allowOverride ? 1 : 0;

# Encoding
utf8::decode($namePrefix);

if ($help) {
    usage();
    exit 0;
}

# Make a few security checks
if (!$username || !$password || !$baseDirectory || !$templatePath || !$namePrefix) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--username=<COMMONS_USERNAME>\n\t--password=<COMMONS_PASSWORD>\n\t--directory=<PICTURE_DIRECTORY>\n\t--templatePath=<TEMPLATE_FILE>\n\t--namePrefix=<UPLOAD_NAME_PREFIX>\n";
    exit;
};

unless (-d $baseDirectory) {
    print STDERR "'$baseDirectory' seems not to be a valid directory.\n";
    exit 1;
}

unless (-f $templatePath) {
    print STDERR "'$templatePath' seems not to be a valid template file.\n";
    exit 1;
}

unless ($delay =~ /^[0-9]+$/) {
    print STDERR "The delay '$delay' seems not valid. This should be a number.\n";
    exit 1;
}

# Connect to wikis
#my $commonsWiki = connectToMediawiki("devwiki", "w");
my $commonsWiki = connectToMediawiki("commons.wikimedia.org", "w");
my $enWiki =  connectToMediawiki("en.wikipedia.org", "w", 1);
my $deWiki =  connectToMediawiki("de.wikipedia.org", "w", 1);
my $frWiki =  connectToMediawiki("fr.wikipedia.org", "w", 1);
my $itWiki =  connectToMediawiki("it.wikipedia.org", "w", 1);

# Compute paths to go through
my @directories;
if (scalar(@filters)) {
    printLog(scalar(@filters)." filters detected.");
    foreach my $filter (@filters) {
	my $filterDirectory = $filter;
	$filterDirectory =~ s/( |_)/$fsSeparator/;
	my $wholeFilterDirectory = $baseDirectory.$fsSeparator.$filterDirectory;
	if (-d $wholeFilterDirectory) {
	    push(@directories, $wholeFilterDirectory);
	} else {
	    print STDERR "'$wholeFilterDirectory' is not a directory, please check your --filter argument(s).\n";
	    exit 1;
	}
    }
} else {
    printLog("No filter detected.");
    push(@directories, $baseDirectory);
}
printLog("Following directory(ies) will be parsed:");
foreach my $directory (@directories) {
    printLog("* $directory");
}

# Get pictures to upload
my @pictures;
my $patternRegex = "([\\w|-]+)\\$fsSeparator([\\w|-]+)\\$fsSeparator([\\w|-]*?)(\\$fsSeparator|)([\\w|-]+)\\.(tif|tiff)\$";
foreach my $directory (@directories) {
    my $explorer = new Kiwix::PathExplorer();
    $explorer->filterRegexp('\.(tif|tiff)$');
    $explorer->path($directory);
    while (my $file = $explorer->getNext()) {
	if (substr($file, length($baseDirectory)) =~ /$patternRegex/) {
	    push(@pictures, $file);
	} else {
	    print STDERR "'".substr($file, length($baseDirectory))."' does not match the GENIUS/SPECIE/ID.(tif|tiff) pattern.\n";
	    exit 1;
	}
    }
}
printLog(scalar(@pictures)." file(s) to upload *.(tif|tiff) where detected.");

# Upload pictures
my $pictureNameRegex = "^.*\\$fsSeparator";
my $templateCode = readFile($templatePath);
utf8::decode($templateCode);

foreach my $picture (@pictures) {
    substr($picture, length($baseDirectory)) =~ /$patternRegex/;
    my $genius = $1;
    my $specie = $2;
    my $subSpecie = $3;
    my $id = $5;
    my $extension = $6;
    my $pictureName;
    if ($subSpecie) {
      $pictureName = $namePrefix."_-_".$genius."_".$specie."_ssp._".$subSpecie."_-_$id.".$extension;
    } else {
      $pictureName = $namePrefix."_-_".$genius."_".$specie."_-_$id.".$extension;
    }

    # Check if already done
    printLog("Check if picture '$pictureName' already uploaded...");
    if (!$doEverything) {
      my $doneFile = $picture.".done";
      my $done;
      if (-f $doneFile) {
   	$done = 42;
      } else {
	my $exists = $commonsWiki->exists("File:$pictureName");
	if ($exists) {
	    $done = 42;
	    writeFile($doneFile, "");
	}
      }
      if ($done) {
	printLog("'$pictureName' already uploaded...");
	next;
      }
    } else {
      printLog("Do not check if '$pictureName' is already uploaded.");
    }

    # Preparing description
    printLog("Preparing description page for '$pictureName'...");
    my $template = HTML::Template->new(scalarref => \$templateCode);
    $template->param(GENIUS=>$genius);
    $template->param(GENIUS_UCFIRST=>ucfirst($genius));
    $template->param(SPECIE=>$specie);
    $template->param(IWEN=>$enWiki->exists("$genius $specie") ? "$genius $specie" : "");
    $template->param(IWDE=>$deWiki->exists("$genius $specie") ? "$genius $specie" : "");
    $template->param(IWFR=>$frWiki->exists("$genius $specie") ? "$genius $specie" : "");
    $template->param(IWIT=>$itWiki->exists("$genius $specie") ? "$genius $specie" : "");


    # Load picture
    printLog("Reading file '$pictureName'...");
    my $content = readFile($picture);

    # Upload
    printLog("Uploading '$pictureName'...");
    my $status = $commonsWiki->uploadImage($pictureName, $content, $template->output(), "Neuchâtel Herbarium picture $id", $allowOverride);

    if ($status) {
        printLog("'$pictureName' was successfuly uploaded.");
	writeFile($picture.".done", "");
    } else {
	print STDERR "'$pictureName' failed to be uploaded.\n";
	exit 1;
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
	utf8::encode($message);
	print "$message\n";
    }
}
