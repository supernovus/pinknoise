package PinkNoise::Layout;

use v5.12;
use Moo;
use utf8::all;
use Carp;
use DateTime::Format::Perl6;

## This MUST be a PinkNoise::DB object.
has db => (is => 'ro', required => 1);

has config => (is => 'lazy', clearer => 'reload_config');

has path_cache      => (is => 'ro', default => sub { {} });
has timestamp_cache => (is => 'ro', default => sub { {} });

sub _build_config {
  my $self = shift;
  my %default = (
    default_type  => 'article',
    max_name_size => 24,
    index => {
      display         => 10,
      template        => 'index.tt',
      main_tag        => 'toc',
      tag_path_first  => '/tags/$tag/index.html',
      tag_path_more   => '/tags/$tag/page$page.html',
      main_path_first => '/index.html',
      main_path_more  => '/index/page$page.html',
    },
    article => {
      template         => 'page.tt',
      top_path_single  => '/articles/$name.html',
      top_path_first   => '/articles/$name/index.html',
      top_path_more    => '/articles/$name/page$page.html',
      date_path_single => '/articles/$year/$month/$name.html',
      date_path_first  => '/articles/$year/$month/$name/index.html',
      date_path_more   => '/articles/$year/$month/$name/page$page.html',
    },
    story => {
      template => 'story.tt',
      toc_path => '/stories/$name/index.html',
    },
    chapter => {
      template    => 'chapter.tt',
      single_path => '/stories/$story/$name.html',
      page_path   => '/stories/$story/$name/page$page.html',
    },
  );
  $self->db->getConfig('layout', %default);
}

sub default_type {
  my $self = shift;
  return $self->config->{default_type};
}

sub max_name_size {
  my $self = shift;
  return $self->config->{max_name_size};
}

sub index {
  my $self = shift;
  return $self->config->{index};
}

sub article {
  my $self = shift;
  return $self->config->{article};
}

sub story {
  my $self = shift;
  return $self->config->{story};
}

sub chapter {
  my $self = shift;
  return $self->config->{chapter};
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
  return lc($node->{type} // $self->default_type);
}

sub page_count {
  my ($self, $node_count, $display) = @_;
  if (!$display) {
    $display = $self->index->{display};
  }
  ceil($node_count / $display);
}

sub index_path {
  my ($self, $tag, $page) = @_;
  if (!$page || $page < 1) { $page = 1; }
  my $cachekey = "index-$tag-$page";
  if (exists $self->path_cache->{$cachekey}) {
    return $self->path_cache->{$cachekey};
  }
  my $path;
  my $opts = $self->index;
  if ($tag eq $opts->{main_tag}) {
    if ($page == 1) {
      $path = $opts->{main_path_first};
    }
    else {
      $path = $opts->{main_path_more};
    }
  }
  else {
    if ($page == 1) {
      $path = $opts->{tag_path_first};
    }
    else {
      $path = $opts->{tag_path_more};
    }
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

  my ($path, $opts);

  my $nodename = $self->get_node_name($node);
  my $nodetype = $self->get_node_type($node);

  if ($nodetype eq 'article') {
    $opts = $self->article;
    my $single = 0;
    if (!exists $node->{contents} || !ref $node->{contents}) {
      $single = 1;
    }
    if ($node->{toplevel}) {
      if ($single) {
        $path = $opts->{top_path_single};
      }
      elsif ($page == 1) {
        $path = $opts->{top_path_first};
      }
      else {
        $path = $opts->{top_path_more};
      }
    }
    else {
      if ($single) {
        $path = $opts->{date_path_single};
      }
      elsif ($page == 1) {
        $path = $opts->{date_path_first};
      }
      else {
        $path = $opts->{date_path_more};
      }
      if (exists $opts->{changelog}) {
        my $cl = $opts->{changelog};
        my $created = $cl->[-1]; ## Changelog is in newest-first order.
        my $ts = $created->{date};
        my $dt = $self->get_datetime($ts);
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
    }  
  }
  elsif ($nodetype eq 'story') {
    $opts = $self->story;
    $path = $opts->{toc_path};
  }
  elsif ($nodetype eq 'chapter') {
    $opts = $self->chapter;
    if (!exists $node->{parent}) {
      croak "Chapter nodes must have a parent story!";
    }
    my $single = 0;
    if (!exists $node->{contents}) {
      croak "Chapter nodes require contents.";
    }
    elsif (!ref $node->{contents}) {
      $single = 1;
    }
    if ($single) {
      $path = $opts->{single_path};
    }
    else {
      $path = $opts->{page_path};
    }
    my $story = $self->db->getNodeById($node->{parent});
    if (!$story) {
      croak "Invalid parent story '".$node->{parent}."' specified in '$nodename'";
    }
    my $storyname = $self->get_node_name($story);
    $path =~ s/\$story/$storyname/g;
  }
  else {
    croak "Unhandled node type '$nodetype' found.";
  }

  $path =~ s/\$name/$nodename/g;
  $path =~ s/\$page/$page/g;

  return $path;
}

1;
