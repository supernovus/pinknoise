package PinkNoise::Registry;

use v5.12;
use Moo::Role;
use Carp;

has db => (is => 'ro', required => 1);

has handlers => (is => 'ro', default => sub { {} });

sub add_handler {
  my ($self, $nodetype, $handler) = @_;
  if (!ref $handler) {
    require UNIVERSAL::require;
    my $classname;
    if (!$handler) {
      $classname = ref $self . '::' . ucfirst(lc($nodetype));
    }
    elsif ($handler =~ /\:\:/) {
      $classname = $handler;
    }
    else {
      $classname = ref $self . '::' . $handler;
    }
    $classname->require or croak "Could not load $classname handler.";
    $handler = $classname->new(parent => $self);
  }
  $self->handlers->{$nodetype} = $handler;
}

sub get_handler {
  my ($self, $nodetype) = @_;
  if (exists $self->handlers->{$nodetype}) {
    return $self->handlers->{$nodetype};
  }
  else {
    croak "No handler for '$nodetype' has been loaded.";
  }
}

1;
