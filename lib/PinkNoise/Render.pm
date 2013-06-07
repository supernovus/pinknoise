package PinkNoise::Render;

use v5.12;
use Moo;
use POSIX qw(ceil);

extends 'Webtoo::Template::TT';

## This MUST be a PinkNoise::DB object.
has db     => (is => 'ro', required => 1);
has site   => (is => 'lazy');
has layout => (is => 'lazy');

sub __getconfig {
  my ($self, $name, %def) = @_;
  my $doc  = $self->db->getConfig($name);
  if (!$doc) {
    $doc = \%def;
    $doc->{_id} = $name;
  }
  return $doc;
}

sub _build_site {
  my $self = shift;
  $self->__getconfig('site');
}

sub _build_layout {
  my $self = shift;
  my %default = (
    index => {
      display   => 10,
      template  => 'index.tt',
    },
    page => {
      template => 'page.tt',
    },
    story => {
      template => 'story.tt',
    },
    chapter => {
      template => 'chapter.tt',
    },
  );
  $self->__getconfig('layout', %default);
}

sub renderNode {
  my ($self, $node, %opts) = @_;
  if (!ref $node) {
    $node = $self->db->getNodebyId($node);
  }
}

sub node_count {
  my ($self, $tag) = @_;
  $self->db->countNodesByTag($tag);
}

sub page_count {
  my ($self, $node_count, $display) = @_;
  if (!$display) {
    $display = $self->layout->{index}{display};
  }
  ceil($node_count / $display);
}

sub index_path {
  my ($self, $tag, $page) = @_;
  if (!$page) { $page = 1; }
  my $dir;
  if ($tag eq 'TOC') {
    if ($page > 1) {
      $dir = '/index/';
    }
    else {
      $dir = '/';
    }
  }
  else {
    $dir = "/tags/$tag/";
  }
  my $file;
  if ($page == 1) {
    $file = 'index.html';
  }
  else {
    $file = "page${page}.html";
  }
  return $dir . $file;
}

sub pager {
  my ($self, $page_count, %opts) = @_;
  my @pager;
  for my $page ( 1 .. $page_count) {
    my $item = { num => $page, current => 0 };
    if (exists $opts{current_page}) {
      my $current_page = $opts{current_page};
      if ($page == $current_page) {
        $item->{current} = 1;
      }
    }
    if (exists $opts{link}) {
      my $link;
      my $type = $opts{link};
      if ($type eq 'index') {
        my $tag;
        if (exists $opts{tag}) {
          $tag = $opts{tag};
        }
        else {
          $tag = 'TOC';
        }
        $link = $self->index_path($tag, $page);
      }
      elsif ($type eq 'page') {
        warn "Not implemented yet.";
      }
      if ($link) {
        $item->{link} = $link;
      }
    }
    push @pager, $item;
  }
  return \@pager;
}

## Render every page of an index, returning an array of pages.
sub renderIndex {
  my ($self, $tag, %opts) = @_;

  my @pages;

  my $node_count = $self->node_count($tag);
  my $page_count = $self->page_count($node_count);

  ## Add the counts to the opts, to pass along.
  $opts{node_count} = $node_count;
  $opts{page_count} = $page_count;

  ## Build a pager.
  $opts{page_list} = $self->pager($page_count);

  ## Okay, process each page of the index.
  for my $page ( 1 .. $page_count ) {
    my $rendered = $self->renderIndexPage($tag, $page, %opts);
    push @pages, $rendered;
  }

  return @pages;
}

sub renderIndexPage {
  my ($self, $tag, $page, %opts) = @_;

  ## Get our layout configuration.
  my $index = $self->layout->{index};

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

  my ($node_count, $page_count);
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

  my $page_list = $self->pager($page_count, 
    link         => 'index',
    tag          => $tag,
    current_page => $page,
  );

  my $template_data = {
    index_tag     => $
    current_page  => $page,
    page_count    => $page_count,
    node_count    => $node_count,
    page_list     => $page_list,
    layout        => $index,
    nodes         => $nodes,
    site          => $self->site,
  };

  $self->render($template, $template_data);
}

1;

