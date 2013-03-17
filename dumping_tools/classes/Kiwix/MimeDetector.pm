package Kiwix::MimeDetector;

use strict;
use warnings;
use MIME::Types;
use Data::Dumper;

my $logger;

my MIME::Types $types = MIME::Types->new;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    $types->addType( MIME::Type->new(type=>'application/epub+zip', extensions=>['epub']) );
    $types->addType( MIME::Type->new(type=>'image/svg+xml', extensions=>['svg']) );
    $types->addType( MIME::Type->new(type=>'application/x-bittorrent', extensions=>['torrent']) );

    return $self;
}

sub getMimeType {
    my $self = shift;
    my $file = shift;
    my MIME::Type $mime = $types->mimeTypeOf($file);
    if ($mime) {
	return $mime->type();
    }
    else {
	if (-d $file) {
	    $self->log("info", "$file is a directory");
	} else {
	    $self->log("error", "Unable to determine type of $file.");
	} 
    }
}

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
