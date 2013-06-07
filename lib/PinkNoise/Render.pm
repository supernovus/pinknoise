package PinkNoise::Render;

use v5.12;
use Moo;

extends 'Webtoo::Template::TT';

## This MUST be a PinkNoise::DB object.
has db     => (is => 'ro', required => 1);
has site   => (is => 'lazy');
has types  => (is => 'lazy');

sub __getconfig {
  my ($self, $name) = @_;
  my $doc  = $self->db->getConfig($name);
  if (!$doc) {
    $doc = {_id => $name};
  }
  return $doc;
}

sub _build_site {
  my $self = shift;
  $self->__getconfig('site');
}

sub _build_types {
  my $self = shift;
  $self->__getconfig('types');
}

sub renderNode {
  my ($self, $node, %opts) = @_;
  if (!ref $node) {
    $node = $self->db->getNodebyId($node);
  }
}
