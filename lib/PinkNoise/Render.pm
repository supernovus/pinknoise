package PinkNoise::Render;

use v5.12;
use Moo;
use POSIX qw(ceil);
use Carp;
use utf8::all;
use Text::Markdown;

extends 'Webtoo::Template::TT';

## This MUST be a PinkNoise::DB object.
has db     => (is => 'ro', required => 1);
has site   => (is => 'lazy', clearer => 'reload_site');
has layout => (is => 'lazy', handles => [
  'page_count', 'index_path', 'node_path', 'get_node_type', 'get_datetime',
]);

sub _build_site {
  my $self = shift;
  $self->db->getConfig('site');
}

sub _build_layout {
  my $self = shift;
  return PinkNoise::Layout->new(db => $self->db);
}

## Useful to call from templates.
sub strftime {
  my ($self, $format, $updated) = @_;
  my $dt = $self->get_datetime($updated);
  if (ref $dt eq 'DateTime') {
    return $dt->strftime($format);
  }
  else {
    carp "Could not handle datetime format '$updated'";
    return $updated;
  }
}

sub renderNode {
  my ($self, $node, %opts) = @_;
  if (!ref $node) {
    $node = $self->db->getNodeById($node);
  }
  my $type = $self->get_node_type($node);

  die "TODO: Not finished yet";
}

sub node_count {
  my ($self, $tag) = @_;
  $self->db->countNodesByTag($tag);
}

sub pager {
  my ($self, %opts) = @_;
  my @pager;
  for my $page ( 1 .. $opts{count}) {
    my $item = { num => $page };
    if (exists $opts{link}) {
      my $link;
      my $type = $opts{link};
      if ($type eq 'index') {
        if (exists $opts{tag}) {
          $link = $self->index_path($opts{tag}, $page);
        }
        else {
          carp "Indexes need tag to build link.";
        }
      }
      elsif ($type eq 'article') {
        carp "Multi-page articles are not implemented yet.";
      }
      elsif ($type eq 'chapter') {
        carp "Chapters are not implemented yet.";
      }
      elsif ($type eq 'story') {
        carp "Story nodes should have 0 or 1 pages, and do not need pagers.";
      }
      if ($link) {
        $item->{link} = $link;
      }
    }
    push @pager, $item;
  }
  return \@pager;
}

## Render every page of an index, returning a hash of $filename => $content
sub renderIndex {
  my ($self, $tag, %opts) = @_;

  my $pages = {};

  my $node_count = $self->node_count($tag);
  my $page_count = $self->page_count($node_count);

  ## Add the counts to the opts, to pass along.
  $opts{node_count} = $node_count;
  $opts{page_count} = $page_count;

  ## Generate a pager
  my $page_list = $opts{page_list} = $self->pager(
    count => $page_count,
    link  => 'index',
    tag   => $tag,
  );

  ## Okay, process each page of the index.
  for my $page (@$page_list) {
    my $rendered = $self->renderIndexPage($tag, $page->{num}, %opts);
    my $pkey;
    if (exists $page->{link}) {
      $pkey = $page->{link};
    }
    else {
      $pkey = $page->{num};
    }
    $pages->{$pkey} = $rendered;
  }

  return $pages;
}

sub renderIndexPage {
  my ($self, $tag, $page, %opts) = @_;

  ## Get our layout configuration.
  my $index = $self->layout->index;

  ## The number of items to display, and the template.
  my $display  = $index->{display};
  my $template = $index->{template};

  my %node_opts = (
    limit => $display,
    skip  => $display * ($page - 1),
  );

  if (exists $index->{sort}) {
    $node_opts{sort} = $index->{sort};
  }

  ## Get all Nodes associated with this tag.
  my $nodes = $self->db->getNodesByTag($tag, %node_opts);

  my ($node_count, $page_count, $page_list);
  if (exists $opts{node_count}) {
    $node_count = $opts{node_count};
  }
  else {
    $node_count = $self->node_count($tag);
  }
  if (exists $opts{page_count}) {
    $page_count = $opts{page_count};
  }
  else {
    $page_count = $self->page_count($node_count, $display);
  }
  if (exists $opts{page_list}) {
    $page_list = $opts{page_list};
  }
  else {
    $page_list = $self->pager(
      count => $page_count, 
      link  => 'index',
      tag   => $tag,
    );
  }

  my $template_data = {
    index_tag     => $tag,
    current_page  => $page,
    page_count    => $page_count,
    node_count    => $node_count,
    page_list     => $page_list,
    layout        => $index,
    nodes         => $nodes,
    site          => $self->site,
    render        => $self,
  };

  $self->render($template, $template_data);
}

1;

