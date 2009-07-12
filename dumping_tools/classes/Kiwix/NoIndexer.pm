package Kiwix::NoIndexer;

use strict;
use warnings;
use Data::Dumper;

my $logger;
my @files;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);
    return $self;
}

sub files {
    my $self = shift;
    @files = @_;
}

sub apply {
    my $self = shift;

    foreach my $file (@files) {
	my $data = $self->readFile($file);

	# add the meta tag
	if ($$data =~ /CONTENT\=\"[^\"]*NOINDEX[^\"]*\"/i) {
	    $self->log("info", "Already a noindex meta tag in $file");
	} else {
	    $self->log("info", "Add the noindex meta tag to $file");
	    $$data =~ s/<head>/<head><meta name="ROBOTS" content="NOINDEX"\/>/i;
	}
  
	$self->writeFile($file, $data);
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

# loggin
sub logger {
    my $self = shift;
    if (@_) { 
	$logger = shift ;
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
