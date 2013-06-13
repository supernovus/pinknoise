package PinkNoise::DB;

use v5.12;
use Moo;
use utf8::all;
use MongoDB;
use Carp;

has host   => (is => 'ro', default => sub { 'localhost' });
has dbname => (is => 'ro', required => 1);

has client => (is => 'lazy');
has db     => (is => 'lazy');
has nodes  => (is => 'lazy');
has config => (is => 'lazy');

sub _build_client {
  my $self = shift;
  MongoDB::MongoClient->new(host => $self->host);
}

sub _build_db {
  my $self = shift;
  $self->client->get_database($self->dbname);
}

sub _build_nodes {
  my $self = shift;
  $self->db->get_collection('nodes');
}

sub _build_config {
  my $self = shift;
  $self->db->get_collection('config');
}

sub getConfig {
  my ($self, $id) = @_;
  my $doc = $self->config->find_one({_id => $id});
  if (!$doc) {
    croak "Configuration document '$id' not found, cannot continue.";
  }
  return $doc;
}

sub saveConfig {
  my ($self, $config) = @_;
  $self->config->save($config);
}

sub loadConfig {
  require JSON;
  my ($self, $id, $json) = @_;
  my $config;
  if ($json =~ /^\{/) {
    $config = decode_json($json);
  }
  elsif (-f $json) {
    require Perl6::Slurp;
    my $jsonfile = slurp $json;
    $config = decode_json($jsonfile);
  }
  else {
    croak "Invalid JSON config '$json' passed to loadConfig";
  }
  $config->{_id} = $id;
  $self->saveConfig($config);
}

sub getNodeById {
  my ($self, $id, $fields) = @_;
  $self->nodes->find_one({_id => $id}, $fields);
}

sub getNodes {
  my ($self, $query, %opts) = @_;
  my $cursor = $self->nodes->find($query);
  if (exists $opts{sort}) {
    $cursor->sort($opts{sort});
  }
  if (exists $opts{limit}) {
    $cursor->limit($opts{limit});
  }
  if (exists $opts{skip}) {
    $cursor->skip($opts{skip});
  }
  if (exists $opts{fields}) {
    $cursor->fields($opts{fields});
  }
}

sub countNodes {
  my ($self, $query) = @_;
  $self->nodes->count($query);
}

sub getNodesByTag {
  my $self = shift;
  my $tag  = shift;
  $self->getNodes({tags => $tag}, @_);
}

sub countNodesByTag {
  my ($self, $tag) = @_;
  $self->countNodes({tags => $tag});
}

sub update {
  my ($self, $query, $spec, %opts) = @_;
  if (!ref $query) {
    $query = {_id => $query};
  }
  $self->nodes->update($query, $spec, \%opts);
}

sub addTag {
  my $self  = shift;
  my $query = shift;
  my $tag   = shift;
  my $spec;
  if (ref $tag eq 'ARRAY') {
    $spec = { '$addToSet' => { 'tags' => { '$each' => $tag } } };
  }
  else {
    $spec = { '$addToSet' => { tags => $tag } };
  }
  $self->update($query, $spec, @_);
}

sub delTag {
  my $self  = shift;
  my $query = shift;
  my $tag   = shift;
  my $spec;
  if (ref $tag eq 'ARRAY') {
    $spec = { '$pullAll' => { tags => $tag } };
  }
  else {
    $spec = { '$pull' => { tags => $tag } };
  }
  $self->update($query, $spec, @_);
}

sub save {
  my ($self, $node) = @_;
  $self->nodes->save($node);
}

1;
