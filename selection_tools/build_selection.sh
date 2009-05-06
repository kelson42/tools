#!/bin/bash

LANG=$1
WIKI=$LANG"wiki"

if [ "$WIKI" = '' ];
then
    echo "usage: WP1.sh <lang> (en for enwiki for example)"
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

createDirIfNecessary ./tmp/$WIKI
createDirIfNecessary ./tmp/$WIKI/source
createDirIfNecessary ./tmp/$WIKI/target

if [ -e ./tmp/$WIKI/date ]
then
    LAST_VERSION=`cat ./tmp/$WIKI/date`
    if [ ! $LAST_VERSION = $CURRENT_VERSION ]
    then
	rm ./tmp/$WIKI/date
	rm ./tmp/$WIKI/source/* >& /dev/null
    fi
fi

echo $CURRENT_VERSION > ./tmp/$WIKI/date

## GET SQL DUMPS FROM download.wikimedia.org
wget --continue -O ./tmp/$WIKI/source/$WIKI-latest-page.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-page.sql.gz
wget --continue -O ./tmp/$WIKI/source/$WIKI-latest-pagelinks.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-pagelinks.sql.gz
wget --continue -O ./tmp/$WIKI/source/$WIKI-latest-langlinks.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-langlinks.sql.gz
wget --continue -O ./tmp/$WIKI/source/$WIKI-latest-redirect.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-redirect.sql.gz
wget --continue -O ./tmp/$WIKI/source/$WIKI-latest-categorylinks.sql.gz http://download.wikimedia.org/$WIKI/latest/$WIKI-latest-categorylinks.sql.gz

rm ./tmp/$WIKI/target/* >& /dev/null

## BUILD PAGES INDEXES
cat ./tmp/$WIKI/source/$WIKI-latest-page.sql.gz | gzip -d | tail -n +38 | ./bin/pages_parser | egrep "^[0-9]+ 0 " | sort -n -t " " -k 1,1 | gzip > ./tmp/$WIKI/target/main_pages_sort_by_ids.lst.gz

## BUILD TALK INDEXES
cat ./tmp/$WIKI/source/$WIKI-latest-page.sql.gz | gzip -d | tail -n +38 | ./bin/pages_parser | egrep "^[0-9]+ 1 " | sort -n -t " " -k 1,1 | gzip > ./tmp/$WIKI/target/talk_pages_sort_by_ids.lst.gz

## BUILD CATEGORIES INDEXES
cat ./tmp/$WIKI/source/$WIKI-latest-page.sql.gz | gzip -d | tail -n +38 | ./bin/pages_parser | egrep "^[0-9]+ 14 " | sort -n -t " " -k 1,1 | gzip > ./tmp/$WIKI/target/categories_sort_by_ids.lst.gz

## BUILD PAGELINKS INDEXES
cat ./tmp/$WIKI/source/$WIKI-latest-pagelinks.sql.gz| gzip -d | tail -n +28 | ./bin/pagelinks_parser | gzip > ./tmp/$WIKI/target/pagelinks.lst.gz

## BUILD LANGLINKS INDEXES
cat ./tmp/$WIKI/source/$WIKI-latest-langlinks.sql.gz | gzip -d | tail -n +28 | ./bin/langlinks_parser | sort -n -t " " -k 1,1 | gzip > ./tmp/$WIKI/target/langlinks_sort_by_ids.lst.gz

## BUILD REDIRECT INDEXES
cat ./tmp/$WIKI/source/$WIKI-latest-redirect.sql.gz | gzip -d | tail -n +28 | ./bin/redirects_parser | sort -n -t " " -k 1,1 | gzip > ./tmp/$WIKI/target/redirects_sort_by_ids.lst.gz

## BUILD CATEGORYLINKS INDEXES
cat ./tmp/$WIKI/source/$WIKI-latest-categorylinks.sql.gz | gzip -d | tail -n +28 | ./bin/categorylinks_parser | sort -n -t " " -k 1,1 | gzip > ./tmp/$WIKI/target/categorylinks_sort_by_ids.lst.gz

## BUILD CHARTS INDEXES
./bin/filter_charts.pl --chartsDirectory=./tmp/charts/ --language=$LANG | gzip > ./tmp/$WIKI/target/charts.lst.gz

## BUILD COUNTS
./bin/build_counts.pl --pagesFile=./tmp/$WIKI/target/main_pages_sort_by_ids.lst.gz --pagelinksFile=./tmp/$WIKI/target/pagelinks.lst.gz --langlinksFile=./tmp/$WIKI/target/langlinks_sort_by_ids.lst.gz --redirectsFile=./tmp/$WIKI/target/redirects_sort_by_ids.lst.gz --chartsFile=./tmp/$WIKI/target/charts.lst.gz | gzip > ./tmp/$WIKI/target/counts_sort_by_ids.lst.gz

## BUILD IMPORTANCE SCORES
./bin/build_importance_scores.pl --countsFile=./tmp/$WIKI/target/counts_sort_by_ids.lst.gz | gzip > ./tmp/$WIKI/target/importance_scores.lst.gz