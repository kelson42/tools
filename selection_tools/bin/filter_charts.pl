#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";
binmode STDERR, ":utf8";

use utf8;
use lib '../mirroring_tools/Mediawiki/';
use lib "../dumping_tools/classes/";

use strict;
use warnings;
use Encode;
use PerlIO::gzip;
use URI::Escape;
use Data::Dumper;
use Getopt::Long;
use Kiwix::PathExplorer;
use MediaWiki;

my $chartsDirectory;
my $language;

GetOptions('chartsDirectory=s' => \$chartsDirectory, 
	   'language=s' => \$language);

if (!$language || !$chartsDirectory) {
    print "usage: ./filter_charts.pl --chartsDirectory=./tmp/charts --language=fr\n";
    exit;
};

# get the namespace in english
my $enSite = MediaWiki->new();
$enSite->hostname("en.wikipedia.org");
$enSite->path("w");
my %enNamespaces = $enSite->namespaces();

# get the namespace in the language
my $langSite = MediaWiki->new();
$langSite->hostname("$language.wikipedia.org");
$langSite->path("w");
my %langNamespaces = $langSite->namespaces();

# Build exclusion regex
my $regex = "^(";
foreach my $code (keys(%langNamespaces)) {
    next unless ($code);
    $regex .= "(".$langNamespaces{$code}.":)|";
}
foreach my $code (keys(%enNamespaces)) {
    next unless ($code);
    $regex .= "(".$enNamespaces{$code}.":)|";
}
$regex .= "(Http:)|(WP:)|(Image:)|(Imagen:)|([0-9]+px)|([0-9A-Za-z]+\.png))";

# get charts file path
my @files;
my $explorer = new Kiwix::PathExplorer();
$explorer->path($chartsDirectory);
$explorer->filterRegexp("^.*\.(gz)\$");
while (my $file = $explorer->getNext()) {
    push(@files, $file);
}

# hash to count file
my %urls;

# parse each file
foreach my $file ( @files ) { 
    
    # open file
    open IN, "<:gzip", $file or die;

    # print info
    print STDERR $file .":";
 
    # parse each line of the file
    my $i=0;
    while ( my $line = <IN> ) {

	# Display progressbar
	if ( $i++ % 100000 == 0) { print STDERR "."; }

	# Keep only entries for your language
	next unless ( $line =~ /^$language /);

	# get infos from the line (ex: "fr Brothers_in_Arms_(jeu) 1 14817")
	my $name;
	my $count;
	if ($line =~ /^[\w|\.]+ ([^ ]+) ([\d]+) [\d]+/) {
	    $name = ucfirst($1);
	    $count = $2;
	} else {
	    next;
	}

	# URL decoding
	$name =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	
	# Return if the title is too long
	next if (length($name) > 255);

	# Beautify the page name
	$name =~ s/ /_/g;
	$name =~ s/^[_]+//g;
	$name =~ s/#.*//;
	
	# Apply the filter to remove images, etc.
	next if ($name =~ /^$regex/);

	# Make the incrementation
	$urls{$name} += $count;
    }

    # Close file
    print STDERR scalar(keys(%urls))." urls observed...\n";
    close IN;
}

# Sort desc all urls and print them
foreach my $url (sort { $urls{$b} <=> $urls{$a} } keys(%urls)) {
    print $url." ".$urls{$url}."\n";
}


