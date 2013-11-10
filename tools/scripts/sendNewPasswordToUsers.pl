#!/usr/bin/perl
use lib '../classes/';

use utf8;
use strict;
use warnings;
use DBI;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;

my $host;
my $path;
my $username;
my $password;
my $userCount;

my %users;

sub usage() {
    print "sendNewPasswordToUsers.pl --username=foo --password=bar --host=uk.wikimedia.org [--path=w] [--userCount=42]\n";
}

GetOptions('path=s' => \$path,
	   'hosts=s' => \$host,
	   'username=s' => \$username,
	   'password=s' => \$password,
	   'userCount=s' => \$userCount
);

if (!$username || !$password || !$host) {
    usage();
    exit 1;
}

# readFromStdin
while (my $entry = <STDIN>) {
    $entry =~ s/\n//;
    my ($name, $password, $done) = split( /\t/, $entry);
    
    if ($name && $password) {
	my %details;
	$details{"password"} = $password;
	$details{"done"} = $done;
	$users{$name} = \%details;
    } else {
	print STDERR "Skip user $name, no id for this user...\n";
    }
}

# Check if there is a problem with the input file
if ($userCount && (scalar(keys(%users)) != $userCount)) {
    print STDERR "Something must be wrong with the input files which contains ".(scalar(keys(%users)))." and the nbUsers value which is ".$userCount."\n";
    exit 1;
}

# Connect to mediawiki
my $site = Mediawiki::Mediawiki->new();
$site->hostname($host);
$site->path($path);
$site->user($username);
$site->password($password);
$site->setup();

# Retrieve information (is emailable?) about users
foreach my $user (keys(%users)) {
    my $details = $users{$user};

    if (my $infos = $site->userInfo($user)) {
	$users{$user}->{"emailable"} = exists($infos->{'emailable'});
    } else {
	print STDERR "Unable to retrieve information about $user.\n";
	exit 1;
    }
}

# Go through all users
my $subject = "Wikimedia UK's wiki migration notice";
foreach my $user (keys(%users)) {
    my $details = $users{$user};
    my $message = "Dear contributor

Since its creation, Wikimedia UK's wiki has been hosted by the Wikimedia Foundation. The hosting for this site was migrated from the Foundation's datacenter to the Wikimedia UK's over the last week-end of September (28-29th September). It was not possible to migrate non-public account information. This includes watch lists, account preferences, contact email, or current password for registered users.

We have recreated 'stub-accounts' on the migrated site and want to communicate to you your new password:
* user: ".$user."
* password: ".$details->{"password"}."

We invite you to change it as soon at possible:
http://wiki.wikimedia.org.uk/w/index.php?title=Special:UserLogin

If you want to know more about this migration:
https://wiki.wikimedia.org.uk/wiki/WMUK_wiki_migration

Kind regards
Wiki migration team";

    if ($details->{"emailable"}) {
	if ($site->emailUser($user, $subject, $message)) {
	    print $user."\t".$details->{"password"}."\tdone\n";
	} else {
	    print STDERR "Unable to send an email to $user.\n";
	    print $user."\t".$details->{"password"}."\n";
	}
    } else {
	print $user."\t".$details->{"password"}."\n";
    }
}

print STDERR "Finished!";
exit 0;

