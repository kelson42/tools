package Kiwix::PathExplorer;

use strict;
use warnings;
use Data::Dumper;
use File::Find;
use threads;
use threads::shared;

my $path : shared = "";
my @files : shared;

my $thread;

my $loggerMutex : shared = 1;
my $filesMutex : shared = 1;
my $logger;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub getNext {
    my $self = shift;
    my @threads;

    unless ($thread) {
	$self->log("info", "Start find on ".$self->path().".");
	$thread = threads->new(\&explore, $self);
    }

    lock($filesMutex);
    while (!scalar(@files) && $thread) {
	cond_timedwait($filesMutex, time() + 1);
	print "titi\n";
    }

    lock($filesMutex);
    return shift(@files);
}

sub explore {
    my $self = shift;
    
    unless ($self->path) {
	$self->log("error", "Please specify a path before exploring it.");
	return;
    }

    find(\&getFiles, $self->path());
    $thread->join();
    $thread = undef;
}

sub getFiles {
    lock($filesMutex);
    while (scalar(@files) > 10000 ) {
	cond_timedwait($filesMutex, time() + 1);
	print "toto\n";
    }
    push(@files, $File::Find::name);
}

sub path {
    my $self = shift;
    lock($path);
    if (@_) { $path = shift }
    return $path;
}

# loggin
sub logger {
    my $self = shift;
    lock($loggerMutex);
    if (@_) { $logger = shift }
    return $logger;
}

sub log {
    my $self = shift;
    lock($loggerMutex);
    return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
