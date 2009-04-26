#!/usr/bin/perl

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

$data = {};
$line = <STDIN>;
chomp $line;
($date, $count, $oldarticle) = split / /, $line, 3;
$data->{$date} = $count;

$n= 0;

while ( $line = <STDIN> ) { 
  chomp $line;
  ($date, $count, $article) = split / /, $line, 3;
  if ( $article eq $oldarticle ) { 
    $data->{$date} += $count;
  } else { 
    $n++;
    if ( 0 == $n % 50000) { print STDERR "$n $oldarticle $c\n"; }
    count($oldarticle, $data);
    $oldarticle = $article;
    $data = {};
    $data->{$date} = $count;
  }
}
    
sub count { 
  my $article = shift;
  my $data = shift;

  my $average = 0;
  my @points = sort {$a <=> $b} values %$data;

  my $count = scalar @points;
  my $min = int(0.2 * $count);
  my $max = $count - $min;
  $count = 0;

  my $i;
  for( $i = $min; $i <= $max; $i++ ) { 
    $average += $points[$i];
    $count++;
  }

  $average = int($average / $count);


  if ( $average > 1) { 
    # To save disk space, and since we will take logarithms and log(1) = 0,
    # skip articles with average hitcount <= 1
    $article =~ s/ /_/g;
    print "$article $average\n";
  }

}
