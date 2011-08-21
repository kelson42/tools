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
use LWP::Simple;
use Term::Query qw(query);

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("getTWLocalization.pl");

# get the params
my @languages;
my $allLanguages;
my $path;

# Get console line arguments
GetOptions('language=s' => \@languages, 
	   'path=s' => \$path,
	   'allLanguages' => \$allLanguages
	   );

if (!$path) {
    print STDERR "usage: ./getTWLocalization.pl --path=./ [--language=fr] [--allLanguages]\n";
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

# Get all languages if necessary
if (!scalar(@languages) || $allLanguages) {
    @languages = ("ar", "ca", "de", "es", "fa", "fr", "he", "it", "ml", "nl", "pl", "pt", "zh");
}

# Initialize $languageMainDtdSourceMaster
my $languageMainDtdSourceMaster = readFile($path."/kiwix/chrome/locale/en/main/main.dtd");
my $languageMainPropertiesSourceMaster = readFile($path."/kiwix/chrome/locale/en/main/main.properties");

# Get all languages
foreach my $language (@languages) {
    $logger->info("Getting locale '$language'.");

    # create directory if necessary
    unless ( -d $path."/kiwix/chrome/locale/".$language) { mkdir $path."/kiwix/chrome/locale/".$language; }
    unless ( -d $path."/kiwix/chrome/locale/".$language."/main") { mkdir $path."/kiwix/chrome/locale/".$language."/main"; }
    my $localePath = $path."/kiwix/chrome/locale/".$language."/main/";
    
    # get translation from translatewiki.net
    my $content = get("http://www.translatewiki.net/w/i.php?title=Special:Translate&task=export-to-file&group=out-kiwix&language=$language&limit=2500");

    # Update main dtd
    my $mainDtdHash = getLocaleHash($content, "ui\.|main");
    my $languageMainDtdSource = $languageMainDtdSourceMaster;
    while ($languageMainDtdSourceMaster =~ /(!ENTITY[ |\t]+)(.*?)([ |\t]+\")(.*?)(\")/g ) {
	my $prefix = $1.$2.$3;
	my $postfix = $5;
	my $name = $2;
	my $value = $4;

	if (exists($mainDtdHash->{$name})) {
	    $value = $mainDtdHash->{$name};
	}

	$languageMainDtdSource =~ s/\Q$1$2$3$4$5\E/$prefix$value$postfix/;
    }
    writeFile($localePath."main.dtd", $languageMainDtdSource);

    # Update js properties file
    my $mainPropertiesHash = getLocaleHash($content, "ui\.messages\.|");
    my $languageMainPropertiesSource = $languageMainPropertiesSourceMaster;

    while ($languageMainPropertiesSourceMaster =~ /^([^<].*?)(\=)(.*)$/mg) {
	my $name = $1;
	my $middle = $2;
	my $value = $3;
	
	if (exists($mainPropertiesHash->{$name})) {
	    $value = $mainPropertiesHash->{$name};
	}
	
	$languageMainPropertiesSource =~ s/\Q$1$2$3\E/$name$middle$value/;
    }
    writeFile($localePath."main.properties", $languageMainPropertiesSource);
}

sub getLocaleHash {
    my $content = shift;
    my ($prefixEx, $prefixInc) = split(/\|/, shift);

    my %translationHash;
    while ($content =~ /$prefixEx($prefixInc.*)=(.*)/g ) {
	$translationHash{$1} = $2;
    }

    return \%translationHash;
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
