#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use PerlIO::gzip;

my $countsFile="";
my $count = 0;

GetOptions('countsFile=s' => \$countsFile);

if (!$countsFile) {
    print "usage: ./build_importance_scores.pl --countsFile=counts_sort_by_ids.lst.gz\n";
    exit;
};

my %hash;
my %score;
my %langlinkHash;
my %pagelinkHash;
my %pagehitHash;

my @pageIds;

my @sortedlanglinks;
my @sortedpagelinks;
my @sortedpagehits;
my @sortedscores;

my ($pageId, $pageName, $langlinkCount, $pagelinkCount, $pagehitCount);

open( COUNTS_FILE, '<:gzip', $countsFile ) or die("Unable to open file $countsFile.\n");
while( <COUNTS_FILE> ) {
    $count++;
 
   ($pageId, $pageName, $langlinkCount, $pagelinkCount, $pagehitCount) = split(" ", $_);

    $hash{$pageId} = $pageName;
    $langlinkHash{$pageId} = $langlinkCount;
    $pagelinkHash{$pageId} = $pagelinkCount;
    $pagehitHash{$pageId} = $pagehitCount;

    push(@pageIds, $pageId);
}
close( COUNTS_FILE );

@sortedlanglinks = sort { $langlinkHash{$b} <=> $langlinkHash{$a} } @pageIds;
@sortedpagelinks = sort { $pagelinkHash{$b} <=> $pagelinkHash{$a} } @pageIds;
@sortedpagehits = sort { $pagehitHash{$b} <=> $pagehitHash{$a} } @pageIds;

my $inv=$count;
for (my $i=0 ; $i<$count ; $i++) {
    $langlinkHash{$sortedlanglinks[$i]} = $inv;
    $pagelinkHash{$sortedpagelinks[$i]} = $inv;
    $pagehitHash{$sortedpagehits[$i]} = $inv;
    $inv--;
}

foreach $pageId (@sortedpagelinks) {
    $score{$pageId} = ( $langlinkHash{$pageId} + $pagehitHash{$pageId} * 2 + $pagelinkHash{$pageId} ) / 4 ;
}

@sortedscores = sort { $score{$b} <=> $score{$a} } @pageIds;

$count=0;
foreach $pageId (@sortedscores) {
    $count++;
    print $pageId." ".$hash{$pageId}."\n";
}




