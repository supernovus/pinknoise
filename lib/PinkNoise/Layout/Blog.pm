package PinkNoise::Layout::Blog;

use v5.12;
use Moo;
use Carp;

extends 'PinkNoise::Layout::Node';

sub get_path {
  my ($self, %params) = @_;
  
  my $path = $self->get_path_spec(%params);
  my $node = $params{node};

  if (exists $node->{changelog}) {
    my $cl = $node->{changelog};
    my $created = $cl->[-1]; ## Changelog is in newest-first order.
    my $ts = $created->{date};
    my $dt = $self->parent->get_datetime($ts);

    if (!$dt) {
      croak "Could not parse timestamp '$ts'.";
    }
  
    my $year  = sprintf('%04d', $dt->year);
    my $month = sprintf('%02d', $dt->month);
    my $day   = sprintf('%02d', $dt->day);
    my $hour  = sprintf('%02d', $dt->hour);
    my $min   = sprintf('%02d', $dt->min);
  
    $path =~ s/\$year/$year/g;
    $path =~ s/\$month/$month/g;
    $path =~ s/\$day/$day/g;
    $path =~ s/\$hour/$hour/g;
    $path =~ s/\$min/$min/g;

  }
  else {
    croak "No changelog detected for '$nodename'";
  }

  return $path;
}

1;
