#!/usr/bin/perl

use strict;
use warnings;
use Graph;
use Data::Dumper;
use Getopt::Long;
use PerlIO::gzip;

my $pagesFile="";
my $categoriesFile="";
my $categorylinksFile="";
my $redirectsFile="";
my $modus="";
my $start="";

my %done;
my @todo;

GetOptions('categoriesFile=s' => \$categoriesFile, 'pagesFile=s' => \$pagesFile, 'categorylinksFile=s' => \$categorylinksFile, 'redirectsFile=s' => \$redirectsFile, 'modus=s' => \$modus, 'start=s' => \$start );

if (!$pagesFile || !$categoriesFile || !$categorylinksFile || !$redirectsFile || !$modus || !($modus eq "get_parents" || $modus eq "get_children" ) || !$start) {
    print "usage: ./parse_categories.pl --pagesFile=main_pages_sort_by_ids.lst.gz --categoriesFile=categories_sort_by_ids.lst.gz  --categorylinksFile=categorylinks.lst.gz --redirectsFile=redirects_sort_by_ids.lst.gz --modus=[get_children|get_parents] --start=my_start_page\n";
    exit;
};

$start =~ s/ /_/g;
$start = ucfirst($start);

my $categories_graph = Graph->new(directed=>1);

my ($pageId, $pageNamespace, $pageName, $pageRedirect);
my ($categoryId, $categoryNamespace, $categoryName, $categoryRedirect);
my ($redirectSourcePageId, $redirectTargetNamespace, $redirectTargetPageName);
my ($categorylinkSourceId, $categorylinkTargetName);

my (%pages_hash, %revert_pages_hash, %categories_hash, %revert_categories_hash, %redirects_hash);

open( PAGES_FILE, '<:gzip', $pagesFile ) or die("Unable to open file $pagesFile.\n");
while( <PAGES_FILE> ) {
    ($pageId, $pageNamespace, $pageName, $pageRedirect) = split(" ", $_);
    unless ($pageNamespace) {
	$pages_hash{$pageId} = $pageName;
	$revert_pages_hash{$pageName} = $pageId;
    }
}
close( PAGES_FILE );

open( CATEGORIES_FILE, '<:gzip', $categoriesFile ) or die("Unable to open file $categoriesFile.\n");
while( <CATEGORIES_FILE> ) {
    ($categoryId, $categoryNamespace, $categoryName, $categoryRedirect) = split(" ", $_);
    if ($categoryNamespace eq "14") {
        $categories_hash{$categoryId} = $categoryName;
        $revert_categories_hash{$categoryName} = $categoryId;
    }
}
close( CATEGORIES_FILE );

open( CATEGORYLINKS_FILE, '<:gzip', $categorylinksFile ) or die("Unable to open file $categorylinksFile.\n");
while( <CATEGORYLINKS_FILE> ) {
    ($categorylinkSourceId, $categorylinkTargetName) = split(" ", $_);
    my $categorylinkTargetId = $revert_categories_hash{$categorylinkTargetName};
    if (defined($categorylinkTargetId)) {
	$categories_graph->add_edge($categorylinkTargetId, $categorylinkSourceId);
    }
}
close( CATEGORYLINKS_FILE );

my $start_id = revertResolve(ucfirst($start));
push(@todo, $start_id);

while (my $id = shift(@todo)) {
    next unless (defined($id));
    next if (exists($done{$id}));
    $done{$id} = 1;
 #   print "--------------------".$id."\n";    

    if ( $modus eq "get_parents") {
	my @edges = $categories_graph->edges_to($start_id);
	foreach my $edge (@edges) {
	    print resolve($edge->[0])."\n";
	}
    } else {
	my @edges = $categories_graph->edges_from($start_id);
	foreach my $edge (@edges) {
	    my $result;
	    if (isCategoryId($edge->[1])) {
		$result = resolveCategory($edge->[1]);
#		print "====".$result."\n";
		unless (exists($done{$edge->[1]})) {
#		print "+++++++".$result."\n";
		    push(@todo, $edge->[1]);
		}
	    }
	    else {
		$result = resolvePage($edge->[1]);
	    }

	    if ($result) {
		print $result."\n";
	    }
	}
    }
}    

sub revertResolve {
    if (substr($_[0], 0, 9) eq "Category:") {
	return $revert_categories_hash{substr($_[0], 9)}; 
    } else {
	return $revert_pages_hash{$_[0]};
    }
}

sub resolve {
    if (exists($pages_hash{$_[0]})) {
	return resolvePage($_[0]);
    }
    
    if (isCategoryId($_[0])) {
	return resolveCategory($_[0]);
    }
}

sub resolvePage {
    return $pages_hash{$_[0]};
}

sub resolveCategory {
    return "Category:".$categories_hash{$_[0]};
}

sub isCategoryId {
    return exists($categories_hash{$_[0]});
}
