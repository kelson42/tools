#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";
binmode STDERR, ":utf8";

use utf8;
use lib '../classes/Mediawiki/';

use strict;
use warnings;
use Getopt::Long;
use List::Compare;
use Getopt::Long;
use Data::Dumper;
use Mediawiki;

my $username;
my $password;

GetOptions('username=s' => \$username, 
	   'password=s' => \$password);

if (!$username || !$password) {
    print "usage: ./wp1_fr_daily_job.pl --usernamey=foobar --password=mypass\n";
    exit;
};

# Get the connection to fr.wikipedia.org
my $site = Mediawiki->new();
$site->hostname("fr.wikipedia.org");
$site->path("w");
$site->user($username);
$site->password($password);
$site->setup();

# Get the page wich have opinion about article to select
my @pages;
foreach my $page ($site->embeddedIn("Template:WP1ps")) {
    if ($page =~ /propositions/) {
	push(@pages, $page);
	print $page."\n";    
    }
}

# search article
my %hash;
foreach my $page (@pages) {
    my @values = split("/", $page);
    my $month = $values[3] || "";
    $month =~ s/_/ /g;
    print $month."\n";

    my ($content, $revision) = $site->downloadPage($page); 

    my $regexp = "(<s>|)[ ]*({{[w|W]P1ps[ |_]opin[i]{0,1}on\\|.*}})";
    while ($content =~ /$regexp/g ) {
	next if ($1 eq "<s>");

	my $call = $2;
	if ($call =~ /opinion=attendre/i ) {
	    if ($call =~ /article=([^|}]*)/i ) {
		my $title = $1;
		$title =~ s/_/ /g;
		$hash{$title} = "[[".$page."|".($month || "30 derniers jours")."]]";
	    }
	}
    }

    unless ($month) {
	my $regexp = "({{[w|W]P1ps\\|.*}})";
	while ($content =~ /$regexp/g ) {
	    my $call = $1;
	    if ($call =~ /article=([^|}]*)/i ) {
		my $title = $1;
		$title =~ s/_/ /g;
		$hash{$title} = "[[".$page."|".($month || "30 derniers jours")."]]";
	    }
	}	
    }
}

# get the list of selected
my @selected = $site->listCategoryEntries("Wikipédia_0.5", 1, 1);

# en attente
my @to_waits = keys(%hash);

# create the comparator
my $lc = List::Compare->new( {
    lists    => [\@to_waits, \@selected],
    unsorted => 1,
} );

# make the comparison
my @unsorted_titles = $lc->get_unique;

# sort the results
my @titles = sort(@unsorted_titles);

# date
use POSIX qw(strftime);
my $date = strftime("%a. %e %b. %H:%M:%S %Y", localtime);

# generate the page
my $content = "
<!-- DÉBUT DE LA ZONE DE TRAVAIL DU BOT -->
''Articles : {{formatnum:".scalar(@titles)."}}

";

foreach my $title (@titles) {
    $content .= "* [[".$title."]] (".$hash{$title}.")\n"
} 

$content .= "\n<!-- FIN DE LA ZONE DE TRAVAIL DU BOT -->";

# edit the page
$site->uploadPage("Projet:Wikipédia_1.0/Version_0.5/en_attente", $content, "Mise à jour des pages en attente"); 

