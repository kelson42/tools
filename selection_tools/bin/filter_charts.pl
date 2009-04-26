#!/usr/bin/perl
binmode STDOUT, ":utf8";
binmode STDIN, ":utf8";
binmode STDERR, ":utf8";

use utf8;
use lib '../../mirroring_tools/Mediawiki/';

use Encode;
use PerlIO::gzip;
use URI::Escape;
use Data::Dumper;
use MediaWiki;

my $language = shift(@ARGV);

# get the namespace in english
my $enSite = MediaWiki->new();
$enSite->hostname("en.wikipedia.org");
$enSite->path("w");
my %enNamespaces = $enSite->allNamespaces();

# get the namespace in the language
my $langSite = MediaWiki->new();
$langSite->hostname("$language.wikipedia.org");
$langSite->path("w");
my %langNamespaces = $langSite->allNamespaces();

#print STDERR Dumper(%langNamespaces);

my $regex = "^(";
foreach my $code (keys(%langNamespaces)) {
    next unless ($code);
    $regex .= "(".$langNamespaces{$code}.":)|";
}
foreach my $code (keys(%enNamespaces)) {
    next unless ($code);
    $regex .= "(".$enNamespaces{$code}.":)|";
}
$regex .= "(Http:)|(WP:)|(Image:)|(Imagen:)|([0-9]+px))";

foreach $file ( @ARGV ) { 
  open IN, "<:gzip", $file or die;

  $file =~ m/(\d+)/;
  $date = $1;  

  print STDERR $file .":";
 
  $i = 0;
  while ( $line = <IN> ) {

    $i++;
    if ( $i % 100000 == 0) { print STDERR "."; }

    # Keep only entries for your language
    next unless ( $line =~ /^$language /);

    @parts = split / /, $line;
    if ( defined $parts[5] ) { 
      print STDERR "\nBAD $parts[0] $parts[1]\n$line";
    }
    $name = $parts[1];
    $count = $parts[2];

    # Decode URL
    $name =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
    
    unless (Encode::is_utf8($name)) {
	$name = decode_utf8($name);
    }

    next if ( $name =~ /\n/);

    $name =~ s/^://;
  
    $name = ucfirst($name);

    $name =~ s/ /_/g;
    $name =~ s/#.*//;
    next if ( length $name > 255);

    next if ($name =~ /^$regex/);
    
#   print STDERR $name."\n";

    # These are ad hoc exceptions based on examination of the data
    next if ($name =~ /Wikipedia.*the.*free.*encyclopedia/);
    next if ($name =~ /files.*css/);
    next if ($name =~ /files\//);
 
    print STDOUT "$date $count $name\n";
  }

  print STDERR " $i\n";
}

