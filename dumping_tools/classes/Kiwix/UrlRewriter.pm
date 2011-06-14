package Kiwix::UrlRewriter;
use base HTML::Parser;

use strict;
use warnings;
use Data::Dumper;
use Carp;
use HTML::Tagset ();
use URI;

sub new {
    my($class, $callback) = @_;
    my $self = $class->SUPER::new(
				  start_h => [ \&_start_tag, "self,tagname,attr,attrseq,text" ],
				  default_h => [ \&_default, "self,tagname,attr,text" ],
				  );
    unless ($callback) {
        Carp::croak("Kiwix::UrlRewriter callback is a required parameter");
    }
    
    $self->{resolvelink_callback} = $callback;

    return $self;
}

sub _start_tag {
    my($self, $tagname, $attr, $attrseq, $text) = @_;

    if ($tagname eq 'base' && defined $attr->{href}) {
        $self->{resolvelink_base} = $attr->{href};
    }

    my $links = $HTML::Tagset::linkElements{$tagname} || [];
    $links = [$links] unless ref $links;

    for my $link (@$links) {
	next unless exists $attr->{$link};
	$attr->{$link}  = $self->{resolvelink_callback}->($attr->{$link});
    }

    $self->{resolvelink_html} .= "<$tagname";
    for my $a (@$attrseq) {
        next if $a eq '/';
        $self->{resolvelink_html} .= sprintf qq( %s="%s"), $a, _escape($attr->{$a});
    }
    $self->{resolvelink_html} .= ' /' if $attr->{'/'};
    $self->{resolvelink_html} .= '>';
}

sub _default {
    my($self, $tagname, $attr, $text) = @_;
    $self->{resolvelink_html} .= $text;
}

my %escape = (
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
    '&' => '&amp;',
    '\+' => '%2B',
	      );
my $esc_re = "(".join('|', keys %escape).")";

# Necessary otherwise $escape{$1} matchs nothing 
$escape{'+'} = '%2B'; 

sub _escape {
    my $str = shift;
    $str =~ s/$esc_re/$escape{$1}/g;
    $str;
}

sub resolve {
    my($self, $html) = @_;

    # init
    $self->{resolvelink_html} = '';
    $self->{resolvelink_count} = 0;

    $self->parse($html);
    $self->eof;

    $self->{resolvelink_html};
}

sub resolved_count {
    my $self = shift;
    $self->{resolvelink_count};
}

1;
