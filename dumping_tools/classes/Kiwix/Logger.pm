package Kiwix::Logger;
use base Log::Log4perl;

use strict;
use warnings;
use Data::Dumper;
use File::Spec::Functions qw(rel2abs);
use File::Basename;

sub new {
    my $class = shift;
    my $name = shift;
    my $self = Log::Log4perl->init(dirname(rel2abs($0))."/../conf/log4perl");
    $self = Log::Log4perl->get_logger($name);
    return $self;
}

# Return the logfile path
sub getLogFilename {
    return dirname(rel2abs($0))."/../log/all.log";
}

1;
