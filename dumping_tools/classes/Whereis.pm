package Whereis;

use strict;
use warnings;

use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(whereis);

sub whereis {
    my $prog = shift;
    return unless ($prog);
    
    foreach my $dir (split /:/, $ENV{PATH}) {
	if (-x "$dir/$prog") {
	    return "$dir/$prog";
	}
    }
}

1;
