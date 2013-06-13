package PinkNoise::Layout;

use v5.12;
use Moo;
use utf8::all;
use Carp;
use DateTime::Format::Perl6;

with 'PinkNoise::Registry';

has config => (is => 'lazy', clearer => 'reload_config');

has path_cache      => (is => 'ro', default => sub { {} });
has timestamp_cache => (is => 'ro', default => sub { {} });

sub _build_config {
  my $self = shift;
  $self->db->getConfig('layout');
}

sub max_name_size {
  my $self = shift;
  return $self->config->{max_name_size};
}

sub index_types {
  my $self = shift;
  return $self->config->{indexes};
}

sub default_node_type {
  my $self = shift;
  return $self->config->{nodes}{default};
}

sub node_types {
  my $self = shift;
  return $self->config->{nodes};
}

sub get_datetime {
  my ($self, $updated) = @_;
  if (exists $self->timestamp_cache->{$updated})
  {
    return $self->timestamp_cache->{$updated};
  }
  my $dt;
  my $format = DateTime::Format::Perl6->new();
  if ($updated =~ /^\d+$/) {
    ## Integers are assumed to be Unix Epoch values.
    $dt = DateTime->from_epoch(
      epoch     => $updated,
      formatter => $format,
    );
    $dt->set_time_zone('local');
  }
  else {
    ## Any other string must be a Perl 6 style ISO8601 datetime string.
    $dt = $format->parse_datetime($updated);
  }
  return $self->timestamp_cache->{$updated} = $dt;
}

sub get_node_type {
  my ($self, $node) = @_;
  return lc($node->{type} // $self->default_node_type);
}

sub get_index_opts {
  my ($self, $tag) = @_;
  my $opts;
  my $indexes = $self->index;
  if (exists $indexes->{$tag}) {
    $opts = $indexes->{$tag};
  }
  elsif (exists $indexes->{default}) {
    my $def_index = $indexes->{default};
    $opts = $indexes->{$def_index};
  }
  else {
    croak "Could not determine index layout options for '$tag'";
  }
}

sub get_node_opts {
  my ($self, $nodetype) = @_;
  my $nodetypes = $self->node_types;
  if (exists $nodetypes->{$nodetype}) {
    return $nodetypes->{$nodetype};
  }
  else {
    croak "Could not determine node options for '$nodetype'";
  }
}

sub index_path {
  my ($self, $tag, $page) = @_;
  if (!$page || $page < 1) { $page = 1; }
  my $cachekey = "index-$tag-$page";
  if (exists $self->path_cache->{$cachekey}) {
    return $self->path_cache->{$cachekey};
  }
  my ($path, $opts);

  my $opts = $self->get_index_opts($tag);
    
  if ($page == 1) {
    $path = $opts->{path_first};
  }
  else {
    $path = $opts->{path_more};
  }
  
  $path =~ s/\$page/$page/g;
  $path =~ s/\$tag/$tag/g;
  return $self->path_cache->{$cachekey} = $path;
}

sub get_node_name {
  my ($self, $node) = shift;
  if (exists $node->{name}) {
    return $node->{name};
  }
  elsif (exists $node->{title}) {
    my $name = $node->{title};
    $name =~ s/\W+/_/g;
    $name = substr($name, 0, $self->max_name_size);
    $name =~ s/_+$//g;
    $name =~ s/^_+//g;
    return lc($name);
  }
  else {
    croak "Invalid node name, ensure node has 'name' or 'title' set.";
  }
}

sub node_path {
  my ($self, $node, $page) = @_;
  if (!$page || $page < 1) { $page = 1; }

  my $path;

  my $nodename = $self->get_node_name($node);
  my $nodetype = $self->get_node_type($node);
  my $nodeopts = $self->get_node_opts($nodetype); 

  my $handler  = $self->get_handler($nodetype);

  if ($handler->can('get_path')) {
    $path = $handler->get_path(
      node => $node, 
      name => $nodename,
      page => $page,
      opts => $nodeopts,
    );
  }
  else {
    croak "Handler for '$nodetype' cannot get_path()";
  }

  $path =~ s/\$name/$nodename/g;
  $path =~ s/\$page/$page/g;

  return $path;
}

1;
