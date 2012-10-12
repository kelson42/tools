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
my $logger = Log::Log4perl->get_logger("removeCategoryCalls.pl");

# get the params
my $host = "";
my $path = "";
my $username = "";
my $password = "";
my $readFromStdin;
my @pages;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'username=s' => \$username,
	   'password=s' => \$password,
           'readFromStdin' => \$readFromStdin,
           'page=s' => \@pages,
	   );

if (!$host) {
    print "usage: ./removeCategoryCalls --host=my.wiki.org [--path=w] [--username=foo] [--password=bar] [--page=titi] [--readFromStdin]\n";
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
my $localCategoryNamespaceName = $site->getNamespaceName(10);

# Go through all pages
foreach my $page (@pages) {
    my ($content) = $site->downloadPage($page);
    $content =~ s/\[\[(Kategorie|$localCategoryNamespaceName):.*\]\]//gi;
    print $content."\n";
    exit;
}

exit;
