#!/bin/sh

LANG=C
export LANG

TMP=`pwd`/target

cat target/*.out  \
  | sort -T$TMP -k 3 -t " " \
  | ./bin/average-trim.pl \
  | gzip > target/hitcounts.raw.gz

cat target/hitcounts.raw.gz | gzip -d | sort -n -r -t " " -k2,2 | gzip > target/sorted_histcounts.raw.gz