#!/usr/bin/perl
use lib '../classes/';

use utf8;
use strict;
use warnings;
use DBI;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;

my $path;
my $database;
my $databaseUsername;
my $databasePassword;
my %users;
my $possible = 'abcdefghijkmnpqrstuvwxyz23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

sub usage() {
    print "createMediawikiUsers.pl --path=/var/www/wiki/w/ --database=wiki --databaseUsername=foo --databasePassword=bar\n";
}

GetOptions('path=s' => \$path,
	   'database=s' => \$database,
	   'databaseUsername=s' => \$databaseUsername,
	   'databasePassword=s' => \$databasePassword,
);

if ( !$path || !$database || !$databaseUsername || !$databasePassword) {
    usage();
    exit 0;
}

# change password path
my $script = $path."/maintenance/changePassword.php";
unless (-f $script) {
    die("The path you have give is wront, $script does not exist.\n");
}

# readFromStdin
while (my $entry = <STDIN>) {
    $entry =~ s/\n//;
    my ($name, $id) = split( /\t/, $entry);
    $users{$name} = $id;
}

# Connect to database
my $dsn = "DBI:mysql:$database;host=localhost:3306";
my $dbh = DBI->connect($dsn, $databaseUsername, $databasePassword) or die ("Unable to connect to the database.");
my $sql;

# Create users
foreach my $name (keys(%users)) {
    my $userId = $users{$name};
    my $userName = $name;
    $userName =~ s/_/ /g;
    my $password = "";
    while (length($password) < 10) {
	$password .= substr($possible, (int(rand(length($possible)))), 1);
    }

    my $insert_handle = $dbh->prepare_cached("INSERT INTO user (user_id, user_name) VALUES (?,?)"); 

    die "Couldn't prepare queries; aborting"
	unless defined $insert_handle;

    $insert_handle->execute($userId, $userName) or die ("Unable to insert new user");
    
    my $cmd = "php $script --userid='$userId' --password='$password'";
    `$cmd`;

    print $name."\t".$password."\n";
}



