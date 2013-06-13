package PinkNoise::Layout::Chapter;

use v5.12;
use Moo;
use Carp;

extends 'PinkNoise::Layout::Node';

sub get_path {
  my ($self, %params) = @_;

  my $node = $params{node};
  my $name = $params{name};

  if (!exists $node->{story}) {
    croak "Chapter node '$name' does not have a parent story.";
  }

  my $path = $self->get_path_spec(%params);

  my $story = $self->parent->db->getNodeById($node->{story});
  if (!$story) {
    croak "Invalid parent story '".$node->{story}."' in '$name'";
  }
  my $storyname = $self->parent->get_node_name($story);

  $path =~ s/\$story/$storyname/g;

  return $path;
}

1;
