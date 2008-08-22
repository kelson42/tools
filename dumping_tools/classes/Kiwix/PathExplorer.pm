package Kiwix::PathExplorer;

use strict;
use warnings;
use Data::Dumper;
use File::Find;
use threads;
use threads::shared;

my $path : shared = "";
my $filesMutex : shared = 1;
my @files : shared;
my $bufferSize : shared = 10000;
my $exploring : shared = -1;
my $thread;
my $loggerMutex : shared = 1;
my $logger;
my $filterRegexp : shared;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub getNext {
    my $self = shift;
    my @threads;

    lock($exploring);

    if ($exploring == -1) {
	$self->log("info", "Start find on ".$self->path().".");
	$thread = threads->new(\&explore, $self);
	$exploring = 1;
    } else {
	if ($exploring == 0){
	    foreach my $thr (threads->list) {
		if ($thr->tid && !threads::equal($thr, threads->self)) {
		    $thr->join();
		}
	    }
	}
    }

    lock($filesMutex);

    while (!scalar(@files) && $exploring == 1) {
	cond_timedwait($filesMutex, time() + 0.1);
	cond_timedwait($exploring, time() + 0.1);
    }

    return shift(@files);
}

sub explore {
    my $self = shift;
    
    unless ($self->path) {
	$self->log("error", "Please specify a path before exploring it.");
	return;
    }

    find(\&getFiles, $self->path());

    lock($exploring);
    $exploring = 0;
}

sub stop {
    my $self = shift;
    $thread->join();
    lock($exploring);
    $exploring = -1;
    lock($filesMutex);
    @files = ();
}

sub reset {
    my $self = shift;
    $self->stop();
}

sub getFiles {
    lock($filesMutex);
    while (scalar(@files) > $bufferSize ) {
	cond_timedwait($filesMutex, time() + 0.1);
    }

    if ($filterRegexp) {
	push(@files, $File::Find::name)
	    if ($File::Find::name =~ /$filterRegexp/i );
    } else {
	push(@files, $File::Find::name);
    }
}

sub path {
    my $self = shift;
    lock($path);
    if (@_) { $path = shift }
    return $path;
}

sub bufferSize {
    my $self = shift;
    lock($bufferSize);
    if (@_) { $bufferSize = shift }
    return $bufferSize;
}

sub filterRegexp {
    my $self = shift;
    lock($filterRegexp);
    if (@_) { $filterRegexp = shift }
    return $filterRegexp;
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
