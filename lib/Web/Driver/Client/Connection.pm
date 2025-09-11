package Web::Driver::Client::Connection;
use strict;
use warnings;
our $VERSION = '2.0';
use JSON::PS;
use Promised::Flow;
use Web::Transport::BasicClient;
use Web::Driver::Client::Response;
use Web::Driver::Client::Session;

push our @CARP_NOT, qw(Web::Transport::BasicClient);

sub new_from_url ($$) {
  my $client = Web::Transport::BasicClient->new_from_url ($_[1]);
  return bless {url => $_[1], http_client => $client,
                cookies => {}}, $_[0];
} # new_from_url

sub http_client ($) {
  return $_[0]->{http_client};
} # http_client

sub http_get ($$) {
  my ($self, $path) = @_;
  return $self->http_client->request (
    path => $path,
    method => 'GET',
    headers => $self->_headers,
  )->then (sub {
    my $res = Web::Driver::Client::Response->new_from_response ($_[0]);
    $self->_process_response_cookies ($res);
    return $res;
  });
} # http_get

sub http_delete ($$) {
  my ($self, $path) = @_;
  return $self->http_client->request (
    path => $path,
    method => 'DELETE',
    headers => $self->_headers,
  )->then (sub {
    my $res = Web::Driver::Client::Response->new_from_response ($_[0]);
    $self->_process_response_cookies ($res);
    return $res;
  });
} # http_delete

sub http_post ($$$) {
  my ($self, $path, $params) = @_;
  return $self->http_client->request (
    path => $path,
    method => 'POST',
    body => (perl2json_bytes $params),
    headers => {
      'Content-Type' => 'application/json',
      %{$self->_headers},
    },
  )->then (sub {
    my $res = Web::Driver::Client::Response->new_from_response ($_[0]);
    $self->_process_response_cookies ($res);
    return $res;
  });
} # http_post

sub _headers ($) {
  my $self = shift;
  my $cookie = join '; ', map { $_ . '=' . $self->{cookies}->{$_} } keys %{$self->{cookies}};
  return length $cookie ? {cookie => $cookie} : {};
} # _headers

sub _process_response_cookies ($$) {
  my ($self, $res) = @_;

  my $r = $res->{response};
  return if $r->is_network_error;

  for my $value (@{$r->header_all ('set-cookie')}) {
    # XXX cookie parsing
    if ($value =~ /^([^;=]+)=([^;=]*);/) {
      $self->{cookies}->{$1} = $2;
    }
  }
} # _process_response_cookies

sub new_session ($;%) {
  my ($self, %args) = @_;
  my $session_args = {
    desiredCapabilities => $args{desired} || {}, # XXX not documented yet
    ($args{required} ? (requiredCapabilities => $args{required}) : ()), # XXX at risk
  };
  if (defined $args{http_proxy_url} or defined $args{https_proxy_url}) {
    $session_args->{desiredCapabilities}->{proxy} = {
      proxyType => 'manual',
    };
    $session_args->{desiredCapabilities}->{proxy}->{httpProxy} = $args{http_proxy_url}->hostport
        if defined $args{http_proxy_url};
    $session_args->{desiredCapabilities}->{proxy}->{sslProxy} = $args{https_proxy_url}->hostport
        if defined $args{https_proxy_url};
  } # proxy
  if (defined $args{profile_dir}) {
    push @{$session_args->{desiredCapabilities}->{chromeOptions}->{args} ||= []},
        '--user-data-dir=' . $args{profile_dir} . '/chrome';
    $session_args->{desiredCapabilities}->{'moz:firefoxOptions'}->{profile}
        = "$args{profile_dir}/firefox";
  }
  ## <https://bugs.chromium.org/p/chromium/issues/detail?id=736452>
  push @{$session_args->{desiredCapabilities}->{chromeOptions}->{args} ||= []},
      '--disable-dev-shm-usage';
  $session_args->{capabilities}->{alwaysMatch} = {
    %{$session_args->{desiredCapabilities} or {}},
    %{$session_args->{requiredCapabilities} or {}},
  };
  $session_args->{capabilities}->{alwaysMatch}->{'goog:chromeOptions'}
      = delete $session_args->{capabilities}->{alwaysMatch}->{chromeOptions};

  my $res;
  return Promise->resolve->then (sub {
    ## ChromeDriver sometimes hungs up without returning any response
    ## or closing connection.
    return promised_wait_until {
      my $timeout = 20;
      return Promise->resolve->then (sub {
        return promised_timeout {
          return $self->http_post (['session'], $session_args);
        } $timeout;
      })->then (sub {
        $res = $_[0];
        die $res if $_[0]->is_network_error;
        return 1;
      })->catch (sub {
        return $self->http_client->abort (message => "|new_session| timeout ($timeout, $_[0])")->then (sub {
          my $new_client = Web::Transport::BasicClient->new_from_url
              ($self->{url}, {
                last_resort_timeout => $self->{http_client}->last_resort_timeout,
              });
          $self->{http_client} = $new_client;
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

Copyright 2016-2025 Wakaba <wakaba@suikawiki.org>.

Copyright 2018 OND Inc. <https://ond-inc.com/>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
