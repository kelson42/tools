#!/usr/bin/perl

use lib '/home/veblen/perl/lib';

use PerlIO::gzip;
use Encode;
use URI::Escape;

foreach $file ( @ARGV ) { 
  open IN, "<:gzip", $file or die;

  $file =~ m/(\d+)/;
  $date = $1;  

  print STDERR $file .":";
 
  $i = 0;
  while ( $line = <IN> ) {
    $i++;
    if ( $i % 100000 == 0) { print STDERR "."; }

    next unless ( $line =~ /^en /);

    @parts = split / /, $line;
    if ( defined $parts[5] ) { 
      print STDERR "\nBAD $parts[0] $parts[1]\n$line";
    }
    $name = $parts[1];
    $count = $parts[2];

    $name =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

    next if ( $name =~ /\n/);
  
    $name = ucfirst($name);

    $name =~ s/ /_/g;
    $name =~ s/#.*//;
    next if ( length $name > 255);

    # We're only interested in main namespace articles
    next if ($name =~ /^((Wikipedia:)|(Wikipedia_talk)|(Category:)|(Image:)|(User:)|(User talk:)|(Special:)|(Template:)|(Talk:))/);

    # These are ad hoc exceptions based on examination of the data
    next if ($name =~ /Wikipedia.*the.*free.*encyclopedia/);
    next if ($name =~ /files.*css/);
    next if ($name =~ /files\//);
 
    print STDOUT "$date $count $name\n";
  }

  print STDERR " $i\n";
}

