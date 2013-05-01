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
my $logger = Log::Log4perl->get_logger("isGlobalUser.pl");

# get the params
my $host = "";
my $path = "";
my $username = "";
my $password = "";
my $readFromStdin;
my @users;

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'username=s' => \$username,
	   'password=s' => \$password,
           'readFromStdin' => \$readFromStdin,
           'user=s' => \@users,
	   );

if (!$host) {
    print "usage: ./isGlobalUser.pl --host=my.wiki.org [--path=w] [--username=foo] [--password=bar] [--user=titi] [--readFromStdin]\n";
    exit;
}

if ($readFromStdin) {
    while (my $user = <STDIN>) {
	$user =~ s/\n//;
	push(@users, $user);
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


# Go through all pages
foreach my $user (@users) {
    if ($site->isGlobalUser($user)) {
	print $user."\n";
    }
}

exit;
