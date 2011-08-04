#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;
use Term::Query qw(query);

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("getTWLocalization.pl");

# get the params
my @languages;
my $allLanguages;
my $path;
my $source;
my $rev;
my $cmd;

## Get console line arguments
GetOptions('language=s' => \@languages, 
	   'path=s' => \$path,
	   'allLanguages' => \$allLanguages
	   );

if (!$path) {
    print STDERR "usage: ./getTWLocalization.pl --path=./ [--language=en-US] [--allLanguages]\n";
    exit;
} elsif (! -d $path || ! -d $path."/kiwix/") {
    print STDERR "'$path' is not a directory, does not exist or is not the Kiwix source directory 'moulinkiwix'.\n";
    exit;
}

# Check if --allLanguages is not set if the user really want to mirror all languages
if (!scalar(@languages) && !$allLanguages) {
    $allLanguages = query("getTWLocalization.pl will download all Kiwix locales in directory '$path' from translatewiki.net. Do you want to continue? (y/n)", "N");
    
    if ($allLanguages =~ /no/i) {
	exit;
    }
}

# Initiate the Mediawiki object
my $site = Mediawiki::Mediawiki->new();
$site->hostname("www.kiwix.org");
$site->path("");
$site->logger($logger);

# Get all languages if necessary
if (!scalar(@languages) || $allLanguages) {
    my @embeddedIns = $site->embeddedIn("template:Language_translation", 0);
    foreach my $embeddedIn (@embeddedIns) {
	if ($embeddedIn =~ /Translation\/languages\/(.*)/ ) {
	    my $language = $1;
	    push(@languages, $language);
	}
    }
}

# Get all languages
foreach my $language (@languages) {

    $logger->info("Getting locale '$language'.");
    
    # create directory
    unless ( -d $path."/kiwix/chrome/locale/".$language) { mkdir $path."/kiwix/chrome/locale/".$language; }
    unless ( -d $path."/kiwix/chrome/locale/".$language."/main") { mkdir $path."/kiwix/chrome/locale/".$language."/main"; }
    my $localePath = $path."/kiwix/chrome/locale/".$language."/main/";
    my $installerPath = $path."/installer/translations/";    

    # get help.html
    ($source) = $site->downloadPage("Translation/languages/".$language."/help.html");
    if ($source) {
	$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
	writeFile($localePath."help.html", $source);
    }
    
    # get main.dtd
    ($source) = $site->downloadPage("Translation/languages/".$language."/main.dtd");
    if ($source) {
	$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
	writeFile($localePath."main.dtd", $source);
    }
    
    # get main.properties
    ($source) = $site->downloadPage("Translation/languages/".$language."/main.properties");
    if ($source) {
	$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
	writeFile($localePath."main.properties", $source);
    }
    
    # get installer
    ($source) = $site->downloadPage("Translation/languages/".$language."/installer");
    if ($source) {
	$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
	my $filename;
	my $codepage;

	if ($source =~ /\!define LANG_FILENAME "([^\"]*)"/) {
	    $filename = $1;
	}

	if ($source =~ /\!define LANG_CODEPAGE "([^\"]*)"/) {
	    $codepage = $1;
	}

	if ($filename && $codepage) {
	    $source =~ s/^.*(LANG_CODEPAGE|LANG_FILENAME).*$//mg;
	    $filename = $installerPath.$filename;
	    my $tmpFilename = $filename.".utf8";

	    writeFile($tmpFilename, $source);
	    $cmd = "iconv -f UTF-8 -t $codepage $tmpFilename > $filename"; `$cmd`;
	    $cmd = "rm $tmpFilename"; `$cmd`;
	}
    }

    # get the autorun
    ($source) = $site->downloadPage("Translation/languages/".$language."/dvd_launcher.xml");
    if ($source) {
	$source =~ s/^<[\/]*source[^>]*>[\n]*//mg;
	my $filename = $language.".xml";
	$filename =~ s/-[^\.]+//;

	if ($filename) {
	    writeFile($path."/autorun/ui/".$filename, $source);
	}
    }
}

sub writeFile {
    my $file = shift;
	my $data = shift;
    
    open (FILE, ">:utf8", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $path = shift;
    my $data = "";

    open FILE, "<:utf8", $path or die "Couldn't open file: $path";
    while (<FILE>) {
        $data .= $_;
    }
    close FILE;

    return $data;
}

exit;
