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
my $logger = Log::Log4perl->get_logger("applyCustomisations.pl");

# get the params
my $projectCode;
my $host = "";
my $path = "";
my $username = "";
my $password = "";
my $entries;

## Get console line arguments
GetOptions('projectCode=s' => \$projectCode,
	   'host=s' => \$host, 
	   'path=s' => \$path,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   );

if (!$projectCode || !$host) {
    print "usage: ./applyCustomisations --projectCode=fr --host=fr.mirror.kiwix.org [--path=w] [--username=foo] [--password=bar]\n";
    exit;
}

# connect to mediawiki
my $site = Mediawiki::Mediawiki->new();
$site->logger($logger);
$site->hostname($host);
$site->path($path);
if ($username) {
    $site->user($username);
    $site->password($password);
}
$site->setup();

# connect to commons
my $commons = Mediawiki::Mediawiki->new();
$commons->logger($logger);
$commons->hostname("commons.wikimedia.org.mirror.kiwix.org");
$commons->path($path);
if ($username) {
    $commons->user($username);
    $commons->password($password);
}
$commons->setup();

# Initiate www.kiwix.org
my $www = Mediawiki::Mediawiki->new();
$www->hostname("www.kiwix.org");
$www->path("");
$www->logger($logger);

# Get the list image to delete
sub getList {
    my $pageTitle = shift;

    # Get the code of the page
    my ($list) = $www->downloadPage($pageTitle);

    # Set empty string if undefined
    unless ($list) {
	$list = "";
    }
    
    # Remove the geshi xml code
    $list =~ s/^<[\/]*source[^>]*>[\n]*//mg;
    
    return $list;
}

# Expand categories in a list
sub expandCategories {
    my $list = shift;
    my $namespace = shift;
    my $entries = "";

    foreach my $entry (split(/\n/, $list)) {
	if ($entry =~ /^Category:(.*)$/i) {
	    my $category=$1;
	    
	    if ($namespace eq "14") {
		$entries = $entries.$entry."\n";
	    }

	    foreach my $categoryEntry ($site->listCategoryEntries($category, 7, $namespace)) {
		$categoryEntry =~ s/ /_/g;
		$entries = $entries.$categoryEntry."\n";
	    }

	} elsif ($entry) {
	    $entries = $entries.$entry."\n";
	}
    }

    return $entries;
}

# Remove the categories
$logger->info("Remove categories...");
$entries = getList("Mirrors/$projectCode/category_black_list.txt");
$entries = expandCategories($entries, 14);

foreach my $entry (split(/\n/, $entries)) {
    if ($site->exists($entry)) {
	$site->deletePage($entry, "");
    }
}

# Remove the images
$logger->info("Remove images...");
$entries = getList("Mirrors/$projectCode/image_black_list.txt");
foreach my $entry (split(/\n/, $entries)) {
    if ($site->exists($entry)) {
	$site->deletePage($entry);
    }
    
    if ($commons->exists($entry)) {
	$commons->deletePage($entry);
    }
}

# Remove the templates 
$logger->info("Remove templates...");
$entries = getList("Mirrors/$projectCode/template_black_list.txt");
$entries = expandCategories($entries, 10);

foreach my $entry (split(/\n/, $entries)) {
    if ($entry =~ /^(.+?) (.+)$/) {
	$entry = $1;
	my $replacement = $2;
	if ($site->exists($entry)) {
	    $site->uploadPage($entry, $replacement);
	}
    } else {
	if ($site->exists($entry)) {
	    $site->uploadPage($entry, "", "empty page");
	}
    }
}

exit;
