#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";
binmode STDERR, ":utf8";

use utf8;
use lib '../classes/';

use strict;
use warnings;
use Getopt::Long;
use List::Compare;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;

my @pages;
my @results;
my $site;

sub printCSV() {
    foreach my $entry (@results) {
	print $entry->{"wp"}."\t";
	print $entry->{"kgs"}."\t";
	print(($entry->{"picture"} ? $entry->{"picture"} : "")."\t");
	print "\n";
	}
    }
}

# Get the connection to it.wikipedia.org
$site = Mediawiki::Mediawiki->new();
$site->hostname("it.wikipedia.org");
$site->path("w");
$site->setup();

# Get the page wich have opinion about article to select
@pages = ();
foreach my $page ($site->embeddedIn("Template:SIoCPoNaRS_row", "0")) {
    push(@pages, $page);
}

# Retrieve information
# {{SIoCPoNaRS row|image=|name=|address=|CH1903_X=|CH1903_Y=|KGS_nr=}}
@results = ();
foreach my $page (@pages) {
    print STDERR "Parsing $page\n";
    my ($content, $revision) = $site->downloadPage($page); 
    my $regexp = "({{[S|s]IoCPoNaRS[ |_]row\\|.*}})";
    while ($content =~ /$regexp/g ) {
	my $call = $1;
	if ($call =~ /[k|K]GS_nr[ ]*=[ ]*([\d]+)/) {
	    my $kgs = $1;
	    my %entry;
	    $entry{"wp"} = "en";
	    $entry{"kgs"} = $kgs;

	    # Picture
	    if ($call =~ /[I|i]mage[ ]*=[ ]*([^\|}]+)[ ]*/) {
		$entry{"picture"} = $1;
	    }

	    $entry{"page"} = $page;
	    push(@results, \%entry);
	}
    }
}

printCSV();

# Get the connection to en.wikipedia.org
$site = Mediawiki::Mediawiki->new();
$site->hostname("en.wikipedia.org");
$site->path("w");
$site->setup();

# Get the page wich have opinion about article to select
@pages = ();
foreach my $page ($site->embeddedIn("Template:SIoCPoNaRS_row", "0")) {
    push(@pages, $page);
}

# Retrieve information
# {{SIoCPoNaRS row|image=|name=|address=|CH1903_X=|CH1903_Y=|KGS_nr=}}
@results = ();
foreach my $page (@pages) {
    print STDERR "Parsing $page\n";
    my ($content, $revision) = $site->downloadPage($page); 
    my $regexp = "({{[S|s]IoCPoNaRS[ |_]row\\|.*}})";
    while ($content =~ /$regexp/g ) {
	my $call = $1;
	if ($call =~ /[k|K]GS_nr[ ]*=[ ]*([\d]+)/) {
	    my $kgs = $1;
	    my %entry;
	    $entry{"wp"} = "en";
	    $entry{"kgs"} = $kgs;

	    # Picture
	    if ($call =~ /[I|i]mage[ ]*=[ ]*([^\|}]+)[ ]*/) {
		$entry{"picture"} = $1;
	    }

	    $entry{"page"} = $page;
	    push(@results, \%entry);
	}
    }
}

printCSV();

# Get the connection to de.wikipedia.org
$site = Mediawiki::Mediawiki->new();
$site->hostname("de.wikipedia.org");
$site->path("w");
$site->setup();

# Get the page wich have opinion about article to select
@pages = ();
foreach my $page ($site->embeddedIn("Template:Kulturgüter_Schweiz_Tabellenzeile", "0")) {
    push(@pages, $page);
}

# Retrieve information
# {{Kulturgüter Schweiz Tabellenzeile|Foto = Engollon Eglise d'Engollon 20110907 1965.jpg|Name = Kirche Engollon|Typ = E|Adresse = Village|Breitengrad = 47.038077|Längengrad = 6.921444|Region-ISO = CH-NE|KGS-Nr =4014}}
@results = ();
foreach my $page (@pages) {
    print STDERR "Parsing $page\n";
    my ($content, $revision) = $site->downloadPage($page); 
    my $regexp = "({{[K|k]ulturgüter[ |_]Schweiz[ |_]Tabellenzeile\\|.*}})";
    while ($content =~ /$regexp/g ) {
	my $call = $1;
	if ($call =~ /[k|K]GS-Nr[ ]*=[ ]*([\d]+)/) {
	    my $kgs = $1;
	    my %entry;
	    $entry{"wp"} = "de";
	    $entry{"kgs"} = $kgs;

	    # Picture
	    if ($call =~ /[F|f]oto[ ]*=[ ]*([^\|}]+)[ ]*/) {
		$entry{"picture"} = $1;
	    }

	    $entry{"page"} = $page;
	    push(@results, \%entry);
	}
    }
}

printCSV();

# Get the connection to fr.wikipedia.org
$site = Mediawiki::Mediawiki->new();
$site->hostname("fr.wikipedia.org");
$site->path("w");
$site->setup();

# Get the page wich have opinion about article to select
@pages = ();
foreach my $page ($site->embeddedIn("Template:Ligne_de_tableau_CH", "0")) {
    push(@pages, $page);
}

# Retrieve information
# {{Ligne de tableau CH|Photo = |Objet = Grimentz : Ilôt Bosquet / Chlasche, Pierre à cupules |A = A |Arch = |B = |E = |M = |O = |S = |Adresse = |Commune = [[Anniviers]] |latitude = 46.170644|longitude = 7.569413|region-iso = CH-VS|kgs-nr = }}
@results = ();
foreach my $page (@pages) {
    print STDERR "Parsing $page\n";
    my ($content, $revision) = $site->downloadPage($page); 
    my $regexp = "({{[l|L]igne[ |_]de[ |_]tableau[ |_]CH\\|.*}})";
    while ($content =~ /$regexp/g ) {
	my $call = $1;
	if ($call =~ /[k|K]gs-nr[ ]*=[ ]*([\d]+)/) {
	    my $kgs = $1;
	    my %entry;
	    $entry{"wp"} = "fr";
	    $entry{"kgs"} = $kgs;

	    # Picture
	    if ($call =~ /[P|p]hoto[ ]*=[ ]*([^\|}]+)[ ]*/) {
		$entry{"picture"} = $1;
	    }

	    $entry{"page"} = $page;
	    push(@results, \%entry);
	}
    }
}

# Retrieve information for wpit
foreach my $page (@pages) {
    print STDERR "Parsing $page\n";
    my ($content, $revision) = $site->downloadPage($page); 
    my $regexp = "({{[l|L]igne[ |_]de[ |_]tableau[ |_]CH\\|.*}})";
    while ($content =~ /$regexp/g ) {
	my $call = $1;
	if ($call =~ /[k|K]gs-nr[ ]*=[ ]*([\d]+)/) {
	    my $kgs = $1;
	    my %entry;
	    $entry{"wp"} = "fr";
	    $entry{"kgs"} = $kgs;

	    # Picture
	    if ($call =~ /[P|p]hoto[ ]*=[ ]*([^\|}]+)[ ]*/) {
		$entry{"picture"} = $1;
	    }

	    $entry{"page"} = $page;
	    push(@results, \%entry);
	}
    }
}

printCSV();
