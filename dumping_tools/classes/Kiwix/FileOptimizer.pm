package Kiwix::FileOptimizer;

use strict;
use warnings;
use Data::Dumper;

my $logger;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub optimize {
    my $self = shift;
    my $file = shift;
    
    unless ($file) {
	$self->log("error", "You have to give a file to be optmized.");
    }
}

# loggin
sub logger {
    my $self = shift;
    if (@_) { $logger = shift }
    return $logger;
}

sub log {
    my $self = shift;
    return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
