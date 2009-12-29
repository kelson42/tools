#!/bin/sh

export LC_ALL=C

stop=`curl http://dammit.lt/wikistats/ 2> /dev/null | grep ".gz" | sed s/\<tr\>\<td\ class=\"n\"\>\<a\ href=\"// | sed s/\".*// | sed '1q' | cut -d "-" -f2`

echo "Stop date is $stop";

for date in `find . -name "pagecounts-*-*.gz" | cut -d - -f2 | sort -u` ; 
do 
    file_count=`find . -name "pagecounts-$date-*gz" | wc -l` ;
    if [ $file_count -gt 23 ] ;
    then

	if [ $date -eq $stop ] ;
	then
	    echo "Charts files for the $date are present on the wikistats web site. Merging process have to stop now."
	    exit;
	fi

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