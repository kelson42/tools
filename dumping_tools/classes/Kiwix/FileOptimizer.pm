package Kiwix::FileOptimizer;

use strict;
use warnings;
use Data::Dumper;
use Kiwix::PathExplorer;
use Kiwix::MimeDetector;
use HTML::Clean;
use Whereis;
use Cwd 'abs_path';

my $logger;
my $contentPath;
my $mimeDetector;
my $optPngPath;
my $optGifPath;
my $optJpgPath;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);
    $self->mimeDetector(new Kiwix::MimeDetector());
    $self->optPngPath(whereis("opt-png"));
    $self->optGifPath(whereis("opt-gif"));
    $self->optJpgPath(whereis("opt-jpg"));

    return $self;
}

sub optimize {
    my $self = shift;
    
    unless ($self->contentPath) {
	$self->log("error", "You have to give a path to explore to search files to be optmized.");
	return;
    }

    my $explorer = new Kiwix::PathExplorer();
    $explorer->path($self->contentPath());
    while (my $file = $explorer->getNext()) {
	$self->optimizeFile($file);
    }
}

sub optimizeFile {
    my $self = shift;
    my $file = shift;

    if ($file) {
	$self->log("info", "Optimizing $file.");
    }
    else {
	$self->log("error", "You have to specify a file to optimize.");
	return;
    }

    my $mimeType = $self->mimeDetector()->getMimeType($file);
    
    if ($mimeType eq "text/html") {
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
}

sub optimizePng {
    my $self = shift;
    my $file = shift;
    
    my $bin = $self->optPngPath();
    
    `$bin $file`;
}

sub optimizeGif {
    my $self = shift;
    my $file = shift;
    
    my $bin = $self->optGifPath();
    
    `$bin $file`;
}

sub optimizeJpg {
    my $self = shift;
    my $file = shift;
    
    my $bin = $self->optJpgPath();
    
    `$bin $file`;
}

sub optimizeHtml {
    my $self = shift;
    my $file = shift;

    my $data = $self->readFile($file);
    my $cleaner = new HTML::Clean($data);

    if ($cleaner) {

	# remove longdesc attributes
	$$data =~ s/longdesc=\"[^\"]*\"//ig;

	# remove the nofollow
	$$data =~ s/rel=\"nofollow\"//ig;

	# remove titles
	$$data =~ s/title=\"[^\"]*\"//ig;

	# remove spaces
	$$data =~ s/[ ]+\/>/\/>/ig;

	if ($$data =~ /\<pre\>/i ) {
	    $cleaner->strip( {whitespace => 0} );
	} else {
	    $cleaner->strip();
	}

	$self->writeFile($file, $cleaner->data());
    }
    
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
    if (@_) {
	$contentPath = abs_path(shift) ;
	if (! substr($contentPath, length($contentPath)-1) eq "/" ) {
            $contentPath = $contentPath + "/";
	}
    }
    return $contentPath;
}

sub mimeDetector {
    my $self = shift;
    if (@_) { $mimeDetector = shift }
    return $mimeDetector;
}

sub optPngPath {
    my $self = shift;
    if (@_) { $optPngPath = shift }
    return $optPngPath;
}

sub optJpgPath {
    my $self = shift;
    if (@_) { $optJpgPath = shift }
    return $optJpgPath;
}

sub optGifPath {
    my $self = shift;
    if (@_) { $optGifPath = shift }
    return $optGifPath;
}

# loggin
sub logger {
    my $self = shift;
    if (@_) { 
	$logger = shift ;
	$self->mimeDetector->logger($logger);
    }
    return $logger;
}

sub log {
    my $self = shift;
    return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
