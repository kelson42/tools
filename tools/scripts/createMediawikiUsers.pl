#!/usr/bin/perl
use lib '../classes/';

use utf8;
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;

my $username;
my $password;
my $host;
my $path;
my $forceUserId;
my $database;
my $databaseUsername;
my $databasePassword;
my %users;

my $possible = 'abcdefghijkmnpqrstuvwxyz23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

sub usage() {
    print "createMediawikiUsers.pl --host=testwiki [--path=w] --username=foo --password=bar [--forceUserId] [--database=wiki] [--databaseUsername] [--databasePassword]\n";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'host=s' => \$host,
	   'path=s' => \$path,
	   'forceUserId' => \$forceUserId,
	   'database=s' => \$database,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword,
);

if ( !$host || !$username || !$password) {
    usage();
    exit 0;
}

# readFromStdin
while (my $entry = <STDIN>) {
    $entry =~ s/\n//;
    my ($name, $id) = split( /\t/, $entry);
    $users{$name} = $id;
}

# Create users
foreach my $name (keys(%users)) {
    my $user = $users{$name};
    my $password = "";
    while (length($password) < 10) {
	$password .= substr($possible, (int(rand(length($possible)))), 1);
    }

    print $name."\t".$password."\n";
}



