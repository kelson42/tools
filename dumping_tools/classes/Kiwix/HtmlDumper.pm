package Kiwix::HtmlDumper;

use strict;
use warnings;
use Data::Dumper;
use Kiwix::PathExplorer;
use Cwd 'abs_path';

my $logger;
my $mediawikiPath;
my $htmlPath;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub dump {
    my $self = shift;
    my $cmd;

    # remove old 
    $cmd = "rm -rf ".$self->mediawikiPath()."/static/";
    `$cmd`;

    # start PHP dump command
    $cmd = "php ".$self->mediawikiPath()."/extensions/DumpHTML/dumpHTML.php -k kiwixoffline --image-snapshot";
    $self->log("info", $cmd);
    `$cmd`;

    # remove unsed stuf
    $cmd = "rm ".$self->mediawikiPath()."/static/skins/monobook/headbg.jpg" ; `$cmd`;
    $cmd = "rm ".$self->mediawikiPath()."/static/*version" ; `$cmd`;
    $cmd = "rm ".$self->mediawikiPath()."/static/raw/gen.css" ; `$cmd`;
    $cmd = "rm -rf ".$self->mediawikiPath()."/static/misc" ; `$cmd`;
}

sub htmlPath {
    my $self = shift;
    if (@_) { 
	$htmlPath = abs_path(shift) ;
	if (! substr($htmlPath, length($htmlPath)-1) eq "/" ) {
	    $htmlPath = $htmlPath + "/";
	}
    } 
    return $htmlPath;
}

sub mediawikiPath {
    my $self = shift;
    if (@_) { 
	$mediawikiPath = abs_path(shift) ;
	if (! substr($mediawikiPath, length($mediawikiPath)-1) eq "/" ) {
	    $mediawikiPath = $mediawikiPath + "/";
	}
    } 
    return $mediawikiPath;
}

sub logger {
    my $self = shift;
    if (@_) { 
	$logger = shift;
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
