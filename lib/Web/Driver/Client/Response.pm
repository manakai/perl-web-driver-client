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
  return 1 if $_[0]->is_network_error;
  return 1 if defined $_[0]->{response} and not $_[0]->{response}->is_success;
  my $json = $_[0]->json;
  if (defined $json and defined $json->{status}) {
    return 1 if $json->{status} != 0;
  }
  return 0;
} # is_error

sub is_no_command_error ($) {
  return 0 unless $_[0]->is_error;
  return 0 if not defined $_[0]->{response};
  return $_[0]->{response}->status == 404;
} # is_no_command_error

sub stringify ($) {
  my $self = $_[0];
  if ($self->is_error) {
    my $json = $self->json;
    if (defined $json) {
      my $value = $json->{value};
      if (defined $value and ref $value eq 'HASH' and
          defined $value->{message}) {
        if (defined $value->{error}) {
          return "Error $value->{error}: $value->{message}";
        } else {
          return "Error: $value->{message}";
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

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
