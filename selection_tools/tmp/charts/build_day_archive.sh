#!/bin/sh

for date in `find . -name "pagecounts-*-*.gz" | cut -d - -f2 | sort -u` ; 
do 
    file_count=`find . -name "pagecounts-$date-*gz" | wc -l` ;
    if [ $file_count -gt 23 ] ;
    then 
	echo "Merging $date files..."
	for file in `find . -name "pagecounts-$date-*.gz"` ; do cat $file | gzip -d ; done | sort -t " " -k 1,2 | ./simplify_charts.pl | bzip2 -z -c > $date.bz2
	if [ $? -eq 0 ] ;
	then 
	    echo "Removing pagecounts-$date-*.gz..."
	    rm pagecounts-$date-*.gz ;
	else
	    echo "Something was wrong, not removing pagecounts-$date-*.gz."
	fi
    fi
done