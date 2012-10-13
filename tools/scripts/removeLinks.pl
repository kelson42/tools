#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use lib "../";
use lib "../classes/";

use Config;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("removeLinks.pl");

# get the params
my $host = "";
my $path = "";
my $username = "";
my $password = "";
my $readFromStdin;
my $action;
my $type;
my @pages;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'username=s' => \$username,
	   'password=s' => \$password,
           'readFromStdin' => \$readFromStdin,
           'page=s' => \@pages,
	   'type=s' => \$type,
	   'action=s' => \$action,
	   );

if (!$host || !$action || !$type) {
    print "usage: ./removeLinks.pl --host=my.wiki.org --type=(category|interwiki|wiki) --action=(linkonly|everything) [--path=w] [--username=foo] [--password=bar] [--page=titi] [--readFromStdin]\n";
    exit;
}

if ($readFromStdin) {
    while (my $page = <STDIN>) {
	$page =~ s/\n//;
	push(@pages, $page);
    }
}

my $site = Mediawiki::Mediawiki->new();
$site->hostname($host);
$site->path($path);
$site->logger($logger);
if ($username) {
    $site->user($username);
    $site->password($password);
}
$site->setup();

# Get localized "Category" namespace name
my $localCategoryNamespaceName;
if ($type eq "category") {
    $localCategoryNamespaceName = $site->getNamespaceName(14);
}

# Go through all pages
foreach my $page (@pages) {
    my ($content) = $site->downloadPage($page);

    if ($type eq "category") {
	if ($action eq "everything") {
	    $content =~ s/\[\[(Kategorie|$localCategoryNamespaceName):.*\]\]//gi;
	}
    } elsif ($type eq "interwiki") {
	if ($action eq "everything") {
	    $content =~ s/\[\[([a-z]{2,3}|simple|be-x-old|zh-yue):.*\]\]//gi;
	}
    } elsif ($type eq "wiki") {
	if ($action eq "linkonly") {
	    my $oldContent = $content;
	    while ($oldContent =~ /\[\[([^\:]*?)\]\]/gm ) {
		my $match = $1;
		my $replacement = $match;

		if ($match =~ /(.*)\|(.*)/) {
		    my $target = $1;
		    my $label = $2;

		    # Check links in templates with dynamic values
		    unless ($target =~ /{{{([a-zA-Z0-9])/ ) {
			$replacement = $label;
		    }
		}
		$content =~ s/\[\[\Q$match\E\]\]/$replacement/g;
	    }
	}
    }

    # Remove trailing spaces
    $content =~ s/[ |\t|\n]+$//g;

    # Save
    $site->uploadPage($page, $content, "remove links");
}

exit;
