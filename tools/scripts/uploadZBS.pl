#!/usr/bin/perl
use lib '../classes/';
use lib '../../dumping_tools/classes/';

use utf8;
use strict;
use warnings;
use DBI;
use Getopt::Long;
use Data::Dumper;
use Mediawiki::Mediawiki;
use HTML::Template;
use File::Basename;

my $commonsHost = "commons.wikimedia.org";
my $overwrite = 0;
my $dbPassword;
my $dbUsername;
my $dbh;
my $username;
my $password;
my $pictureDirectory;
my $metadataFile;
my @filters;
my $help;
my $delay = 0;
my $verbose;
my %metadatas;
my $templateCode = "=={{int:filedesc}}==
{{Artwork     
  |artist           = <TMPL_VAR NAME=AUTHOR>
  |title            = <TMPL_VAR NAME=TITLE>
  |description      = {{de|<TMPL_VAR NAME=DESCRIPTION>}}
  |date             = <TMPL_VAR NAME=DATE>
  |medium           = <TMPL_VAR NAME=MEDIUM>
  |dimensions       = 
  |institution      = {{institution:Zentralbibliothek Solothurn}}
  |location         = 
  |references       =
  |object history   =
  |credit line      =
  |inscriptions     =
  |notes            = 
  |accession number = Call number <TMPL_VAR NAME=SYSID>
  |source           = Zentralbibliothek Solothurn
  |permission       = 
  |other_versions   = 
}}
{{Zentralbibliothek Solothurn}}
{{PD-old}}

[[Category:Historical images of Solothurn]]
";

my $templateCodeBack = "=={{int:filedesc}}==
{{Artwork     
  |artist           = <TMPL_VAR NAME=AUTHOR>
  |title            = <TMPL_VAR NAME=TITLE>
  |description      = {{de|1=<TMPL_VAR NAME=DESCRIPTION>}} 
  |date             = <TMPL_VAR NAME=DATE>
  |medium           = <TMPL_IF NAME=MEDIUM>{{de|1=<TMPL_VAR NAME=MEDIUM>}}</TMPL_IF>
  |dimensions       = <TMPL_IF NAME=DIMENSIONS>{{de|1=<TMPL_VAR NAME=DIMENSIONS>}}</TMPL_IF>
  |institution      = {{institution:Zentralbibliothek Zürich}}
  |location         = <TMPL_VAR NAME=LOCATION>
  |references       =
  |object history   =
  |credit line      =
  |inscriptions     =
  |notes            = 
  |accession number =
  |source           = {{Zentralbibliothek_Zürich_backlink|<TMPL_VAR NAME=SYSID>}}
  |permission       = Public domain
  |other_versions   = [[:File:<TMPL_VAR NAME=OTHER_VERSION>]]
}}
{{Zentralbibliothek_Zürich<TMPL_IF NAME=ISORIGINAL>|category=Media_contributed_by_Zentralbibliothek_Zürich (original picture)</TMPL_IF>}}

=={{int:license-header}}==
{{PD-old-100}}<TMPL_UNLESS NAME=ISORIGINAL><TMPL_IF NAME=CATEGORY>

[[Category:<TMPL_VAR NAME=CATEGORY>]]</TMPL_IF></TMPL_UNLESS NAME=ISORIGINAL>";

sub usage() {
    print "uploadZBS.pl is a script to upload files from the Solothurn central library.\n";
    print "\tuploadZBS --username=<COMMONS_USERNAME> --password=<COMMONS_PASSWORD> --directory=<PICTURE_DIRECTORY> --dbUsername=<MYSQL_USERNAME> --dbPassword=<MYSQL_PASSWORD>\n\n";
    print "In addition, you can specify a few additional arguments:\n";
    print "--filter=<ID>                    Upload only this/these image(s)\n";
    print "--delay=<NUMBER_OF_SECONDS>      Wait between two uploads\n";
    print "--help                           Print the help of the script\n";
    print "--verbose                        Print debug information to the console\n";
    print "--overwrite                      Force re-upload of pictures (both for FTP and Wikimedia commons)\n";
}

GetOptions('username=s' => \$username, 
	   'password=s' => \$password,
	   'dbUsername=s' => \$dbUsername,
	   'dbPassword=s' => \$dbPassword,
	   'directory=s' => \$pictureDirectory,
	   'delay=s' => \$delay,
	   'verbose' => \$verbose,
	   'overwrite' => \$overwrite,
	   'filter=s' => \@filters,
	   'help' => \$help,
);

if ($help) {
    usage();
    exit 0;
}

# Make a few security checks
if (!$username || !$password || !$pictureDirectory || !$dbUsername || !$dbPassword) {
    print "You have to give the following parameters (more information with --help):\n";
    print "\t--username=<COMMONS_USERNAME>\n\t--password=<COMMONS_PASSWORD>\n\t--directory=<PICTURE_DIRECTORY>\n\t--dbUsername=<MYSQL_USERNAME>\n\t--dbPassword=<MYSQL_PASSWORD>\n";
    exit;
};

unless (-d $pictureDirectory) {
    die "'$pictureDirectory' seems not to be a valid directory.";
}

unless ($delay =~ /^[0-9]+$/) {
    die "The delay '$delay' seems not valid. This should be a number.";
}

# Check connections to remote services
connectToCommons();

# Select all images from the database
$dbh = DBI->connect("DBI:mysql:database=zbs;host=localhost;port=3306", $dbUsername, $dbPassword, { RaiseError => 1 }) 
    or die "Connection impossible à la base de données 'zbs' !\n $! \n $@\n$DBI::errstr"; 
my %images; 
my $prep = $dbh->prepare('SELECT * FROM  zbsolothurn_grafiksammlung_metadaten') or die $dbh->errstr; 
$prep->execute() or die "Unable to execute SQL select request\n"; 
while (my $image = $prep->fetchrow_hashref()) { 
    $images{$image->{'id_we'}} = $image; 
} 
$prep->finish(); 

# Go through all images
foreach my $imageId (keys(%images)) {
    my $image = $images{$imageId};

    # Get image path
    my $filename = $image->{'we_signatur'};
    $filename =~ s/^(a+)(\d+)(.*)$/$1_$2/;
    $filename = "$pictureDirectory$filename.tif";
    unless ( -e $filename) {
	print STDERR "Unable to find $imageId corresponding file path.\n";
	next;
    }
    
    # Compute metadata;
    my %metadata;
    $metadata{'sysid'} = $image->{'we_signatur'};
    $metadata{'medium'} = $image->{'we_technik'}.($image->{'we_technikattribut'} ? ", ".$image->{'we_technikattribut'} : "");
    $metadata{'author'} = $image->{'we_kuenstler1'};
    $metadata{'title'} = $image->{'we_titel'};
    $metadata{'description'} = $image->{'we_inhalt'};
    $metadata{'date'} = $image->{'we_ez_jahr2'} ? "{{other date|between|".$image->{'we_ez_jahr1'}."|".$image->{'we_ez_jahr2'}."}}" : $image->{'we_ez_jahr1'};

    # Preparing description
    my $template = HTML::Template->new(scalarref => \$templateCode);
    $template->param(TITLE=>$metadata{'title'});
    $template->param(AUTHOR=>$metadata{'author'});
    $template->param(DESCRIPTION=>$metadata{'description'});
    $template->param(DATE=>$metadata{'date'});
    $template->param(SYSID=>$metadata{'sysid'});
    $template->param(MEDIUM=>$metadata{'medium'});
    my $description = $template->output();

    print $description;
}

# Read/Write functions
sub writeFile {
    my $file = shift;
    my $data = shift;
    utf8::encode($data);
    utf8::encode($file);
    open (FILE, ">", "$file") or die "Couldn't open file: $file";
    print FILE $data;
    close (FILE);
}

sub readFile {
    my $file = shift;
    utf8::encode($file);
    open FILE, $file or die $!;
    binmode FILE;
    my ($buf, $data, $n);
    while (($n = read FILE, $data, 4) != 0) { 
	$buf .= $data;
    }
    close(FILE);
    utf8::decode($data);
    return $buf;
}

# Setup the connection to Mediawiki
sub connectToCommons {
    my $site = Mediawiki::Mediawiki->new();
    $site->hostname($commonsHost);
    $site->path("w");
    $site->user($username);
    $site->password($password);

    my $connected = $site->setup();
    unless ($connected) {
	die "Unable to connect with this username/password to $commonsHost.";
    }

    return $site;
}

# Logging function
sub printLog {
    my $message = shift;
    if ($verbose) {
	utf8::encode($message);
	print "$message\n";
    }
}
