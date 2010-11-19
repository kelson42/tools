package Kiwix::FileOptimizer;

use strict;
use warnings;
use Data::Dumper;
use Kiwix::PathExplorer;
use Kiwix::MimeDetector;
use Encode;
use Whereis;
use Cwd 'abs_path';

use threads;
use threads::shared;

my $contentPath : shared;
my $removeTitleTag : shared;
my $ignoreHtml : shared;

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

sub optimize {
    my $self = shift;

    # Few checks
    unless ($self->contentPath) {
	$self->log("error", "You have to give a path to explore to search files to be optmized.");
	return;
    }

    # Start the threads to optimize files
    $self->log("info", $threadCount." thread(s) launched...");
    for (my $i=0; $i<$threadCount; $i++) {
        $threads[$i] = threads->new(\&optimizeFiles, $self, $i);
    }

    # Start the directory walker to find files to optimize
    my $explorer = new Kiwix::PathExplorer();
    $explorer->path($self->contentPath());
    while (my $file = $explorer->getNext()) {
	$self->addFileToOptimize($file);
    }

    while ($self->isRunnable()) {
	$self->log("error", "No file anymore to optimize to add to queue.");
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

sub optimizeFiles {
    my $self = shift;
    my $id = shift;
    my $ignoreHtml = $self->ignoreHtml();

    $self->log("info", "Starting thread $id...");
    my $mimeDetector = new Kiwix::MimeDetector();

    while ($self->isRunnable()) {
	my $file = $self->getFileToOptimize();
	if ($file) {
	    $self->log("info", "$id : Optimizing $file.");
	    my $mimeType = $mimeDetector->getMimeType($file);
	    if ($mimeType eq "text/html" && !$ignoreHtml) {
		$self->optimizeHtml($file);
	    } elsif ($mimeType eq "image/png") {
		$self->optimizePng($file);
	    } elsif ($mimeType eq "image/gif") {     
		$self->optimizeGif($file); 
	    } elsif ($mimeType eq "image/jpeg") {
		$self->optimizeJpg($file);
	    } else {
		$self->log("info", "Nothing to be done.");
	    }
	} else {
	    $self->log("error", "You have to specify a file to optimize.");
	    sleep($self->delay());
	}
    }

}

sub optimizePng {
    my $self = shift;
    my $file = shift;
    `opt-png "$file"`;
}

sub optimizeGif {
    my $self = shift;
    my $file = shift;
    `opt-gif "$file"`;
}

sub optimizeJpg {
    my $self = shift;
    my $file = shift;
    `opt-jpg "$file"`;
}

sub optimizeHtml {
    my $self = shift;
    my $file = shift;

    my $data = $self->readFile($file);

    # remove longdesc attributes
    $$data =~ s/longdesc=\"[^\"]*\"//ig;
    
    # remove the nofollow
    $$data =~ s/rel=\"nofollow\"//ig;
    
    # remove titles
    if ($self->removeTitleTag) {
	$$data =~ s/title=\"[^\"]*\"//ig;
    }
    
    # remove spaces
    $$data =~ s/[ ]+\/>/\/>/ig;
    
    $self->writeFile($file, $data);
}

sub writeFile {
    my $self = shift;
    my $file = shift;
    my $data = shift;

    open (FILE, ">$file") or die "Couldn't open file: $file";
    print FILE $$data;
    close (FILE);
}

sub readFile {
    my $self = shift;
    my $path = shift;
    my $data = "";

    open FILE, $path or die "Couldn't open file: $path";
    while (<FILE>) {
	$data .= $_;
    }
    close FILE;

    return \$data;
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

sub removeTitleTag {
    my $self = shift;
    lock($removeTitleTag);
    if (@_) { $removeTitleTag = shift }
    return $removeTitleTag;
}

sub ignoreHtml {
    my $self = shift;
    lock($ignoreHtml);
    if (@_) { $ignoreHtml = shift }
    return $ignoreHtml;
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
sub addFileToOptimize {
    my $self = shift;

    if (@_) {
        my $file = ucfirst(shift);

        lock($queueMutex);
        unless ( exists($queue{$file}) ) {
            $queue{$file} = 1;
        }
    }
}

sub getFileToOptimize {
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
