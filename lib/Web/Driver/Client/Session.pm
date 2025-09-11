package Web::Driver::Client::Session;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use MIME::Base64;
use Web::URL;
use Web::Driver::Client::Response;

push our @CARP_NOT, qw(Web::Driver::Client::Connection);

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
  return Promise->resolve->then (sub {
    my $timeout = (defined $args{timeout} ? $args{timeout} : 30)*1000;
    if (not defined $self->{async_script_timeout} or
        $self->{async_script_timeout} != $timeout) {
      return $self->http_post (['timeouts'], {
        type => 'script',
        ms => $timeout,
      })->then (sub {
        die $_[0] if $_[0]->is_error;
        $self->{async_script_timeout} = $timeout;
      });
    }
  })->then (sub {
    return $self->http_post (['execute', 'async'], {
      script => q{
        Promise.resolve().then(()=>{
          return (new Function(arguments[0])).apply(null,arguments[1]);
        }).then ((r)=>{
          return[0,r];
        },(e)=>{
          if(e instanceof Error || e instanceof window.Error){
            return[1,{name:e.name,message:e.message,stack:e.stack}];
          }else{
            return[2,e];
          }
        }).then(arguments[2]);
      },
      args => [$script, $args || []],
    });
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    my $value = $res->json->{value};
    if (not defined $value or not defined $value->[0]) {
      $res->mark_as_error;
      die $res;
    }
    if ($value->[0] == 0) {
      return Web::Driver::Client::Response->new_from_json
          ({value => $value->[1]});
    } elsif ($value->[0] == 1) {
      die Web::Driver::Client::Response->new_from_json
          ({status => 400, # something not zero
            value => {error => "JavaScript Error",
                      js_error => $value->[1]}});
    } else { # $value->[0] == 2
      die Web::Driver::Client::Response->new_from_json
          ({status => 400, # something not zero
            value => {error => "Thrown",
                      message => $value->[1]}});
    }
  });
} # execute

sub get_all_cookies ($) {
  my ($self) = @_;
  return $self->http_get (['cookie'])->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return [map {
      $_->{httponly} = delete $_->{httpOnly};
      $_;
    } @{$res->json->{value}}];
  });
} # get_all_cookies

sub get_cookie ($$) {
  my ($self, $name) = @_;
  return $self->http_get (['cookie', $name])->then (sub {
    my $res = $_[0];
    return [] if $res->is_no_such_cookie_error;
    die $res if $res->is_error;
    my $v = $res->json->{value};
    return [map {
      $_->{httponly} = delete $_->{httpOnly};
      $_;
    } @{ref $v eq 'HASH' ? [$v] : $v}];
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
        return $self->execute (q{ document.cookie = arguments[0] }, [$cookie])->then (sub {
          return undef;
        });
      }
      die $res;
    }
    return undef;
  });
} # set_cookie

sub delete_all_cookies ($) {
  my $self = shift;
  return $self->http_delete (['cookie'], {
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
  });
} # delete_all_cookies

sub _select ($$) {
  my ($self, $selector) = @_;
  return $self->execute (q{
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

sub switch_to_top_frame ($) {
  my ($self) = @_;
  return $self->http_post (['frame'], {id => undef})->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return undef;
  });
} # switch_to_top_frame

sub text_content ($;%) {
  my ($self, %args) = @_;
  return Promise->resolve->then (sub {
    if (defined $args{selector}) {
      return $self->_select ($args{selector})->then (sub {
        return undef unless defined $_[0];
        return $self->execute (q{ return arguments[0].textContent }, [$_[0]]);
      });
    } else {
      return $self->execute (q{ return document.documentElement ? document.documentElement.textContent : '' });
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
        return $self->execute (q{ return arguments[0].innerHTML }, [$_[0]]);
      });
    } else {
      return $self->execute (q{ return document.documentElement ? document.documentElement.outerHTML : '' });
    }
  })->then (sub {
    my $res = $_[0];
    return undef unless defined $res;
    return $res->json->{value};
  });
} # inner_html

sub set_window_dimension ($$$) {
  my ($self, $width, $height) = @_;
  return $self->http_post (['window', 'rect'], {
    width => $width,
    height => $height,
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return undef;
  });
} # set_window_dimension

sub screenshot ($;%) {
  my ($self, %args) = @_;
  return Promise->resolve->then (sub {
    if (defined $args{element}) {
      return $self->http_get (['element', $args{element}->{'element-6066-11e4-a52e-4f735466cecf'} || $args{element}->{ELEMENT}, 'screenshot'])->then (sub {
        my $res = $_[0];
        if ($res->is_no_command_error) {
          carp "Element screenshot is not supported by the WebDriver server";
          return $self->http_get (['screenshot']);
        }
        return $res;
      });
    } elsif (defined $args{selector}) {
      return $self->_select ($args{selector})->then (sub {
        die "Selector |$args{selector}| selects no element"
            unless defined $_[0];
        return $self->http_get (['element', $_[0]->{'element-6066-11e4-a52e-4f735466cecf'} || $_[0]->{ELEMENT}, 'screenshot']);
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

sub click ($$) {
  my ($self, $element) = @_;
  return $self->http_post (['element', $element->{'element-6066-11e4-a52e-4f735466cecf'} || $element->{ELEMENT}, 'click'], {})->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return undef;
  });
} # click

sub value ($$$) {
  my ($self, $element, $value) = @_;
  return $self->http_post (['element', $element->{'element-6066-11e4-a52e-4f735466cecf'} || $element->{ELEMENT}, 'value'], {
    text => '' . $value,
    value => [split //, $value], # old
  })->then (sub {
    my $res = $_[0];
    die $res if $res->is_error;
    return undef;
  });
} # value

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

Copyright 2016-2021 Wakaba <wakaba@suikawiki.org>.

Copyright 2017 OND Inc. <https://ond-inc.com/>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
