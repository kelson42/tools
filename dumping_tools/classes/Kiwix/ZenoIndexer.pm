package Kiwix::ZenoIndexer;

use strict;
use warnings;
use Data::Dumper;
use File::Find;

my $logger;
my $indexerPath;
my $htmlPath;
my $zenoFilePath;

my @files;

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub exploreHtmlPath {
    my $self = shift;
    find(\&analyzeFile, $self->htmlPath());
}

sub analyzeFile {
    print shift()."\n";
}

sub htmlPath {
    my $self = shift;
    if (@_) { $htmlPath = shift } 
    return $htmlPath;
}

sub zenoFilePath {
    my $self = shift;
    if (@_) { $zenoFilePath = shift } 
    return $zenoFilePath;
}

sub indexerPath {
    my $self = shift;
    if (@_) { $indexerPath = shift } 
    return $indexerPath;
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
