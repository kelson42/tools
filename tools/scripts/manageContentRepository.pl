#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/../classes/";
use lib "$FindBin::Bin/../../dumping_tools/classes/";

use utf8;
use strict;
use warnings;
use Kiwix::PathExplorer;
use Getopt::Long;
use Data::Dumper;
use File::stat;
use Time::localtime;
use Number::Bytes::Human qw(format_bytes);
use Mediawiki::Mediawiki;

my %content;

# Configuration variables
my $contentDirectory = "/var/www/download.kiwix.org";
my $zimDirectoryName = "zim";
my $zimDirectory = $contentDirectory."/".$zimDirectoryName;
my $portableDirectoryName = "portable";
my $portableDirectory = $contentDirectory."/".$portableDirectoryName;
my $binDirectoryName = "bin";
my $srcDirectoryName = "src";
my $htaccessPath = $contentDirectory."/.htaccess";
my $libraryDirectoryName = "library";
my $libraryDirectory = $contentDirectory."/".$libraryDirectoryName;
my $libraryName = "library.xml";
my $tmpDirectory = "/tmp";
my $maxOutdatedVersions = 1;
 
# Task
my $writeHtaccess = 0;
my $writeWiki = 0;
my $writeLibrary = 0;
my $showHelp = 0;
my $wikiPassword = "";
my $deleteOutdatedFiles = 0;

sub usage() {
    print "manageContentRepository\n";
    print "\t--help\n";
    print "\t--writeHtaccess\n";
    print "\t--writeLibrary\n";
    print "\t--deleteOutdatedFiles\n";
    print "\t--htaccessPath=/var/www/download.kiwix.org/.htaccess\n";
    print "\t--writeWiki\n";
    print "\t--wikiPassword=foobar\n";
}

# Parse command line
if (scalar(@ARGV) == 0) {
    $writeHtaccess = 1;
    $writeWiki = 1;
    $writeLibrary = 1;
}

GetOptions(
    'writeHtaccess' => \$writeHtaccess,
    'writeWiki' => \$writeWiki,
    'writeLibrary' => \$writeLibrary,
    'deleteOutdatedFiles' => \$deleteOutdatedFiles,
    'help' => \$showHelp,
    'wikiPassword=s' => \$wikiPassword,
    'htaccessPath=s' => \$htaccessPath,
);

if ($showHelp) {
    usage();
    exit 0;
}

# Parse the "zim" directories
my $explorer = new Kiwix::PathExplorer();
$explorer->path($zimDirectory);
while (my $file = $explorer->getNext()) {
    if ($file =~ /^.*\/([^\/]+)\.zim$/i) {
	my $basename = $1;
	my $core = $basename;
	my $month;
	my $year;
	my $lang;
	my $project;
	my $option;

	# Old/new date format
	if ($basename =~ /^(.+?_)([a-z\-]{2,10}?_|)(.+_|)([\d]{2}|)_([\d]{4})$/i) {
	    $project = substr($1, 0, length($1)-1);
	    $option = $3 ? substr($3, 0, length($3)-1) : "";
	    $core = substr($1.$2.$3, 0, length($1.$2.$3)-1);
	    $lang = $2 ? substr($2, 0, length($2)-1) : "en";
	    $month = $4;
	    $year = $5;
	} elsif ($basename =~ /^(.+?_)([a-z\-]{2,10}?_|)(.+_|)([\d]{4}|)\-([\d]{2})$/i) {
	    $project = substr($1, 0, length($1)-1);
	    $option = $3 ? substr($3, 0, length($3)-1) : "";
	    $core = substr($1.$2.$3, 0, length($1.$2.$3)-1);
	    $lang = $2 ? substr($2, 0, length($2)-1) : "en";
	    $year = $4;
	    $month = $5;
	}

	$content{$basename} = {
	    size => format_bytes(-s "$file"),
	    lang => $lang,
	    option => $option,
	    project => $project,
	    zim => $file,
	    basename => $basename,
	    core => $core,
	    month => $month,
	    year => $year,
	};
    }
}

# Parse the "portable" directories
$explorer->reset();
$explorer->path($portableDirectory);
while (my $file = $explorer->getNext()) {
    if ($file =~ /^.*?\+([^\/]+)\.zip$/i) {
	my $basename = $1;
	if  (exists($content{$basename})) {
	    if ((exists($content{$basename}->{portable}) && 
		 getFileCreationDate($file) > getFileCreationDate($content{$basename}->{portable})) ||
		!exists($content{$basename}->{portable})
		) {
		$content{$basename}->{portable} = $file;
	    }
	} else {
	    print STDERR "Unable to find corresponding ZIM file to $file\n";
	}
    }
}

# Sort content
my %recentContent;
my %deprecatedContent;
my %stagingContent;
my %intemporalContent;
foreach my $key (keys(%content)) {
    my $entry = $content{$key};
    my $year = $entry->{year};
    my $core = $entry->{core};

    if ($year) {
	if (!exists($entry->{portable})) {
	    $stagingContent{$core} = $entry;
	} elsif (exists($recentContent{$core})) {
	    my $otherEntry = $recentContent{$core};
	    if ($year == $otherEntry->{year}) {
		my $month = $entry->{month};
		if ($month > $otherEntry->{month} && $entry->{portable}) {
		    $deprecatedContent{$core} = $otherEntry;
		    $recentContent{$core} = $entry;
		} else {
		    $deprecatedContent{$core} = $entry;
		}
	    } else {
		if ($year < $otherEntry->{year}) {
		    $deprecatedContent{$core} = $entry;
		} else {
		    if ($entry->{portable}) {
			$deprecatedContent{$core} = $otherEntry;
			$recentContent{$core} = $entry;
		    } else {
			$deprecatedContent{$core} = $entry;
		    }
		}
	    }
	} else {
	    $recentContent{$core} = $entry;
	}
    } else {
	$intemporalContent{$core} = $entry;
    }
}

# Apply to the multiple outputs
if ($deleteOutdatedFiles) {
    deleteOutdatedFiles();
}

if ($writeHtaccess) {
    writeHtaccess();
}

if ($writeWiki) {
    if (!$wikiPassword) {
	print STDERR "If you want to update the library on www.kiwix.org, you need to put a wiki password.\n";
	exit 1;
    }
    writeWiki();
}

if ($writeLibrary) {
    writeLibrary();
}

# Remove old files
sub deleteOutdatedFiles {
    my @sortedContent = sort { $content{$b}->{core}."_".$content{$b}->{year}."_".$content{$b}->{month} cmp $content{$a}->{core}."_".$content{$a}->{year}."_".$content{$a}->{month} } keys(%content);
    my $core = '';
    my $coreCounter = 0;
    foreach my $key (@sortedContent) {
	my $entry = $content{$key};
	if ($entry->{core} eq $core) {
	    if ($coreCounter > $maxOutdatedVersions) {
		print "Deleting ".$entry->{zim}."...\n";
		my $cmd = "mv ".$entry->{zim}." /var/www/backup/"; `$cmd`;
		if ($entry->{portable}) {
		    my $cmd = "mv ".$entry->{portable}." /var/www/backup/"; `$cmd`;
		}
	    } else {
		$coreCounter += 1;
	    }
	} else {
	    $core = $entry->{core};
	    $coreCounter = 1;
	}
    }
}

# Update www.kiwix.org page listing all the content available
sub beautifyZimOptions {
    my $result = "";
    my @options = split("_", shift || "");
    my $optionsLength = scalar(@options);
    for (my$i=0; $i<$optionsLength; $i++) {
	my $option = $options[$i];
	$result .= $option.($i+1<$optionsLength ? " " : "");
    }
    return $result;
}

sub writeWiki {
    my @lines;
    foreach my $key (sortKeys(keys(%recentContent))) {
	my $entry = $recentContent{$key};
	my $line = "{{ZIMdumps/row|{{{2|}}}|{{{3|}}}|".
	    $entry->{project}."|".
	    $entry->{lang}."|".$entry->{size}."|".
	    $entry->{year}."-".$entry->{month}."|".(beautifyZimOptions($entry->{option} || "all"))."|8={{DownloadLink|".
	    $entry->{core}."|{{{1}}}|".$zimDirectoryName."/|".($entry->{portable} ? $portableDirectoryName : "")."/}} }}\n";
	push(@lines, $line);
    }

    my $content = "<!-- THIS PAGE IS AUTOMATICALLY, PLEASE DON'T MODIFY IT MANUALLY -->";
    foreach my $line (@lines) {
	$content .= $line;
    }

    # Get the connection to kiwix.org
    my $site = Mediawiki::Mediawiki->new();
    $site->hostname("www.kiwix.org");
    $site->path("w");
    $site->user("LibraryBot");
    $site->password($wikiPassword);
    $site->setup();
    $site->uploadPage("Template:ZIMdumps/content", $content, "Automatic update of the ZIM library");
    $site->logout();
}

# Write http://dwonload.kiwix.org .htaccess for better html page
# descriptions of permalinks (pointing always to the last up2date
# content)
sub writeHtaccess {
    my $content = "#\n";
    $content .= "# Please do not edit this file manually\n";
    $content .= "#\n\n";
    $content .= "RewriteEngine On\n\n";
    
    # Bin redirects
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix.apk /".$binDirectoryName."/android/kiwix-1.95.apk\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-installer.exe /".$binDirectoryName."/0.9/kiwix-0.9-installer.exe\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-linux-i686.tar.bz2 /".$binDirectoryName."/0.9/kiwix-0.9-linux-i686.tar.bz2\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-linux-x86_64.tar.bz2 /".$binDirectoryName."/0.9/kiwix-0.9-linux-x86_64.tar.bz2\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-win.zip /".$binDirectoryName."/0.9/kiwix-0.9-win.zip\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix.dmg /".$binDirectoryName."/0.9/kiwix-0.9.dmg\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix.xo /".$binDirectoryName."/0.9/kiwix-0.9.xo\n";
    $content .= "RedirectPermanent /".$binDirectoryName."/kiwix-server-arm.tar.bz2 /".$binDirectoryName."/0.9/kiwix-server-0.9-linux-armv5tejl.tar.bz2\n";
    $content .= "RedirectPermanent /".$srcDirectoryName."/kiwix-src.tar.xz /".$srcDirectoryName."/kiwix-0.9-src.tar.xz\n";

    # Backward compatibility redirects
    $content .= "RedirectPermanent /zim/0.9/wikipedia_en_ray_charles_03_2013.zim /zim/wikipedia/wikipedia_en_ray_charles_2015-06.zim\n";
    $content .= "RedirectPermanent /zim/wikipedia/wikipedia_en_ray_charles_03_2013.zim /zim/wikipedia/wikipedia_en_ray_charles_2015-06.zim\n";
    $content .= "RedirectPermanent /zim/0.9/ /zim/wikipedia/\n";
    $content .= "\n\n";

    # Folder description
    $content .= "AddDescription \"Deprectated stuff kept only for historical purpose\" archive\n";
    $content .= "AddDescription \"All versions of Kiwix, the software (no content is in there)\" bin\n";
    $content .= "AddDescription \"Development stuff (tools & dependencies), for developers\" dev\n";
    $content .= "AddDescription \"Binaries and source code tarballs compiled auto. one time a day, for developers\" nightly\n";
    $content .= "AddDescription \"Random stuff, mostly mirrored for third part projects\" other\n";
    $content .= "AddDescription \"Portable packages (Kiwix+content), mostly for end-users\" portable\n";
    $content .= "AddDescription \"XML files describing all the content available, for developers\" library\n";
    $content .= "AddDescription \"Kiwix source code tarballs, for developers only\" src\n";
    $content .= "AddDescription \"ZIM files, content dumps for offline usage (to be read with Kiwix)\" zim\n";

    # Content redirects
    foreach my $key (keys(%recentContent)) {
	my $entry = $recentContent{$key};
	$content .= "RedirectPermanent /".$zimDirectoryName."/".$entry->{core}.".zim ".substr($entry->{zim}, length($contentDirectory))."\n";
	$content .= "RedirectPermanent /".$zimDirectoryName."/".$entry->{core}.".zim.torrent ".substr($entry->{zim}, length($contentDirectory)).".torrent\n";
	$content .= "RedirectPermanent /".$zimDirectoryName."/".$entry->{core}.".zim.md5 ".substr($entry->{zim}, length($contentDirectory)).".md5\n";
	if ($entry->{portable}) {
	    $content .= "RedirectPermanent /".$portableDirectoryName."/".$entry->{core}.".zip ".substr($entry->{portable}, length($contentDirectory))."\n";
	    $content .= "RedirectPermanent /".$portableDirectoryName."/".$entry->{core}.".zip.torrent ".substr($entry->{portable}, length($contentDirectory)).".torrent\n";
	    $content .= "RedirectPermanent /".$portableDirectoryName."/".$entry->{core}.".zip.md5 ".substr($entry->{portable}, length($contentDirectory)).".md5\n";
	}
	$content .= "\n";
    }
    writeFile($htaccessPath, $content);

    # Write a few .htaccess files in sub-directories
    $content = "AddDescription \" \" *\n";
    foreach my $subDirectory ("archive", "bin", "dev", "nightly", "other", "portable", "src", "zim", "library") {
	my $htaccessPath = $contentDirectory."/".$subDirectory."/.htaccess";
	writeFile($htaccessPath, $content);
    }
}

# Sort the key in user friendly way
sub sortKeysMethod {
    my %coefs = (
	"wikipedia"  => 10,
	"wiktionary" => 9,
	"wikivoyage" => 8,
	"wikiversity" => 7,
	"wikibooks" => 6,
	"wikisource" => 5,
	"wikiquote" => 4,
	"wikinews" => 3,
	"wikispecies" => 2,
	"ted" => 1
    );
    my $ac = $coefs{shift([split("_", $a)])} || 0;
    my $bc = $coefs{shift([split("_", $b)])} || 0;

    if ($ac < $bc) {
	return 1;
    } elsif ($ac > $bc) {
	return -1;
    }

    # else
    return $a cmp $b;
}

sub sortKeys {
    return sort sortKeysMethod @_;
}

# Write the library.xml file which is used as content catalog by Kiwix
# software internal library
sub writeLibrary {
    my $kiwixManagePath;

    # Get kiwix-manage full path
    if ($writeLibrary) {
	$kiwixManagePath = `which kiwix-manage`;
	$kiwixManagePath =~ s/\n//g;
	if ($? != 0 || !$kiwixManagePath) {
	    print STDERR "Unable to find kiwix-manage. You need it to write the library.\n";
	    exit 1;
	}
    }

    # Generate random tmp library name
    my @chars = ("A".."Z", "a".."z");
    my $randomString;
    $randomString .= $chars[rand @chars] for 1..8;
    my $tmpLibraryPath = $tmpDirectory."/".$libraryName.".".$randomString;
    my $libraryPath = $libraryDirectory."/".$libraryName;

    # Create the library.xml file for the most recent files
    foreach my $key (sortKeys(keys(%recentContent))) {
	my $entry = $recentContent{$key};
	my $zimPath = $entry->{zim};
	my $permalink = "http://download.kiwix.org".substr($entry->{zim}, length($contentDirectory)).".meta4";
	my $cmd = "$kiwixManagePath $tmpDirectory/$libraryName.$randomString add $zimPath --zimPathToSave=\"\" --url=$permalink"; `$cmd`;
    }

    # Move the library.xml file to its final destination
    my $cmd = "mv $tmpLibraryPath $libraryPath"; `$cmd`;
}

# fs functions
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

sub getFileCreationDate {
    return stat(shift)->ctime;
}

exit 0;

