package Web::Driver::Client::Session;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::URL;

sub new_from_connection_and_session_id ($$$) {
  return bless {connection => $_[1], session_id => $_[2]}, $_[0];
} # new_from_connection_and_session_id

sub session_id ($) {
  return $_[0]->{session_id};
} # session_id

sub http_get ($$$) {
  my ($self, $path, $params) = @_;
  return $self->{connection}->http_get (['session', $self->{session_id}, @$path]);
} # http_get

sub http_post ($$$) {
  my ($self, $path, $params) = @_;
  return $self->{connection}->http_post (['session', $self->{session_id}, @$path], $params);
} # http_post

sub http_delete ($$) {
  my ($self, $path) = @_;
  return $self->{connection}->http_delete (['session', $self->{session_id}, @$path]);
} # http_delete

sub go ($$) {
  my ($self, $url) = @_;
  return $self->http_post (['url'], {
    url => (UNIVERSAL::isa ($url, 'Web::URL') ? $url->stringify : $url),
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return undef;
  });
} # go

sub url ($) {
  my $self = $_[0];
  return $self->http_get (['url'])->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    my $parsed = Web::URL->parse_string ($res->json->{value});
    die "WebDriver server returns an unparsable URL <@{[$res->json->{value}]}>"
        unless defined $parsed;
    return $parsed;

  });
} # url

sub execute ($$$;%) {
  my ($self, $script, $args, %args) = @_;
  return $self->http_post (['execute'], {
    script => $script,
    args => $args || [],
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return $res;
  });
} # execute

sub close ($) {
  my $self = $_[0];
  $self->{closed} = 1;
  return $self->http_delete ([]);
} # close

sub DESTROY ($) {
  my $self = $_[0];
  $self->close unless $self->{closed};
}

1;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
