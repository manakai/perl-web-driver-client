#!/usr/bin/env perl
use strict;
use FindBin;
use lib glob "$FindBin::Bin/../modules/*/lib";
use lib glob "$FindBin::Bin/../t_deps/modules/*/lib";
use lib "$FindBin::Bin/../lib";
use warnings;
use Test::More;
use Promise;
use Web::Driver::Client::Response;

if (@ARGV) {
  do shift @ARGV or die $@ || $!;
} else {
  require Web::Driver::Client::Connection;
}

{
  package SessionTestConnection;
  our @ISA = ('Web::Driver::Client::Connection');
  sub http_post {
    my ($self, $path, $args) = @_;
    ++$self->{posts};
    $self->{args} = $args;
    if ($self->{active}) {
      my $response = Web::Driver::Client::Response->new_from_json
          ({value => {error => 'session not created', message => 'Session is already started'}});
      $response->mark_as_error;
      return Promise->resolve($response);
    }
    $self->{active} = 1;
    return Promise->reject('connection lost after accepting session')
        if $self->{mode} eq 'network-error';
    my $response = Web::Driver::Client::Response->new_from_json
        ({value => {sessionId => 'owned-session'}});
    if ($self->{mode} eq 'protocol-error') {
      $self->{active} = 0;
      $response->mark_as_error;
    }
    return Promise->resolve($response);
  }
  sub http_delete {
    my ($self, $path) = @_;
    ++$self->{deletes};
    $self->{deleted_path} = $path;
    $self->{active} = 0;
    return Promise->resolve;
  }
}
{
  package SessionTestHTTP;
  sub abort { ++$_[0]->{aborts}; return Promise->resolve }
  sub close { return Promise->resolve }
  sub last_resort_timeout { return 600 }
}

for my $mode (qw(delayed normal network-error protocol-error deadline default enabled)) {
  subtest $mode => sub {
    my $http = bless {aborts => 0}, 'SessionTestHTTP';
    my $wd = bless {http_client => $http, mode => $mode, posts => 0,
                    deletes => 0, active => 0}, 'SessionTestConnection';
    my (@deadlines, $session, $error);
    {
      no warnings qw(redefine once);
      # Control the response/deadline ordering without making CI wait 22 seconds.
      # The separate real-HTTP reproduction checks the same ordering with real timers.
      local *Web::Driver::Client::Connection::promised_timeout = sub (&$;%) {
        my ($code, $deadline) = @_;
        push @deadlines, $deadline;
        my $response = $code->();
        return Promise->reject('session creation deadline')
            if $mode eq 'deadline' || ($mode eq 'delayed' && $deadline < 22);
        return $response;
      };
      local *Web::Transport::BasicClient::new_from_url = sub { return $http };
      $wd->new_session (($mode eq 'default' ? () : (retry => $mode eq 'enabled' ? 1 : 0)),
          desired => {browserName => 'firefox'})->then
          (sub { $session = $_[0] }, sub { $error = $_[0] })->to_cv->recv;
    }
    is $wd->{posts}, 1, 'one session-creation POST, including ambiguous failures';
    is_deeply \@deadlines, [$mode eq 'default' || $mode eq 'enabled' ? 20 : 180],
        'opt-in uses the overall deadline; default per-attempt behavior is unchanged';
    is $wd->{args}->{capabilities}->{alwaysMatch}->{browserName}, 'firefox',
        'browser capabilities are preserved';
    if ($mode eq 'normal' || $mode eq 'delayed' || $mode eq 'default' || $mode eq 'enabled') {
      ok $session, 'the caller owns the successful session';
      is $error, undef, 'success is not discarded';
      $session->close->to_cv->recv if $session;
      is $wd->{deletes}, 1, 'normal teardown closes the session';
      is_deeply $wd->{deleted_path}, ['session', 'owned-session'], 'only the owned session is deleted';
      is $wd->{active}, 0, 'no session is orphaned';
      is $http->{aborts}, 0, 'a successful response is not interrupted';
    } else {
      ok !defined $session, 'no successful session is fabricated';
      ok $error, 'failure remains visible';
      is $wd->{deletes}, 0, 'an unknown session ID is never guessed';
      is $http->{aborts}, $mode eq 'protocol-error' ? 0 : 1,
          'an interrupted request is aborted without replay';
    }
    $wd->close->to_cv->recv;
  };
}
done_testing;
