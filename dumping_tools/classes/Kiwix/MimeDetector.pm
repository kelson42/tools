package Kiwix::MimeDetector;

use strict;
use warnings;
use MIME::Types;
use Data::Dumper;

my MIME::Types $types = MIME::Types->new;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    $types->addType( MIME::Type->new(type=>'image/svg+xml', extensions=>['svg']) );

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
	print "Unable to determine type of $file\n";
    }
}

1;
