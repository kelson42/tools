#!/usr/bin/perl

use utf8;

binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );

my $offset = shift() - 1;
my $sort = shift;

my $last;
my $line = 0;;

if ($sort eq "n") {
    $last = -999999999999999999; 
    while( my $str = <> ){
	my @fields = split(" ", $str);
	if ($fields[$offset] < $last) {
	    print "Error on line $line : ".$last." not < than ".$fields[$offset]."\n";
	}
	$last = $fields[$offset];
	$line = $line + 1;
    }
}
else {
    $last = "";
    while( my $str = <> ){
        my @fields = split(" ", $str);

        if ($fields[$offset] lt $last) {
            print "Error on line $line : ".$last." not less than ".$fields[$offset]."\n";
        }
        $last = $fields[$offset];
        $line = $line + 1;
    }
}
