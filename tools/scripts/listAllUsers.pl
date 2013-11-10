#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";

use utf8;
use lib "../classes/";

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;

# log
use Log::Log4perl;
Log::Log4perl->init("../conf/log4perl");
my $logger = Log::Log4perl->get_logger("listAllUsers.pl");

# get the params
my $host = "";
my $path = "";
my $username = "";
my $password = "";

## Get console line arguments
GetOptions('host=s' => \$host, 
	   'path=s' => \$path,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   );

if (!$host) {
    print "usage: ./listAllUsers.pl --host=my.wiki.org [--path=w] [--username=foo] [--password=bar]\n";
    exit;
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

foreach my $user ($site->allUsers()) {
    print $user->{'name'}."\t".$user->{'id'}."\n";
}

exit;
