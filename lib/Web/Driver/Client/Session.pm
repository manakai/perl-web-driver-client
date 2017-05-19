package Web::Driver::Client::Session;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use MIME::Base64;
use Web::URL;
use Web::Driver::Client::Response;

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

sub _execute ($$;$) {
  my ($self, $code, $args) = @_;
  return $self->http_post (['execute'], {
    script => $code,
    args => $args || [],
  })->then (sub {
    die $_[0] if $_[0]->is_error;
    return $_[0];
  });
} # _execute

sub execute ($$$;%) {
  my ($self, $script, $args, %args) = @_;
  return Promise->resolve->then (sub {
    return $self->{has_promise_execute} if defined $self->{has_promise_execute};
    return $self->_execute (q{
      return Promise.resolve ().then (function () { return 4 });
    })->then (sub {
      my $res = $_[0];
      return $self->{has_promise_execute} = 0
          unless ($res->json->{value} eq 4);
      return $self->http_post (['execute'], {
        script => q{ return Promise.reject (6) },
        args => [],
      })->then (sub {
        my $res = $_[0];
        if ($res->is_error and
            defined $res->json and
            ref $res->json eq 'HASH' and
            defined $res->json->{value} and
            ref $res->json->{value} eq 'HASH' and
            defined $res->json->{value}->{error} and
            $res->json->{value}->{error} eq 6) {
          return $self->{has_promise_execute} = 1;
        } else {
          return $self->{has_promise_execute} = 0;
        }
      });
    });
  })->then (sub {
    if ($_[0]) {
      return $self->_execute ($script, $args);
    } else {
      return $self->http_post (['execute_async'], {
        script => q{
          var code = new Function (arguments[0]);
          var args = arguments[1];
          var callback = arguments[2];
          Promise.resolve ().then (function () {
            return code.apply (null, args);
          }).then (function (r) {
            callback ([true, r]);
          }, function (e) {
            callback ([false, e]);
          });
        },
        args => [$script, $args || []],
      })->then (sub {
        my $res = $_[0];
        die $res if $res->is_error;
        my $value = $res->json->{value};
        if ($value->[0]) {
          return Web::Driver::Client::Response->new_from_json
              ({value => $value->[1]});
        } else {
          die Web::Driver::Client::Response->new_from_json
              ({status => 400, # something not zero
                value => {error => "javascript error",
                          message => $value->[1]}});
        }
      });
    }
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
    if ($res->is_error) {
      my $json = $res->json;
      if (defined $json->{value}->{message} and
          $json->{value}->{message} =~ /^You may only set cookies on HTML documents/) {
        ## GeckoDriver :-<

        ## Note that $name, $value, $args{$key} are not validated!
        my $cookie = $name . '=' . $value;
        for my $key (qw(path domain)) {
          if (defined $args{$key}) {
            $cookie .= '; ' . $key . '=' . $args{$key};
          }
        }
        if ($args{secure}) {
          $cookie .= '; Secure';
        }
        if ($args{httponly} or $args{httpOnly}) {
          $cookie .= '; HttpOnly';
        }
        if ($args{max_age}) {
          $cookie .= '; Max-Age=' . 0+$args{max_age};
        }
        return $self->_execute (q{ document.cookie = arguments[0] }, [$cookie])->then (sub {
          return undef;
        });
      }
      die $res;
    }
    return undef;
  });
} # set_cookie

sub _select ($$) {
  my ($self, $selector) = @_;
  return $self->_execute (q{
    return document.querySelector (arguments[0]);
  },  [$selector])->then (sub {
    my $json = $_[0]->json;
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

sub text_content ($;%) {
  my ($self, %args) = @_;
  return Promise->resolve->then (sub {
    if (defined $args{selector}) {
      return $self->_select ($args{selector})->then (sub {
        return undef unless defined $_[0];
        return $self->_execute (q{ return arguments[0].textContent }, [$_[0]]);
      });
    } else {
      return $self->_execute (q{ return document.documentElement ? document.documentElement.textContent : '' });
    }
  })->then (sub {
    my $res = $_[0];
    return undef unless defined $res;
    return $res->json->{value};
  });
} # text_content

sub inner_html ($;%) {
  my ($self, %args) = @_;
  return Promise->resolve->then (sub {
    if (defined $args{selector}) {
      return $self->_select ($args{selector})->then (sub {
        return undef unless defined $_[0];
        return $self->_execute (q{ return arguments[0].innerHTML }, [$_[0]]);
      });
    } else {
      return $self->_execute (q{ return document.documentElement ? document.documentElement.outerHTML : '' });
    }
  })->then (sub {
    my $res = $_[0];
    return undef unless defined $res;
    return $res->json->{value};
  });
} # inner_html

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
    return decode_base64 $res->json->{value};
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
