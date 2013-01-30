#!/usr/bin/perl
#binmode STDOUT, ":utf8";
#binmode STDIN, ":utf8";

use utf8;
use lib "../classes/";

use strict;
use warnings;
use Encode;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("modifyMediawikiEntry.pl");

# parameters
my $host = "";
my $path = "";
my $username = "";
my $password = "";
my @entries;
my $readFromStdin = 0;
my $file = "";
my $action = "touch";
my @variables;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'file=s' => \$file,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   'action=s' => \$action,
	   'variable=s@' => \@variables,
           'readFromStdin' => \$readFromStdin,
           'entry=s' => \@entries,
    );

if (!$host || (!$readFromStdin && !$file && !scalar(@entries)) || !($action =~ /^(touch|delete|empty|restore|rollback|replace|stub|append)$/)) {
    print "usage: ./modifyMediawikiEntry.pl --host=my.wiki.org [--file=my_file] [--path=w] [--entry=my_page] [--readFromStdin] [--action=touch|delete|empty|restore|rollback|replace|stub|append] [--variable={{footnote}}] [--username=foobar] [--password=mypass]\n";
    exit;
}

$logger->info("=======================================================");
$logger->info("= Start modifying entries =============================");
$logger->info("=======================================================");

# readFromStdin
if ($readFromStdin) {
    $logger->info("Read entries from stdin.");
    while (my $entry = <STDIN>) {
	$entry =~ s/\n//;
#	$entry = decode_utf8($entry);
	push(@entries, $entry);
    }
}

# readfile
if ($file) {
    if (-f $file) {
	open SOURCE_FILE, "<$file" or die $!;
	while (<SOURCE_FILE>) {
	    my $entry = $_;
	    $entry =~ s/\n//;
	    push(@entries, $entry);
	}
    } else {
	$logger->info("File '$file' does not exist.");
    }
}

# connect to mediawiki
my $site = Mediawiki::Mediawiki->new();
$site->logger($logger);
$site->hostname($host);
$site->path($path);
$site->user($username);
$site->password($password);
$site->setup();

# do action for each entry
foreach my $entry (@entries) {
    my $status;
    if ($action eq "touch") {
	$status = $site->touchPage($entry);
    } elsif ($action eq "delete") {
	$status = $site->deletePage($entry);
    } elsif ($action eq "empty") {
	$status = $site->uploadPage($entry, "");
    } elsif ($action eq "restore") {
	$status = $site->restorePage($entry, "");
    } elsif ($action eq "rollback") {
	$status = $site->rollbackPage($entry, "");
    } elsif ($action eq "replace") {
	my $regex = $variables[0];
	my $replacement = $variables[1];
	unless ($regex && $replacement) {
	    print STDERR "You have to define two varaibles as regex and replacement.\n";
	}
	my ($content, $revision) = $site->downloadPage($entry);
	$content =~ s/$regex/$replacement/mg;
	$status = $site->uploadPage($entry, $content);      
    } elsif ($action eq "stub") {
	$status = $site->uploadPage($entry, "-");
    } elsif ($action eq "append") {
	my ($content, $revision) = $site->downloadPage($entry);
	$status = $site->uploadPage($entry, $content.$variables[0]);
    } else {
	$logger->info("This action is not valid, will exit.");
	last;
    }

    if ($status) {
	$logger->info("The '$action' action was successfuly performed on '$entry'.");
    } else {
	$logger->info("The '$action' action failed to be performed on '$entry'.");
    }
}

$logger->info("=======================================================");
$logger->info("= Stop modifying entries =============================");
$logger->info("=======================================================");

exit;
