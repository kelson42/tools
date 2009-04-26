#!/bin/sh

WIKI=$1
LANG=C
TMP=`pwd`/target

export $LANG
export $WIKI
echo $WIKI

rm -rf $TMP/*

for i in `find . -name "*.gz" | cut -d\- -f2 | sort -u`; do perl bin/phase1h.pl $WIKI source/pagecounts-$i-* | sort -T$TMP  -k 3 -t " " | perl bin/tally.pl > target/$i.out ; done
