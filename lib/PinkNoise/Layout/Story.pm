package PinkNoise::Layout::Story;

use v5.12;
use Moo;

extends 'PinkNoise::Layout::Node';

sub get_path {
  my $self = shift;
  ## We enforce the only single page rule.
  return $self->get_path_spec(only_single => 1, @_);
}

1;
