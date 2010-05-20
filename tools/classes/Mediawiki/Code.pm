package MediaWiki::Code;

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use LWP::UserAgent;
use XML::DOM;
use Compress::Zlib;
use HTML::Entities qw(decode_entities);

my $directory;
my $logger;
my $doc;
my $mediawikiRevision = "head";
my @extensions;
my $filter=".*";
my @extensionsToIgnore = ('MakeBot', 'SiteMatrix', 'FixedImage', 'OggHandler', 'BoardVote', 'CentralNotice', 'TorBlock', 'Central.*Auth', 'TitleKey', 'CheckUser', 'Cross.*namespace.*', 'GlobalBlocking', 'Global[ |_]*Usage', 'OAIRepository', 'SimpleAntiSpam', 'SpamBlacklist', 'ConfirmEdit', 'MakeBot', 'AntiBot', 'AntiSpoof', 'Oversight', 'Makesysop', 'Title.*Blacklist', 'DismissableSiteNotice', 'Username.*Blacklist', 'MWSearch', 'OpenSearchXml', 'Renameuser', 'TrustedXFF', 'Collection', 'SecurePoll', 'Abuse[ ]*Filter', 'UsabilityInitiative', 'PDF Handler', 'PrefStats', 'OptIn', 'UploadBlacklist', 'WikimediaMessages', 'NewUserMessage', 'LocalisationUpdate', 'nuke', 'FlaggedRevs', 'UsabilityInitiative' );

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    return $self;
}

sub get {
    my $self = shift;
    my $host = shift || "";
    my $path = shift || "";

    my $url = "http://".$host."/".($path ? $path."/" : "")."index.php?title=Special:Version";
    $self->log("info", "Download Mediawiki version informations from : $url\n");
    my $html = $self->downloadTextFromUrl($url);

    if ("Mediawiki" =~ /$filter/i ) {
	if ($html =~ /<td>.*www\.mediawiki\.org.*<\/td>.*[\s]*.*<td>.*r([\d]+).*<\/td>/m ) {
	    $mediawikiRevision = $1;
	} else {
	    $self->log("warn", "The website does not seems to be a Mediawiki installation.\n");
	}
    }

    while ($html =~ /<td>.*(http.*mediawiki.*xtension:[^\"]+)[^>]+>([^>]+)<\/a>.*[\n]*[\t].*r([\d]+).*<\/td>.*[\n]*[\t]*.*<td>(.*)<\/td>.*[\n]*[\t]*.*<td>(.*)<\/td>/mg ) {
	my %extension;

	$extension{url} = $1;
	$extension{title} = $2;
	$extension{version} = $3 || "head ";
	$extension{description} = $4;
	$extension{author} = $5;

	my $ignoreExtension = 0;

	# check if the extension title match (or not) the filter
	unless ($extension{title} =~ /$filter/i ) {
	    $ignoreExtension = 1;
	}

	# check if the extension is in the ignore list
	foreach my $extensionToIgnore (@extensionsToIgnore) {
	    if ($extension{title} =~ /$extensionToIgnore/i ) {
		$ignoreExtension = 1;
		last;
	    }
	}

	# handle with the $ignoreExtension value
	if ($ignoreExtension) {
	    $self->log("info", "Ignore extension : '".$extension{title}."'\n");
	    next;
	} else {
	    $self->log("info", "Will install extension : '".$extension{title}."'\n");
	}

	$extension{description} =~ s/\<[^>]+\>//g;
	$extension{description} = decode_entities($extension{description});

	my $path = $self->getPathForExtension($extension{url}) || $self->getPathForExtension($extension{url}."/installation");

	my $firstSlash = index($path, "/");
	$extension{path} = substr($path, 0, $firstSlash);
	$extension{file} = substr($path, $firstSlash + 1);

	unless ($extension{path}) {
	    $self->log("error", "Unable to find a path for the extension '".$extension{title}."'");	
	    next;
	}

	push(@extensions, \%extension);
    }

    while ($html =~ /<td>.*(http.*meta\.wikimedia\.org.*wiki\/[^\"]+)[^>]+>([^>]+)<\/a>.* (\d{4}-\d{2}-\d{2}|\d+\.*\d*\.*\d*|r\d+|).*<\/td>.*[\n]*[\t]*.*<td>(.*)<\/td>.*[\n]*[\t]*.*<td>(.*)<\/td>/mg ) {
	my %extension;

	$extension{url} = $1;
	$extension{title} = $2;
	$extension{version} = $3 || "head ";
	$extension{description} = $4;
	$extension{author} = $5;

	# remove MergeAccount
	next if ($extension{title} =~ /MergeAccount/i );

	# parserFunction
	if ($extension{title} =~ /ParserFunctions/i ) {
	    $extension{url} = "http://www.mediawiki.org/wiki/Extension:ParserFunctions"
	}

	$extension{description} =~ s/\<[^>]+\>//g;
	$extension{description} = decode_entities($extension{description});

	my $path = $self->getPathForExtension($extension{url}) || $self->getPathForExtension($extension{url}."/installation");

	my $firstSlash = index($path, "/");
	$extension{path} = substr($path, 0, $firstSlash);
	$extension{file} = substr($path, $firstSlash + 1);

	unless ($extension{path}) {
	    $self->log("error", "Unable to find a path for the extension '".$extension{title}."'");	
	    next;
	}

	push(@extensions, \%extension);
    }
    
    # add dumpHTML
    my %extension;
    $extension{url} = "http://www.mediawiki.org/wiki/Extension:DumpHTML";
    $extension{title} ="DumpHTML";
    $extension{version} = "head ";
    $extension{description} = "To dump HTML pages form a live web mediawiki instance.";
    $extension{author} = "";
    $extension{path} = "DumpHTML";
    $extension{file} = "";
    push(@extensions, \%extension);
    
    return 1;
}

sub php {
    my $self = shift;
    my $php = "";

    foreach my $extension (@extensions) {
	if ($extension->{path} && $extension->{file}) {
	    $php .= "require_once( \"\$IP/extensions/".$extension->{path}."/".$extension->{file}."\" );\n";
	}
    }

    return $php;
}

sub getPathForExtension {
    my $self = shift;
    my $url = shift;

    my $html = $self->downloadTextFromUrl($url);

    my $require_once = "";

    if ($html =~ /(require_once|include).*extensions\/(\S*\.php).*/ ) {
        $require_once = $2;
	$require_once =~ s/\<[^>]+\>//g;
    } 

    return $require_once;
}

sub informations {
    my $self = shift;
    my $action = shift;
    my $informations = "";

    if ("Mediawiki" =~ /$filter/i ) {
	print "[Mediawiki]\n";
	print "revision: $mediawikiRevision\n\n";
    }

    foreach my $extension (@extensions) {
	print "[Extension]\n";
	print "title: ".$extension->{title}."\n";
	print "description: ".$extension->{description}."\n";
	print "url: ".$extension->{url}."\n";
	print "version: ".$extension->{version}."\n";
	print "author: ".$extension->{author}."\n";
	print "path:".$extension->{path}."\n";
	print "\n";
    }
}

sub applyCustomisations {
    # copy the Kiwix skins
    my $cmd = "cp ../data/skins/*.php ".$directory."/skins/";
    `$cmd`;

    # Overwrite the dumpHtml.* extension files
    $cmd = "cp ../data/skins/dumpHTML.* ".$directory."/extension/DumpHTML/";
    `$cmd`;

    # copy and modify Parser.php
    $cmd = "cp $directory/includes/parser/Parser.php $directory/skins/ParserOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/class Parser/class ParserOriginal/' $directory/skins/ParserOriginal.php";
    `$cmd`;

    # copy and modify ImageGallery.php
    $cmd = "cp $directory/includes/ImageGallery.php $directory/skins/ImageGalleryOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/class ImageGallery/class ImageGalleryOriginal/' $directory/skins/ImageGalleryOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/private /protected /' $directory/skins/ImageGalleryOriginal.php";
    `$cmd`;

    # copy and modify title.php
    $cmd = "cp $directory/includes/Title.php $directory/skins/TitleOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/class Title/class TitleOriginal/' $directory/skins/TitleOriginal.php";
    `$cmd`;
    $cmd = "sed -i -e 's/private /protected /' $directory/skins/TitleOriginal.php";
    `$cmd`;

    # compile textvc
    $cmd = "cd $directory/math ; make clean all";
    print $cmd."\n";
    `$cmd`;

    # Set link color to 'black' in the timeline extension
    if ( -f $directory.'/extensions/timeline/EasyTimeline.pl') {
	$cmd = 'sed -i -e \'s/\$LinkColor[ |]=.*$/\$LinkColor = "black";/\' ' . $directory . '/extensions/timeline/EasyTimeline.pl';
	`$cmd`;
    }

    # Make the link for the 'local directory
    $cmd = 'ln -s /var/www/mirror/commons/images/ '.$directory.'/images/shared';
    `$cmd`;

    # Make the link for the 'local' directory
    $cmd = 'ln -s '.$directory.'/images/ '.$directory.'/images/local';
    `$cmd`;

    # todo: check if all extern tools are there
}

sub getSvnCommands {
    my $self = shift;
    my $svnCommands = "";

    if ("Mediawiki" =~ /$filter/i ) {
	$svnCommands .= "svn co -r ".$mediawikiRevision." http://svn.wikimedia.org/svnroot/mediawiki/trunk/phase3 ".$self->directory()."\n";
    }

    foreach my $extension (@extensions) {
	$svnCommands .= "svn co -r ".$extension->{version}." http://svn.wikimedia.org/svnroot/mediawiki/trunk/extensions/".$extension->{path}." ".$self->directory()."/extensions/".$extension->{path}."\n";
    }

    # download in addtion ExtensionFunctions.php
    $svnCommands .= " wget -O ".$self->directory()."/extensions/ExtensionFunctions.php /var/www/mirror/fr/extensions/ExtensionFunctions.php http://svn.wikimedia.org/svnroot/mediawiki/trunk/extensions/ExtensionFunctions.php\n";

    # tidy
    $svnCommands .= "svn co http://svn.wikimedia.org/svnroot/mediawiki/trunk/extensions/tidy ".$self->directory()."/extensions/tidy\n";

    return $svnCommands;
}

sub downloadTextFromUrl {
    my $self = shift;
    my $url = shift;

    my $ua = LWP::UserAgent->new();
    my $response = $ua->get($url);

    my $data = $response->content;
    my $encoding = $response->header('Content-Encoding');

    if ($encoding && $encoding =~ /gzip/i) {
	$data = Compress::Zlib::memGunzip($data);
    }
    
    return $data;
}

sub logger {
    my $self = shift;
    if (@_) { $logger = shift }
    return $logger;
}

sub filter {
    my $self = shift;
    if (@_) { $filter = shift }
    return $filter;
}

sub directory {
    my $self = shift;
    if (@_) { $directory = shift }
    return $directory;
}

sub log {
    my $self = shift;
    return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
