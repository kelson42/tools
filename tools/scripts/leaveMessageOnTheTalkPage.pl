#!/usr/bin/perl
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
my $logger = Log::Log4perl->get_logger("leavMessageOnTheTalkPage.pl");

# parameters
my $host = "";
my $path = "";
my $username = "";
my $password = "";
my @users;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'username=s' => \$username,
	   'password=s' => \$password,
    );

if (!$host) {
    print "usage: ./leaveMessageOnTheTalkPage.pl --host=my.wiki.org [--path=w] [--username=foobar] [--password=mypass]\n";
    exit;
}

$logger->info("=======================================================");
$logger->info("= Start modifying entries =============================");
$logger->info("=======================================================");

# readFromStdin
$logger->info("Read entries from stdin.");
while (my $entry = <STDIN>) {
    $entry =~ s/\n//;
    my ($name) = split( /\t/, $entry);
    push(@users, $name);
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
my $subject = "Wiki migration notice";
my $message = "The hosting for this site will be migrated from the Foundation's datacenter to the Wikimedia UK's over the last week-end of September (28-29th September). It will not be possible to migrate non-public account information. This includes watch lists, account preferences, contact email, or current password for registered users. We will recreate 'stub-accounts' on the migrated site and will communicate to you your new password if you [https://uk.wikimedia.org/wiki/Special:Preferences activate \"Enable email from other users\" in your user profile] now! [[WMUK wiki migration|Want to know more]]? ~~~~";
my $comment = "Wiki's will be migrated...";

foreach my $user (@users) {
    my $entry = "User_talk:$user";
    my ($content, $revision) = $site->downloadPage($entry);
    my $status; 

    unless ($content && $content =~ /$subject/) {
	do {
	    print STDERR "Add message to $entry...";
	    $content .= "\n== $subject ==\n\n$message\n";
	    $status = $site->uploadPage($entry, $content, $comment);
	} while (!$status);
    }
}

$logger->info("=======================================================");
$logger->info("= Stop modifying entries =============================");
$logger->info("=======================================================");

exit;
