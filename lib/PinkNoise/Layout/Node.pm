package PinkNoise::Layout::Node;

## A default implementation, can be extended.

use v5.12;
use Moo;
use Carp;

with 'PinkNoise::Handler';

## Override this with your own implementation.
sub get_path {
  my $self = shift;
  return $self->get_path_spec(@_);
}

## You can call this to handle common options.
sub get_path_spec {
  my ($self, %params) = @_;

  my $node = $params{node};
  my $opts = $params{opts};
  my $page = $params{page};

  my $path;

  if (!exists $node->{contents} || !ref $node->{contents}) {
    if (exists $params{no_single} && $params{no_single}) {
      croak "This node does not support single pages";
    }
    else {
      $path = $opts->{path_single};
    }
  }
  elsif (exists $params{only_single} && $params{only_single}) {
    croak "This node only supports single pages";
  }
  elsif ($page == 1) {
    $path = $opts->{path_first};
  }
  else {
    $path = $opts->{path_more};
  }
  return $path;
}

1;

