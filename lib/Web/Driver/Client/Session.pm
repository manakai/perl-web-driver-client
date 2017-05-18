package Web::Driver::Client::Session;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use MIME::Base64;
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

sub get_cookie ($$) {
  my ($self, $name) = @_;
  return $self->http_get (['cookie', $name])->then (sub {
    my $res = $_[0];
    if ($res->is_no_command_error) {
      return $self->http_get (['cookie'])->then (sub {
        my $res = $_[0];
        die $res if $res->is_error;
        return [map {
          $_->{httponly} = delete $_->{httpOnly};
          $_;
        } grep { $_->{name} eq $name } @{$res->json->{value}}];
      });
    }
    die $res if $res->is_error;
    return [map {
      $_->{httponly} = delete $_->{httpOnly};
      $_;
    } @{$res->json->{value}}];
  });
} # get_cookie

sub set_cookie ($$$;%) {
  my ($self, $name, $value, %args) = @_;
  my $cookie = {
    name => ''.$name,
    value => ''.$value,
  };
  for my $key (qw(path domain)) {
    if (defined $args{$key}) {
      $cookie->{$key} = '' . $args{$key};
    }
  }
  if ($args{secure}) {
    $cookie->{secure} = \1;
  }
  if ($args{httponly} or $args{httpOnly}) {
    $cookie->{httpOnly} = \1;
  }
  if ($args{max_age}) {
    $cookie->{expiry} = time + $args{max_age};
  }
  return $self->http_post (['cookie'], {
    cookie => $cookie,
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return undef;
  });
} # set_cookie

sub _select ($$) {
  my ($self, $selector) = @_;
  return $self->execute (q{
    return document.querySelector (arguments[0]);
  },  [$selector])->then (sub {
    my $json = $_[0]->json;
    die $_[0] if $_[0]->is_error;
    return $json->{value};
  });
} # _select

sub switch_to_frame_by_selector ($$) {
  my ($self, $selector) = @_;
  return $self->_select ($selector)->then (sub {
    die "Selector |$selector| selects no element" if not defined $_[0];
    return $self->http_post (['frame'], {id => $_[0]});
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return undef;
  });
} # switch_to_frame_by_selector

sub screenshot ($;%) {
  my ($self, %args) = @_;
  return Promise->resolve->then (sub {
    if (defined $args{selector}) {
      return $self->_select ($args{selector})->then (sub {
        die "Selector |$args{selector}| selects no element"
            unless defined $_[0];
        return $self->http_get (['element', $_[0]->{ELEMENT}, 'screenshot']);
      })->then (sub {
        my $res = $_[0];
        if ($res->is_no_command_error) {
          carp "Element screenshot is not supported by the WebDriver server";
          return $self->http_get (['screenshot']);
        }
        return $res;
      });
    } else {
      return $self->http_get (['screenshot']);
    }
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    my $encoded = $res->json->{value};
    $encoded =~ s/^data:[^,]+,//;
    return decode_base64 $encoded;
  });
} # screenshot

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
