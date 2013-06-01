package PinkNoise::DB;

use v5.12;
use Moo;
use MongoDB;

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
  $self->config->find_one({_id => $id});
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

sub getNodesByTag {
  my $self = shift;
  my $tag  = shift;
  $self->getNodes({_tags => $tag}, @_);
}

1;
