package Kiwix::HtmlDumper;

use strict;
use warnings;
use Data::Dumper;
use HTML::LinkExtractor;
use Kiwix::PathExplorer;
use URI::Escape;
use File::Path qw(mkpath);
use File::Copy;
use Sys::Hostname;
use Socket;

use Cwd 'abs_path';

my $logger;
my $mediawikiPath;
my $htmlPath;
my $restartAtCheckpoint;
my %imgs;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub dump {
    my $self = shift;
    my $cmd;

    # start PHP dump command
    my $checkpointPath = $self->mediawikiPath()."/checkpoint";

    unless ($self->restartAtCheckpoint()) {
	$cmd = "rm -f $checkpointPath"; `$cmd`;

	# remove old 
	$cmd = "rm -rf ".$self->mediawikiPath()."/static/"; `$cmd`;
	$self->log("info", $cmd); `$cmd`;
    }

    do {
	$cmd = "ulimit -v 2000000 ; php ".$self->mediawikiPath()."/extensions/DumpHTML/dumpHTML.php -k kiwixoffline --checkpoint ".$self->mediawikiPath()."/checkpoint";
	$self->log("info", $cmd); `$cmd`;
	
	# Check if process is finished
	my $checkpoint = $self->readFile($checkpointPath);
	if ($$checkpoint =~ /done/i) {
	    $checkpointPath = "";
	    $self->log("info", "php dumping finished");
	} else {
	    # Sleep a little bit
	    sleep(10);
	}
    } while ($checkpointPath);

    # remove unsed stuff
    $self->log("info", "Remove a few unused files...");
    $cmd = "rm ".$self->mediawikiPath()."/static/skins/monobook/headbg.jpg" ; `$cmd`;
    $cmd = "rm ".$self->mediawikiPath()."/static/*version" ; `$cmd`;
    $cmd = "rm ".$self->mediawikiPath()."/static/raw/gen.css" ; `$cmd`;
    $cmd = "rm -rf ".$self->mediawikiPath()."/static/misc" ; `$cmd`;

    # copy the static rep to the destination folder
    $cmd = "rm -rf  ".$self->htmlPath() ;
    $self->log("info", $cmd); `$cmd`;
    $cmd = "cp -rf ".$self->mediawikiPath()."/static/ ".$self->htmlPath()."/" ;
    $self->log("info", $cmd); `$cmd`;

    # mv the 'article' one level deeper
    $cmd = "mkdir ".$self->htmlPath()."/html/" ; `$cmd`;
    $cmd = "mv ".$self->htmlPath()."/articles ".$self->htmlPath()."/html/"  ; `$cmd`;
    $cmd = "mv ".$self->htmlPath()."/index.html ".$self->htmlPath()."/html/"  ; `$cmd`;
    $cmd = "mv ".$self->htmlPath()."/skins ".$self->htmlPath()."/html/"  ; `$cmd`;
    $cmd = "cp -r ".$self->htmlPath()."/raw ".$self->htmlPath()."/html/skins/"  ; `$cmd`;
    $cmd = "mv ".$self->htmlPath()."/raw ".$self->htmlPath()."/html/"  ; `$cmd`;

    my $explorer = new Kiwix::PathExplorer();
    $explorer->path($self->htmlPath());
    $explorer->filterRegexp('^.*html$');

#    my @localAddresses = (Net::Address::IP::Local->public(), "127.0.0.1");
    while (my $file = $explorer->getNext()) {
	$self->log("info", "Analyze images to copy for ".$file);

	# read file
	my $content = $self->readFile($file);

	# Prepare to rewrite the content
	my $newContent = $content;
	my %rews;

	# setup the parser
	my $LX = new HTML::LinkExtractor();
	$LX->strip(1); # just anchor text, not entire tag
	$LX->parse($content);

	# print anchor text and href
	for my $Link (@{$LX->links}) {
	    my $tag = $$Link{tag};

	    # only img links
	    next unless $tag eq 'img';
	    my $src = $$Link{src};
	    my $imgPath = $src;

	    $imgPath =~ s/\.\.\///g;
	    $imgs{$imgPath} = 1;

	    $rews{$src} = $imgPath;
	}

	# Rewrite the file
	foreach my $imgLink (keys(%rews)) {
	    my $rewritedImgLink;
	    if ($file =~ ".*index\.html") {
		$rewritedImgLink = "../".$rews{$imgLink};
	    } else {
		$rewritedImgLink = "../../../../../".$rews{$imgLink};
	    }
	    $$newContent =~ s/\Q$imgLink\E/$rewritedImgLink/g;
	}
	writeFile($file, $newContent);
    }

    $explorer->reset();

    foreach my $img (keys(%imgs)) {
	$img = uri_unescape($img);
	$img =~ /(^.*\/)([^\/]*)$/ ;
	my $dir = $1;

	my $originalPath = $self->mediawikiPath()."/".$img;
	my $destinationPath = $self->htmlPath()."/".$img;
	my $destinationDir = $self->htmlPath()."/".$dir;

	# create the directory if necessary
	unless (-d $destinationDir) {
	    mkpath($destinationDir);
	}

	# copy the image file itself
	copy($originalPath, $destinationPath);
	$self->log("info", "cp \"$originalPath\" \"$destinationPath\"");
    }
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

sub writeFile {
    my $file = shift;
    my $data = shift;

    open (FILE, ">$file") or die "Couldn't open file: $file";
    print FILE $$data;
    close (FILE);
}

sub htmlPath {
    my $self = shift;

    if (@_) {
	$htmlPath = shift;

	# remove the leading / if necessary
	$htmlPath =~ s/(\/$)//;

	# get the absolute path in case of a relative path
	if (! (substr($htmlPath, 0, 1) eq '/') )  { 
	    $htmlPath = abs_path($htmlPath);
	}

	# add a leading /
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

sub restartAtCheckpoint {
    my $self = shift;
    if (@_) {
	$restartAtCheckpoint = shift;
    }
    return $restartAtCheckpoint;
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
