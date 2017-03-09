package Web::Driver::Client::Connection;
use strict;
use warnings;
our $VERSION = '1.0';
use JSON::PS;
use Web::Transport::ConnectionClient;
use Web::Driver::Client::Response;
use Web::Driver::Client::Session;

sub new_from_url ($$) {
  my $client = Web::Transport::ConnectionClient->new_from_url ($_[1]);
  return bless {url => $_[1], http_client => $client}, $_[0];
} # new_from_url

sub http_client ($) {
  return $_[0]->{http_client};
} # http_client

sub http_get ($$) {
  my ($self, $path) = @_;
  return $self->http_client->request (
    path => $path,
    method => 'GET',
  )->then (sub {
    return Web::Driver::Client::Response->new_from_response ($_[0]);
  });
} # http_get

sub http_delete ($$) {
  my ($self, $path) = @_;
  return $self->http_client->request (
    path => $path,
    method => 'DELETE',
  )->then (sub {
    return Web::Driver::Client::Response->new_from_response ($_[0]);
  });
} # http_delete

sub http_post ($$$) {
  my ($self, $path, $params) = @_;
  return $self->http_client->request (
    path => $path,
    method => 'POST',
    headers => {'Content-Type' => 'application/json'},
    body => (perl2json_bytes $params),
  )->then (sub {
    return Web::Driver::Client::Response->new_from_response ($_[0]);
  });
} # http_post

sub new_session ($;%) {
  my ($self, %args) = @_;
  return $self->http_post (['session'], {
    desiredCapabilities => $args{desired} || {},
    ($args{required} ? (requiredCapabilities => $args{required}) : ()),
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return Web::Driver::Client::Session->new_from_connection_and_session_id
        ($self, $res->json->{sessionId});
  });
} # new_session

sub close ($) {
  return $_[0]->{http_client}->close;
} # close

#XXX DESTROY

1;

=head1 LICENSE

Copyright 2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
