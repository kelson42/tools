#!/bin/bash

WIKI=$1

if [ "$WIKI" = '' ];
then
    echo "usage: WP1.sh <wikiname> (enwiki for example)"
    exit
fi

CURRENT_VERSION=`curl -s http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-abstract.xml-rss.xml | grep "</link>" | tail -n 1 | sed -e 's/<//g' | cut -d "/" -f 5`

if [ "$CURRENT_VERSION" = '' ];
then
    echo "error: no dump are available for this name."
    exit
fi

createDirIfNecessary()
{
  if [ ! -e $1 ]
  then
    mkdir $1
  fi
}

createDirIfNecessary ./$WIKI
createDirIfNecessary ./$WIKI/source
createDirIfNecessary ./$WIKI/target

if [ -e ./$WIKI/date ]
then
    LAST_VERSION=`cat ./$WIKI/date`
    if [ ! $LAST_VERSION = $CURRENT_VERSION ]
	then
	rm ./$WIKI/date
	rm ./$WIKI/source/* >& /dev/null
    fi
    wget --connect-timeout=10 --tries=2 --continue -O ./$WIKI/source/wikicharts_cur_$WIKI.sql.gz http://tools.wikimedia.de/~cbm/dumps/u_leon_wikistats_p/2007-12-10/wikicharts_cur_$WIKI.sql.gz
fi

echo $CURRENT_VERSION > ./$WIKI/date

## GET SQL DUMPS FROM download.wikimedia.org
wget --continue -O ./$WIKI/source/$WIKI-latest-page.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-page.sql.gz
wget --continue -O ./$WIKI/source/$WIKI-latest-pagelinks.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-pagelinks.sql.gz
wget --continue -O ./$WIKI/source/$WIKI-latest-langlinks.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-langlinks.sql.gz
wget --continue -O ./$WIKI/source/$WIKI-latest-redirect.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-redirect.sql.gz
wget --continue -O ./$WIKI/source/$WIKI-latest-categorylinks.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-categorylinks.sql.gz

rm ./$WIKI/target/* >& /dev/null

## BUILD PAGES INDEXES
cat ./$WIKI/source/$WIKI-latest-page.sql.gz | gzip -d | tail -n +38 | ./bin/pages_parser | egrep "^[0-9]+ 0 " | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/main_pages_sort_by_ids.lst.gz

## BUILD TALK INDEXES
cat ./$WIKI/source/$WIKI-latest-page.sql.gz | gzip -d | tail -n +38 | ./bin/pages_parser | egrep "^[0-9]+ 1 " | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/talk_pages_sort_by_ids.lst.gz

## BUILD CATEGORIES INDEXES
cat ./$WIKI/source/$WIKI-latest-page.sql.gz | gzip -d | tail -n +38 | ./bin/pages_parser | egrep "^[0-9]+ 14 " | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/categories_sort_by_ids.lst.gz

## BUILD PAGELINKS INDEXES
cat ./$WIKI/source/$WIKI-latest-pagelinks.sql.gz| gzip -d | tail -n +28 | ./bin/pagelinks_parser | gzip > ./$WIKI/target/pagelinks.lst.gz

## BUILD LANGLINKS INDEXES
cat ./$WIKI/source/$WIKI-latest-langlinks.sql.gz | gzip -d | tail -n +28 | ./bin/langlinks_parser | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/langlinks_sort_by_ids.lst.gz

## BUILD REDIRECT INDEXES
cat ./$WIKI/source/$WIKI-latest-redirect.sql.gz | gzip -d | tail -n +28 | ./bin/redirects_parser | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/redirects_sort_by_ids.lst.gz

## BUILD CATEGORYLINKS INDEXES
cat ./$WIKI/source/$WIKI-latest-categorylinks.sql.gz | gzip -d | tail -n +28 | ./bin/categorylinks_parser | sort -n -t " " -k 1,1 | gzip > ./$WIKI/target/categorylinks_sort_by_ids.lst.gz

## BUILD CHARTS INDEXES
cat ./$WIKI/source/wikicharts_cur_$WIKI.sql.gz | gzip -d | tail -n +40 | ./bin/charts_parser | egrep "^0 " | gzip > ./$WIKI/target/charts.lst.gz

## BUILD COUNTS
./bin/build_counts.pl --pagesFile=./$WIKI/target/main_pages_sort_by_ids.lst.gz --pagelinksFile=./$WIKI/target/pagelinks.lst.gz --langlinksFile=./$WIKI/target/langlinks_sort_by_ids.lst.gz --redirectsFile=./$WIKI/target/redirects_sort_by_ids.lst.gz --chartsFile=./$WIKI/target/charts.lst.gz | gzip > ./$WIKI/target/counts_sort_by_ids.lst.gz
