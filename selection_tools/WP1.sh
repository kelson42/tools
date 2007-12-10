#!/bin/bash

WIKI=$1
EMPTY=''

if [ "$WIKI" = "$EMPTY" ];
then
    echo "usage: WP1.sh <wikiname> (enwiki for example)"
    exit
fi

rm -rf $WIKI
mkdir $WIKI
mkdir $WIKI/source
mkdir $WIKI/target

## GET SQL DUMPS FROM download.wikimedia.org
wget -O ./$WIKI/source/$WIKI-latest-page.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-page.sql.gz
wget -O ./$WIKI/source/$WIKI-latest-pagelinks.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-pagelinks.sql.gz
wget -O ./$WIKI/source/$WIKI-latest-langlinks.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-langlinks.sql.gz
wget -O ./$WIKI/source/$WIKI-latest-redirect.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-redirect.sql.gz
wget -O ./$WIKI/source/$WIKI-latest-categorylinks.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-categorylinks.sql.gz

## BUILD PAGES INDEXES
cat ./$WIKI/source/$WIKI-latest-page.sql.gz | gzip -d | tail -n +38 | ./bin/pages_parser | egrep "^[0-9]+ 0 " | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/main_pages_sort_by_ids.lst.gz

## BUILD PAGELINKS INDEXES
cat ./$WIKI/source/$WIKI-latest-pagelinks.sql.gz| gzip -d | tail -n +28 | ./bin/pagelinks_parser | gzip > ./$WIKI/target/pagelinks.lst.gz

## BUILD LANGLINKS INDEXES
cat ./$WIKI/source/$WIKI-latest-langlinks.sql.gz | gzip -d | tail -n +28 | ./bin/langlinks_parser | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/langlinks_sort_by_ids.lst.gz

## BUILD REDIRECT INDEXES
cat ./$WIKI/source/$WIKI-latest-redirect.sql.gz | gzip -d | tail -n +28 | ./bin/redirects_parser | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/redirects_sort_by_ids.lst.gz

## BUILD CATEGORYLINKS INDEXES
cat ./$WIKI/source/$WIKI-latest-categorylinks.sql.gz | gzip -d | tail -n +28 | ./bin/categorylinks_parser | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/categorylinks_sort_by_ids.lst.gz

## BUILD COUNTS
./bin/build_counts.pl --pagesFile=./$WIKI/target/main_pages_sort_by_ids.lst.gz --pagelinksFile=./$WIKI/target/pagelinks.lst.gz --langlinksFile=./$WIKI/target/langlinks_sort_by_ids.lst.gz --redirectsFile=./$WIKI/target/redirects_sort_by_ids.lst.gz | gzip > ./$WIKI/target/counts_sort_by_ids.lst.gz