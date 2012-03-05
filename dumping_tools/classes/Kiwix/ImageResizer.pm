package Kiwix::ImageResizer;

use strict;
use warnings;
use Data::Dumper;
use Kiwix::PathExplorer;
use Image::Magick ;
use Encode;
use Whereis;
use Cwd 'abs_path';

use threads;
use threads::shared;

my $contentPath : shared;
my $maxWidth : shared;
my $maxHeight : shared;

my %queue : shared;
my $threadCount = 2;
my $queueMutex : shared = 1;
my @threads;
my $isRunnable : shared = 1;
my $delay : shared = 1;

my $loggerMutex : shared = 1;
my $logger;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub findAndResize {
    my $self = shift;

    # Few checks
    unless ($self->contentPath) {
	$self->log("error", "You have to give a path to explore to search files to be optmized.");
	return;
    }

    # Start the threads to optimize files
    $self->log("info", $threadCount." thread(s) launched...");
    for (my $i=0; $i<$threadCount; $i++) {
        $threads[$i] = threads->new(\&findAndResizeImages, $self, $i);
    }

    # Start the directory walker to find files to optimize
    my $explorer = new Kiwix::PathExplorer();
    $explorer->filterRegexp("\.(jpg|jpeg|gif|png)");
    $explorer->path($self->contentPath());
    while (my $file = $explorer->getNext()) {
	$self->addImageToResize($file);
    }

    while ($self->isRunnable()) {
	$self->log("error", "No images anymore to add to queue.");
	sleep($self->delay());
	unless ($self->getQueueSize()) {
	    $self->isRunnable(0);
	}
    }

    # Kill all threads
    for (my $i=0; $i<$threadCount; $i++) {
	$threads[$i]->join();
    }
}

sub findAndResizeImages {
    my $self = shift;
    my $id = shift;
    my $maxHeight = $self->maxHeight();

    $self->log("info", "Starting thread $id...");
    my $imager = new Image::Magick;

    while ($self->isRunnable()) {
	my $file = $self->getImageToResize();

	if ($file) {
	    print STDERR "Get Infos from $file\n";

	    my $logInfo = "";
	    my ($width, $height, $size, $format) = $imager->Ping($file);
	    if ($width && $width > $self->maxWidth() && $height < $width) {
		$logInfo = "Resizing $file : $width x $height";
		my $cmd = "convert \"$file\" -resize ".$self->maxWidth()."x \"$file\"";
		`$cmd`;
	    } elsif ($height && $height > $self->maxHeight()) {
		$logInfo = "Resizing $file : $width x $height";
		my $cmd = "convert \"$file\" -resize x".$self->maxHeight()." \"$file\"";
		`$cmd`;
	    } else {
		$logInfo = "Nothing to do for $file ($width x $height).";
	    }
	    
	    print STDERR $logInfo."\n";
	    $self->log("info", $logInfo);
	} else {
	    $self->log("error", "You have to specify an image to optimize.");
	    sleep($self->delay());
	}
    }

}

sub contentPath {
    my $self = shift;
    lock($contentPath);
    if (@_) {
	$contentPath = abs_path(shift) ;
	if (! substr($contentPath, length($contentPath)-1) eq "/" ) {
            $contentPath = $contentPath + "/";
	}
    }
    return $contentPath;
}

sub maxWidth {
    my $self = shift;
    lock($maxWidth);
    if (@_) { $maxWidth = shift }
    return $maxWidth;
}

sub maxHeight {
    my $self = shift;
    lock($maxHeight);
    if (@_) { $maxHeight = shift }
    return $maxHeight;
}

sub isRunnable {
    my $self = shift;
    lock($isRunnable);
    if (@_) { $isRunnable = shift }
    return $isRunnable;
}

sub delay {
    my $self = shift;
    return int(rand(5));
}

sub threadCount {
    my $self = shift;
    if (@_) { $threadCount = shift }
    return $threadCount;
}

# queue
sub addImageToResize {
    my $self = shift;

    if (@_) {
        my $file = ucfirst(shift);

        lock($queueMutex);
        unless ( exists($queue{$file}) ) {
            $queue{$file} = 1;
        }
    }
}

sub getImageToResize {
    my $self = shift;
    my $file;

    lock($queueMutex);

    if (keys(%queue)) {
	($file) = keys(%queue);

        if ($file) {
            delete($queue{$file});
        } else {
            $self->log("error", "empty file found in queue.");
        }
    }

    unless (Encode::is_utf8($file)) {
        $file = decode_utf8($file);
    }

    return $file;
}

sub getQueueSize {
    my$self = shift;

    lock($queueMutex);
    return (scalar(keys(%queue)));
}

# loggin
sub logger {
    my $self = shift;

    lock($loggerMutex);
    if (@_) { 
	$logger = shift ;
    }
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
