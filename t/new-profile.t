use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use WDCTest;

test {
  my $c = shift;
  my $name = rand;
  my $value = rand;
  return server ({
    '/foo/bar.html' => (encode_web_utf8 '<html><title>Test</title><body>' . rand),
  }, sub {
    my $url = shift;
    my $go_url = Web::URL->parse_string ('/foo/bar.html', $url);
    my $wd = Web::Driver::Client::Connection->new_from_url ($wd_url);
    my $profile_path = '/tmp/' . rand;
    return $wd->new_session (profile_dir => $profile_path)->then (sub {
      my $session = $_[0];
      return $session->go ($go_url)->then (sub {
        my $res = $_[0];
        return $session->set_cookie ($name => $value);
      })->finally (sub {
        return $session->close;
      });
    })->then (sub {
      return $wd->new_session (profile_dir => $profile_path);
    })->then (sub {
      my $session = $_[0];
      return $session->go ($go_url)->then (sub {
        return $session->get_cookie ($name);
      })->then (sub {
        my $values = $_[0];
        test {
          is 0+@$values, 1;
          is $values->[0]->{name}, $name;
          is $values->[0]->{value}, $value;
        } $c;
      })->finally (sub {
        return $session->close;
      });
    })->finally (sub {
      return $wd->close;
    });
  })->finally (sub {
    done $c;
    undef $c;
  });
} n => 3, name => 'cookie';

run_tests;

=head1 LICENSE

Copyright 2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
