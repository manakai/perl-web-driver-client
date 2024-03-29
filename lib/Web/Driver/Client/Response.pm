package Web::Driver::Client::Response;
use strict;
use warnings;
our $VERSION = '1.0';
use JSON::PS;
use overload '""' => 'stringify', fallback => 1;

sub new_from_response ($$) {
  return bless {response => $_[1]}, $_[0];
} # new_from_response

sub new_from_json ($$) {
  return bless {json => $_[1]}, $_[0];
} # new_from_json

sub is_network_error ($) {
  return 0 unless defined $_[0]->{response};
  return $_[0]->{response}->is_network_error;
} # is_network_error

sub json ($) {
  return $_[0]->{json} if exists $_[0]->{json};
  return $_[0]->{json} = undef if $_[0]->is_network_error;
  my $mime = $_[0]->{response}->header ('Content-Type') || '';
  $mime =~ tr/A-Z/a-z/;
  return $_[0]->{json} = undef
      if not $mime =~ m{\Aapplication/json\s*(?:;|$)};
  return $_[0]->{json} = json_bytes2perl $_[0]->{response}->body_bytes;
} # json

sub is_error ($) {
  return 1 if $_[0]->{is_error};
  return 1 if $_[0]->is_network_error;
  return 1 if defined $_[0]->{response} and not $_[0]->{response}->is_success;
  my $json = $_[0]->json;
  if (defined $json and defined $json->{status}) {
    return 1 if $json->{status} != 0;
  }
  return 0;
} # is_error

sub mark_as_error ($) {
  $_[0]->{is_error} = 1;
} # mark_as_error

## ChromeDriver (unknown command):
## Status: 404
## Content-Type: text/plain
##
## unknown command: {path}
##
## GeckoDriver (no such element):
## Status: 404
##
## {"value":{"error":"no such element","message":"Web element reference not seen before: {element id}...
sub is_no_command_error ($) {
  return 0 unless $_[0]->is_error;

  my $res = $_[0]->{response};
  return 0 if not defined $res;
  return 0 unless $res->status == 404;

  my $json = $_[0]->json;
  return 1 if not defined $json;

  my $error = eval { $json->{value}->{error} } // '';
  return 1 if $error eq '';
  return $error eq 'unknown command';
} # is_no_command_error

sub is_no_such_cookie_error ($) {
  return 0 unless $_[0]->is_error;
  return 0 if not defined $_[0]->{response};

  ## Spec & GeckoDriver
  return 1 if $_[0]->{response}->status == 404 &&
              $_[0]->json->{value}->{error} eq 'no such cookie';

  ## ChromeDriver
  return 1 if $_[0]->{response}->status == 200 &&
              defined $_[0]->json->{value} &&
              ref $_[0]->json->{value} eq 'HASH' &&
              $_[0]->json->{value}->{message} =~ /^no such cookie\n  \(Session info: chrome=/;

  return 0;
} # is_no_such_cookie_error

sub stringify ($) {
  my $self = $_[0];
  if ($self->is_error) {
    my $json = $self->json;
    if (defined $json) {
      my $value = $json->{value};
      if (defined $value and ref $value eq 'HASH') {
        if (defined $value->{error} and
            $value->{error} eq 'JavaScript Error') {
          my $e = $value->{js_error};
          my $m = $e->{stack};
          unless ($m =~ /^\Q@{[$e->{name}]}\E: \Q@{[$e->{message}]}\E/) {
            $m = "$e->{name}: $e->{message} at $m";
          }
          return $m;
        } elsif (defined $value->{message}) {
          if (defined $value->{error}) {
            my $m = $value->{message};
            if ($value->{error} eq 'Thrown' and ref $m) {
              $m = perl2json_chars $m;
            }
            return "Error $value->{error}: $m";
          } else {
            return "Error: $value->{message}";
          }
        }
      }
    }
    return 'Error' unless defined $self->{response};
    return 'Error: ' . $self->{response};
  }
  return 'OK';
} # stringify

1;

=head1 LICENSE

Copyright 2016-2020 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
