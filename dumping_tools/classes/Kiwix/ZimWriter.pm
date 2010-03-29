package Kiwix::ZimWriter;

use strict;
use warnings;
use Data::Dumper;
use Kiwix::PathExplorer;
use Kiwix::MimeDetector;
use Kiwix::UrlRewriter;
use HTML::LinkExtractor;
use Text::Unaccent;
use HTML::Entities;
use URI::Escape;
use Math::BaseArith;
use DBI qw(:sql_types);
use Cwd 'abs_path';
use DBD::Pg;

my $logger;
my $writerPath;
my $htmlPath;
my $welcomePage;
my $zimFilePath;
my $dbHandler;
my $dbName;
my $dbUser;
my $dbPassword;
my $dbPort = "5433";
my $dbHost = "localhost";
my $mediawikiOptim;
my %urls;
my %deadUrls;
my @files;
my $file;
my $htmlFilterRegexp = "^.*\.(html|htm)\$";
my $jsFilterRegexp = "^.*\.(js)\$";
my $cssFilterRegexp = "^.*\.(css)\$";
my $rewriteCDATA;
my $shortenUrls;
my $strict;
my $avoidForceHtmlCharsetToUtf8;

my %bestResolutionSizes;
my %bestResolutionUrls;
my %bestResolutionRedirects;
my %additionalKeywords;

my $mimeDetector;

my %mimeTypes = (
    "text/html" => 0,
    "text/plain" => 1,
    "image/jpeg" => 2,
    "image/png" => 3,
    "image/tiff" => 4,
    "text/css" => 5,
    "image/gif" => 6,
    "application/javascript" => 8,
    "image/icon" => 9,
    "application/pdf" => 10,
    "application/x-bittorrent" => 11,
    "application/x-shockwave-flash" => 12,
    "image/vnd.microsoft.icon" => 13,
    "application/zip" => 14,
    "image/svg+xml" => 15,
    "audio/x-wav" => 16,
    "application/vnd.ms-powerpoint" => 17
    );

my %mimeTypesCompression = (
    "text/html" => 1,
    "text/plain" => 1,
    "image/jpeg" => 0,
    "image/png" => 0,
    "image/tiff" => 1,
    "text/css" => 1,
    "image/gif" => 0,
    "application/javascript" => 1,
    "image/icon" => 0,
    "application/pdf" => 1,
    "application/x-bittorrent" => 0,
    "application/x-shockwave-flash" => 0,
    "image/vnd.microsoft.icon" => 0,
    "application/zip" => 0,
    "image/svg+xml" => 1,
    "audio/x-wav" => 0,
    "application/vnd.ms-powerpoint" => 1
    );

sub new {
    my $class = shift;
    my $self = {};

    bless($self, $class);

    $self->mimeDetector(new Kiwix::MimeDetector());

    return $self;
}

sub prepareUrlRewriting {
    my $self = shift;
    $self->getUrls();
    $self->getUrlCounts();
    $self->checkDeadUrls();
    $self->computeNewUrls();
}

sub getUrls {
    my $self = shift;

    $self->log("info", "Listing all files in the HTML path ".$self->htmlPath());
    my $explorer = new Kiwix::PathExplorer();
    $explorer->path($self->htmlPath());

    while (my $file = $explorer->getNext()) {
	unless ($self->ignoreFile($file)) {
	    $self->incrementCount( substr($file, length($htmlPath)) );
	}
    }
}

sub getUrlCounts {
    my $self = shift;

    foreach my $file (keys(%urls)) {

	# deal with the css
	if ($file =~ /$cssFilterRegexp/i) {
	    $file = $self->htmlPath().$file;
	    my $data = $self->readFile($file);
	    while ($data =~ /url\([\"\']*(.*\.)(png|gif|jpg|jpeg)[\"\']*\)/gm) {
		my $url = $1.$2;
		if ($url =~ /\:\/\// ) {
		    $self->log("warn", "There is an CSS online picture dependence in ".$file);
		} else {
		    $self->incrementCount( getAbsoluteUrl($file, $self->htmlPath(), $url));
		}
	    }
	    
	    next;
	}

	# only html
	unless ($file =~ /$htmlFilterRegexp/i ) {
	    next;
	}

	$self->log("info", "Count links in the (x)html file ".$file);

	# add html path
	$file = $self->htmlPath().$file;
	
	# Parse the file
	my $linkExtractor = HTML::LinkExtractor->new();
	$linkExtractor->parse($file);
	my $links = $linkExtractor->links();

	# Read file
	my $data = $self->readFile($file);

	# CDATA links
	if ($self->rewriteCDATA) {
	    while ($data =~ /\@import\ \"([^\"]+)\"/gm) {
		push(@$links, {"src"=>$1, "tag"=>"CDATA"} );
	    }
	}

	# Analyze the links
	foreach my $link (@$links) {
	    # Exceptions
	    if ($link->{'tag'} =~ /meta/i || $link->{'tag'} =~ /form/i ) {
		next;
	    }

	    # Get the url
	    my $url = $link->{'href'} || $link->{'src'} || $link->{'codebase'} || $link->{'background'};

	    unless ($url) {
		next;
	    }
	    
	    if (!$url && $strict) {
		print $strict."\n";
		print "Not able to analyze in $file following link:\n";
		print Dumper($link);
		exit;
	    };

	    # normal link
	    if (isLocalUrl($url) && !isSelfUrl($url)) {
		$url = removeLocalTagFromUrl($url);
		$url =~ s/\n//g;
		$url =~ s/(\?.*$)//;
		$url = uri_unescape($url);
		$self->incrementCount(getAbsoluteUrl($file, $self->htmlPath(), $url));
	    } 

	    # refresh/redirect link
	    elsif (exists($link->{'http-equiv'}) && $link->{'http-equiv'} =~ /Refresh/i) {
		if ($link->{'content'} =~ /url\=(.*)/) {
		    my $target = $1;
		    $target = removeLocalTagFromUrl($target);
		    $target =~ s/\n//g;
		    $target = uri_unescape($target);
		    $target = getAbsoluteUrl($file, $self->htmlPath(), $target);
		    if ($data =~ /<title>(.*)<\/title>/i ) {
			my $title = decode_entities($1);
			if ($title) {
			    $additionalKeywords{$target} = ($additionalKeywords{$target} ? $additionalKeywords{$target}.", " : "").$title;
			    $self->log("info", "New 'redirect keyword' for '$target' : '$title'");
			}
		    }
		}
	    }
	}
    }

    $self->log("info", "Finished with counting links.");
    
    # remove unused redirects
    $self->log("info", "Removing unused redirects...");
    foreach my $file (keys(%urls)) {
	if ($urls{$file} <= 1 && 
	    $file =~ /$htmlFilterRegexp/i && 
	    -f $self->htmlPath().$file) {

	    $self->log("info", "Removing unused redirects... looking at $file");

	    # read file
	    my $path = $self->htmlPath().$file;
	    my $data = $self->readFile($path);

	    # is redirect?
	    my $linkExtractor = HTML::LinkExtractor->new();
	    $linkExtractor->parse(\$data);
	    my $links = $linkExtractor->links();
	    foreach my $link (@$links) {
		next unless (exists($link->{'http-equiv'}) && $link->{'http-equiv'} =~ /Refresh/i );
		$self->log("info", "Removing redirect $file.");
		delete($urls{$file});
		last;
	    }
	}
    }
    $self->log("info", "Finished with removing unused redirects.");
}

sub mediawikiOptim {
    my $self = shift;
    if (@_) { $mediawikiOptim = shift }
    return $mediawikiOptim;
}

sub checkDeadUrls {
    my $self = shift;

    $self->log("info", "Checking dead urls...");
    foreach my $url (keys(%urls)) {
	unless (-f $self->htmlPath().$url) {
	    $self->log("error", "[".$self->htmlPath()."]".$url." is a dead url. It should be removed.");
	    $deadUrls{$url} = 1;
	}
    }

    $self->log("info", "Removing deadUrl from %urls...");
    foreach my $url (keys(%deadUrls)) {
	delete($urls{$url});
    }
}

sub computeNewUrls {
    my $self = shift;
    
    # Special code to user only one resolution of a picutre in case of a Mediawiki HTML dump
    my $normalImageFakeSize = 424242;
    my $imageRegex = '^.*\/([\d]+px\-|)([^\/]*)\.(png|jpg|jpeg)$';
    if ($self->mediawikiOptim()) {
	
	# Get the best resolution for each picture
	foreach my $url (keys(%urls)) {
	    if ($url =~ /$imageRegex/i) {
		my $size = $1 || $normalImageFakeSize;
		my $filename = $2.".".$3;
		$size =~ s/px\-//g;
		
		if (exists($bestResolutionSizes{$filename})) {
		    if ($bestResolutionSizes{$filename} < $size) {
			$bestResolutionSizes{$filename} = $size;
			$bestResolutionUrls{$filename} = $url;
		    }
		} else {
		    $bestResolutionSizes{$filename} = $size;
		    $bestResolutionUrls{$filename} = $url;
		}
	    }
	}

	# Remove low resolution picture urls
	foreach my $url (keys(%urls)) {
	    if ($url =~ /$imageRegex/i) {
		my $size = $1 || $normalImageFakeSize;
		my $filename = $2.".".$3;
		$size =~ s/px\-//g;
		
		if ($size < $bestResolutionSizes{$filename}) {
		    
		    # increment the url count of the best picture
		    $urls{ $bestResolutionUrls{$filename} } += $urls{$url};
		    
		    # create the redirection
		    $bestResolutionRedirects{$url} = $bestResolutionUrls{$filename};

		    # delete the hash entry
		    delete($urls{$url});

		    $self->log("info", "Optim url ".$url." -> ".$bestResolutionUrls{$filename});
		}
	    }
	}
    }

    # Sort urls
    my @urls = keys(%urls);
    $self->log("info", "Sorting ".scalar(@urls)." urls.");
    my @sortedUrls = sort { $urls{$b} <=> $urls{$a} } (@urls);

    if ($self->shortenUrls()) {
	# new url base
	my $baseString = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
	my $baseSize = length($baseString);
	
	my @baseString;
	for (my $i=0; $i<$baseSize; $i++) {
	    push(@baseString, substr($baseString, $i, 1));
	}
	
	my @base;
	for (my $i=0; $i<$baseSize; $i++) {
	    push(@base, $baseSize);
	}
	
	# compute the new url
	$self->log("info", "Computing new urls.");
	my $nameIndex=0;
	foreach my $url (@sortedUrls) {
	    my @newUrl = encode( $nameIndex, \@base );
	    my $newUrl = "";
	    my $trail = 1;
	    
	    foreach (@newUrl) {
		if ($trail) {
		    if ($_ == 0) {
			next;
		    } else {
			$trail = 0;
		    }
		}
		
		$newUrl .= $baseString[$_];
	    }
	    
	    if ($newUrl eq "") {
		$newUrl = $baseString[0];
	    }
	    
	    $urls{$url} = $newUrl;
	    $nameIndex++;
	}
    } else {
	my %newUrlsReverse;

	# compute the new url
	$self->log("info", "Computing new urls.");

	foreach my $url (@sortedUrls) {
	    my $newUrlBase;
	    my $newUrl;
	    my $file = $self->htmlPath().$url;
	    my $extension;

	    # only html
	    if ($url =~ /$htmlFilterRegexp/i) {
		#data
		my $data = $self->readFile($file);
		
		if ($data =~ /<title>(.*)<\/title>/i ) {
		    $newUrlBase = decode_entities($1);
		}
		$extension=".html";
		
	    }

	    # else
	    unless ($newUrlBase) {
		$url =~ /^(.*\/|)([^\/]*)(\..*)$/;
		$newUrlBase = $2;
		$extension=$3;
	    }
	
	    #$newUrlBase = unac_string("UTF8", $newUrlBase) || $newUrlBase;
	    #$newUrlBase =~ s/ /_/g;
	    #$newUrlBase =~ s/[^a-z0-9_]/_/ig;
	    $newUrlBase =~ s/[_]+/_/ig;
	    $newUrl = $newUrlBase.$extension;

	    unless ($newUrl) {
		print "Unable to compute new url for url $url in $file.\n";
		exit;
	    }

	    # check if there is not a collision with the new url
	    if (exists($newUrlsReverse{$newUrl}) && !($newUrlsReverse{$newUrl} eq $url)) {
		my $inc = 0;
		do {
		    $newUrl = $newUrlBase."_".$inc++.$extension;
		} while (exists($newUrlsReverse{$newUrl}) && !($newUrlsReverse{$newUrl} eq $url));
	    }

	    # set the value in 
	    $newUrlsReverse{$newUrl} = $url;

	    $urls{$url} = $newUrl;
	}
	
    }

    # re-add low resolution picture to %urls if necessary
    if ($self->mediawikiOptim()) {
	foreach my $url (keys(%bestResolutionRedirects)) {
	    $urls{$url} = $urls{ $bestResolutionRedirects{$url} };
	}
    }

    # update the welcome page
    if (exists($urls{$welcomePage})) {
	$welcomePage = $urls{$welcomePage};
    } else {
	$self->log("error", "Unable to find the welcome page '$welcomePage'.");
    }
}

sub getNamespace {
    my $file = shift;

    if ($file =~ /$htmlFilterRegexp/i) {
	return "A";
    } elsif ($file =~ /$cssFilterRegexp/i || $file =~ /$jsFilterRegexp/i) {
	return "I";
    } else {
	return "I";
    }
}

sub getAbsoluteUrl {
    my $file = shift;
    my $path = shift;
    my $url = shift;
    my $i;

    if ( $url =~ /^\/.*$/ ) {
	$url =~ s/^\///;
	return $url;
    }

    $file = substr($file, length($htmlPath) );
    $url =~ s/^\.\///mg ;
    $url =~ s/\/\///mg ;
    
    my @fileParts = split(/\//, $file);
    my @urlParts = split(/\//, $url);
    
    my $offset = scalar(@fileParts) - 1;

    $i = 0;
    while ($i < scalar(@urlParts) && $urlParts[$i++] eq "..") {
	$offset -= 1;
    }

    my $newUrl = "";
    for ($i=0; $i<$offset; $i++) {
	$newUrl .= $fileParts[$i] . "/";
    }

    for ($i=0; $i<scalar(@urlParts); $i++) {
	unless ($urlParts[$i] eq ".." ) {
	    $newUrl .= $urlParts[$i];

	    if ($i < scalar(@urlParts) - 1) {
		$newUrl .=  "/";
	    }
	}
    }
    
    return $newUrl;
}

sub incrementCount {
    my $self = shift;
    my $url = shift;

    if (exists($urls{$url})) {
	$urls{$url} += 1;
    } else {
	$urls{$url} = 1;
    }
}

sub isLocalUrl {
    my $url = shift;
    $url =~ /^[\w]{1,15}\:(\/\/|).*$/ ? 0 : 1 ;
}

sub removeLocalTagFromUrl {
    my $url = shift;
    $url =~ s/(\#.*)$// ;
    return $url;
}

sub isSelfUrl {
    my $url = shift;
    $url =~ /^\#.*$/ ? 1 : 0 ;
}

sub fillDb {
    my $self = shift;

    foreach my $url (keys(%urls)) {
	if (-f $self->htmlPath().$url && !exists($bestResolutionRedirects{$url})) {
	    $self->copyFileToDb($url);
	}
    }
}

sub buildZimFile {
    my $self = shift;
    my $dbName = $self->dbName();
    my $writerPath = $self->writerPath();
    my $zimFilePath = $self->zimFilePath();
    my $command = "$writerPath -s 1024 --db \"postgresql:dbname=$dbName user=kiwix port=$dbPort\" $zimFilePath";

    # call the zim writer
    $self->log("info", "Creating the zim file : $command");
    `$command`;
}

sub executeSql {
    my $self = shift;
    my $sql = shift;
    
    $self->dbHandler()->do($sql);
    if ($self->dbHandler()->err()) { die "$DBI::errstr\n"; }
}

# create database
sub createDb {
    my $self = shift;
    my $dbName = $self->dbName();
    my $dbUser = $self->dbUser();

    $ENV{'PGPASSWORD'} = $self->dbPassword();
    `createdb -U $dbUser $dbName `;
    `cat zim-postgresql.sql | psql -U $dbUser -d $dbName`;
}

# delete database
sub deleteDb {
    my $self = shift;
    my $dbName = $self->dbName();
    my $dbUser = $self->dbUser();
    $ENV{'PGPASSWORD'} = $self->dbPassword();
    `dropdb -U $dbUser $dbName`;
}

# connect to database
sub connectToDb {
    my $self = shift;
    my $dbName = $self->dbName();

    $self->dbHandler(DBI->connect("dbi:Pg:dbname=".$dbName.";host=".$dbHost.";port=".$dbPort, $self->dbUser(), $self->dbPassword(), {AutoCommit => 1, PrintError => 1}));

    # set unicode flag
    if ($self->dbHandler()) {
	$self->dbHandler()->{unicode} = 1;
	return 1;
    }
}

sub buildDatabase {
    my $self = shift;
    my $dbName = $self->dbName();

    $self->log("info", "Will create and fill the database '".$dbName."'.");

    # create database
    $self->createDb();

    # connect to the db
    unless ($self->connectToDb()) {
	$self->log("error", "Unable to connect to the database.");
	return;
    } 

    # create db schema
    #$self->createDbSchema();

    # fill the mimetype table
    foreach my $mimeType (keys(%mimeTypes)) {
	my $mimeTypeCode = $mimeTypes{$mimeType};
	my $mimeTypeCompression = $mimeTypesCompression{$mimeType};

	if ($mimeType eq "text/html" && !$self->avoidForceHtmlCharsetToUtf8()) {
	    $mimeType = "text/html; charset=utf-8";
	}

	$self->executeSql("insert into mimetype (id, mimetype, compress) values ('".$mimeTypeCode."', '".$mimeType."', '".($mimeTypeCompression ? "true"  : "false")."')");
    }

    # fill the article table
    $self->fillDb();

    # Fill with the mainpage
    $self->log("info", "Fill with the main page.");
    my $sth = $self->dbHandler()->prepare("select aid from article where namespace='A' and url='$welcomePage'");
    $sth->execute();
    my $result = $sth->fetchrow_hashref();
    $welcomePage = $result->{'aid'};
    $sth->finish();

    # fill the zimfile table
    $self->log("info", "Fill the zimfile table.");
    $self->executeSql("insert into zimfile (filename, mainpage) values ('".$self->zimFilePath()."', '".$welcomePage."')");

    # fill the zimarticle table
    $self->log("info", "Fill the zimarticle table.");
    $self->executeSql("insert into zimarticle (zid, aid) select 1, aid from article");

    # commit und disconnect
    $self->dbHandler()->disconnect();
    $self->log("info", "Have finished to build & fill the database.");
}

sub copyFileToDb {
    my $self = shift;
    $file = shift;

    # url
    my %hash;
    $hash{url} = $urls{$file};
    
    #data
    $file = $self->htmlPath().$file;
    my $data = $self->readFile($file);

    # mime-type
    $hash{mimetype} = $self->mimeDetector()->getMimeType($file);
    if (!exists($mimeTypes{$hash{mimetype}}) || !exists($mimeTypesCompression{$hash{mimetype}})) {
	print $hash{mimetype}.", mime-type from '".$file."' is not known...\n";
	exit;
    }

    # namespace
    $hash{namespace} = getNamespace($file);
    
    # title
    if ($hash{mimetype} =~ /text\/html/ ) {
	if ($data =~ /<title>(.*)<\/title>/mi ) {
	    $hash{title} = $1;
	}
    }

    if (!$hash{title}) {
	$hash{title} = $hash{url};
    }

    # url rewrite callback
    sub urlRewriterCallback {
	my $url = shift;
	$url = uri_unescape($url);

	if ($url && isLocalUrl($url) && !isSelfUrl($url)) {
	    my $absUrl;

	    # remove parameter if necessary
	    $url =~ s/(\?.*$)//;
	    $url =~ s/\n//g;

	    if ($url =~ /\#/ ) {
		$absUrl = getAbsoluteUrl($file, $htmlPath, removeLocalTagFromUrl($url));
	    } else  {
		$absUrl = getAbsoluteUrl($file, $htmlPath, $url);
	    }
	    
	    # check if all is OK with this url
	    if ($strict && !getNamespace($absUrl) && !exists($deadUrls{$absUrl})) {
		print "Unable to get namesapce for url $absUrl in $file and this is not a dead url.\n";
		exit;
	    }
	    
	    my $newUrl = "";
	    if (!exists($urls{$absUrl})) {
		if ($strict && !exists($deadUrls{$absUrl})) {
		    print "Unable to get new url for url $absUrl in $file nd this is not a dead url.\n";
		    exit;
		}
	    } else {
		# compute the new url
		$newUrl = "/".getNamespace($absUrl)."/".$urls{$absUrl};
		
		# Add the local anchor if necessary
		if ($url =~ /\#/) {
		    my @urlParts = split( /\#/, $url );
		    $newUrl .= "#".$urlParts[1];
                }
            }		
	    
	    return $newUrl;
       } else {
	   return $url;
       }
    }
    
    # redirect
    my $linkExtractor = HTML::LinkExtractor->new();
    $linkExtractor->parse(\$data);
    my $links = $linkExtractor->links();
    foreach my $link (@$links) {
	next unless (exists($link->{'http-equiv'}) && $link->{'http-equiv'} =~ /Refresh/i );
	my $target = urlRewriterCallback($link->{'url'});
	$target =~ s/\/.\/// ;
	$hash{redirect} = $target;
	last;
    }

    # rewriting (for HTML)
    if (!$hash{redirect} && $hash{mimetype} =~ /text\/html/ && scalar(%urls)) {
	$self->log("info", "Rewriting url in ".$file);
	
	my $rewriter = new Kiwix::UrlRewriter(\&urlRewriterCallback);
	$data = $rewriter->resolve($data);
	
	# CDATA rewriting
	if ($self->rewriteCDATA()) {
	    my %links;
	    
	    # Get links to rewrite
	    while ($data =~ /\@import\ \"([^\"]+)\"/gm) {
		$links{$1} = 1;
	    }
	    
	    # Rewrite them
	    foreach my $link (keys(%links)) {
		my $newLink = urlRewriterCallback($link);
		$link = quotemeta($link);
		$data =~ s/$link/$newLink/g;
	    }
	}
    }

    # data
    if (!$hash{redirect}) {

	# if necessary deal with additional keywords
	if ($hash{mimetype} =~ /text\/html/ && exists($additionalKeywords{substr($file, length($htmlPath))})) {
	    if ($data =~ /(<meta[ ]+name=[\"|\']{1}keywords[\"|\']{1}[ ]+content=[\"|\']{1}.*)([\"|\']{1})/i ) {
		my $replacement = $1."\, \Q".$additionalKeywords{substr($file, length($htmlPath))}."\E".$2;
		$data =~ s/<meta[ ]+name=[\"|\']{1}keywords[\"|\']{1}[ ]+content=[\"|\']{1}.*[\"|\']{1}/$replacement/i;
		$self->log("info", "Put following additional keywords to '".substr($file, length($htmlPath))."': '".$additionalKeywords{substr($file, length($htmlPath))}."'");
	    } else {

		my $replacement = "<head><meta name=\"keywords\" content=\"\Q".$additionalKeywords{substr($file, length($htmlPath))}."\E\"\ \/>";
		$data =~ s/<head>/$replacement/i;
		$self->log("info", "Creating additional keywords to '".substr($file, length($htmlPath))."': '".$additionalKeywords{substr($file, length($htmlPath))}."'");		
	    }
	}

	# deal with CSS pictures
	if ($hash{mimetype} eq "text/css") {
	    my $newData = $data;
	    while ($data =~ /url\([\"\']*(.*\.)(png|gif|jpg|jpeg)[\"\']*\)/gm) {
		my $url = $1.$2;
		unless ($url =~ /\:\/\// ) {
		    my $absUrl = getAbsoluteUrl($file, $htmlPath, $url);
		    if ($urls{$absUrl}) {
			my $newUrl = "/".getNamespace($absUrl)."/".$urls{$absUrl};
			$newData =~ s/\Q$url\E/$newUrl/i;
		    }
		}
	    }
	    $data = $newData;
	}

	$hash{data} = $data;
    }

    $self->log("info", "Adding to DB ".$file);
    my $sql = "insert into article (namespace, title, url, redirect, mimetype, data) values (?, ?, ?, ?, ?, ?)";
    my $sth = $self->dbHandler()->prepare($sql);

    # check empty data for non redirect articles
    if (!$hash{redirect} && !$hash{data}) {
	$self->log("info", "'".$file."' is an empty file, will be skiped.");
	return;
    }

    # if no predefined mimetype
    return unless (defined($mimeTypes{ $hash{mimetype} }));

    $sth->bind_param(1, $hash{namespace});
    $sth->bind_param(2, $hash{title});
    $sth->bind_param(3, $hash{url});
    $sth->bind_param(4, $hash{redirect});
    $sth->bind_param(5, $mimeTypes{ $hash{mimetype} });
    
    $sth->bind_param(6, $hash{data}, { pg_type => DBD::Pg::PG_BYTEA } );

    $sth->execute();
    if ($self->dbHandler()->err()) { die "$DBI::errstr\n"; }
    
    return \%hash;
}

sub removeUnwantedFiles {
    my $self = shift;
    my @selectedFiles;
    foreach my $file (@files) {
	unless ($self->ignoreFile($file)) {
	    push(@selectedFiles, $file);
	}
    }
    @files = @selectedFiles;
}

sub ignoreFile {
    my $self = shift;
    my $file = shift;

    if ( $file =~ /^.*\.htm$/i || $file =~ /^.*\.html$/i || 
	 $file =~ /^.*\.jpeg$/i || $file =~ /^.*\.jpg$/i ||
	 $file =~ /^.*\.png$/i || $file =~ /^.*\.css$/i ||
	 $file =~ /^.*\.svg$/i || $file =~ /^.*\.js$/i || $file =~ /^.*\.gif$/i
	 ) 
    {
	return 0;
    }

    return 1;
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

    return $data;
}

sub htmlPath {
    my $self = shift;
    if (@_) { 
	$htmlPath = abs_path(shift) ;
	if (! (substr($htmlPath, length($htmlPath)-1) eq "/" )) {
	    $htmlPath .= "/";
	}
    } 
    return $htmlPath;
}

sub zimFilePath {
    my $self = shift;
    if (@_) { $zimFilePath = shift } 
    return $zimFilePath;
}

sub dbName {
    my $self = shift;
    if (@_) { $dbName = shift } 
    return $dbName;
}

sub dbHost {
    my $self = shift;
    if (@_) { $dbHost = shift } 
    return $dbHost;
}

sub dbPort {
    my $self = shift;
    if (@_) { $dbPort = shift } 
    return $dbPort;
}

sub dbHandler {
    my $self = shift;
    if (@_) { $dbHandler = shift } 
    return $dbHandler;
}

sub rewriteCDATA {
    my $self = shift;
    if (@_) { $rewriteCDATA = shift } 
    return $rewriteCDATA;
}

sub avoidForceHtmlCharsetToUtf8 {
    my $self = shift;
    if (@_) { $avoidForceHtmlCharsetToUtf8 = shift; }
    return $avoidForceHtmlCharsetToUtf8;
}

sub strict {
    my $self = shift;
    if (@_) { $strict = shift } 
    return $strict;
}

sub shortenUrls {
    my $self = shift;
    if (@_) { $shortenUrls = shift } 
    return $shortenUrls;
}

sub dbUser {
    my $self = shift;
    if (@_) { $dbUser = shift } 
    return $dbUser;
}

sub dbPassword {
    my $self = shift;
    if (@_) { $dbPassword = shift } 
    return $dbPassword;
}

sub writerPath {
    my $self = shift;
    if (@_) { $writerPath = shift } 
    return $writerPath;
}

sub welcomePage {
    my $self = shift;
    if (@_) { $welcomePage = shift } 
    return $welcomePage;
}

sub logger {
    my $self = shift;
    if (@_) { 
	$logger = shift;
	$self->mimeDetector->logger($logger);
    } 
    return $logger;
}

sub mimeDetector {
    my $self = shift;
    if (@_) { $mimeDetector = shift } 
    return $mimeDetector;
}

sub log {
    my $self = shift; 
    return unless $logger;
    my ($method, $text) = @_;
    $logger->$method($text);
}

1;
