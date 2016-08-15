package Web::Driver::Client::Session;
use strict;
use warnings;

sub new_from_connection_and_session_id ($$$) {
  return bless {connection => $_[1], session_id => $_[2]}, $_[0];
} # new_from_connection_and_session_id

sub session_id ($) {
  return $_[0]->{session_id};
} # session_id

sub go ($$) {
  my ($self, $url) = @_;
  return $self->{connection}->http_post (['session', $self->{session_id}, 'url'], {
    url => (UNIVERSAL::isa ($url, 'Web::URL') ? $url->stringify : $url),
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
  });
} # go

sub execute ($$$;%) {
  my ($self, $script, $args, %args) = @_;
  return $self->{connection}->http_post (['session', $self->{session_id}, 'execute'], {
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
  return $self->{connection}->http_delete (['session', $self->{session_id}]);
} # close

1;
