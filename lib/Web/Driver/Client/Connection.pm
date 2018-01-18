package Web::Driver::Client::Connection;
use strict;
use warnings;
our $VERSION = '1.0';
use JSON::PS;
use Promised::Flow;
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
  my $session_args = {
    desiredCapabilities => $args{desired} || {}, # XXX not documented yet
    ($args{required} ? (requiredCapabilities => $args{required}) : ()), # XXX at risk
  };
  if ($args{http_proxy_url}) {
    $session_args->{desiredCapabilities}->{proxy} = {
      proxyType => 'manual',
      httpProxy => $args{http_proxy_url}->hostport,
    };
  }
  my $res;
  return Promise->resolve->then (sub {
    ## ChromeDriver sometimes hungs up without returning any response
    ## or closing connection.
    return promised_wait_until {
      return Promise->resolve->then (sub {
        return promised_timeout {
          return $self->http_post (['session'], $session_args);
        } 10;
      })->then (sub {
        $res = $_[0];
        die $res if $_[0]->is_network_error;
        return 1;
      })->catch (sub {
        return $self->http_client->abort (message => '|new_session| timeout (20)')->then (sub {
          $self->{http_client} = Web::Transport::ConnectionClient->new_from_url
              ($self->{url});
          return 0;
        });
      });
    } timeout => 60*3;
  })->then (sub {
    die $res if $res->is_error;
    my $json = $res->json;
    my $session_id = $json->{sessionId};
    if (defined $json->{value} and ref $json->{value} eq 'HASH' and
        defined $json->{value}->{sessionId}) {
      $session_id = $json->{value}->{sessionId};
    }
    return Web::Driver::Client::Session->new_from_connection_and_session_id
        ($self, $session_id);
  });
} # new_session
# XXX GeckoDriver does not support creating of multiple concurrent sessions

# XXX should also close any existing sessions?
sub close ($) {
  return $_[0]->{http_client}->close;
} # close

sub DESTROY ($) {
  return $_[0]->close;
} # DESTROY

1;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.
Copyright 2018 OND Inc. <https://ond-inc.com/>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
