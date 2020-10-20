use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use WDCTest;

test {
  my $c = shift;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/index.html' => (encode_web_utf8 q{<p onclick="textContent='def'">abc}),
  }, sub {
    my $url = shift;
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go (Web::URL->parse_string ('/index.html', $url))->then (sub {
        return $session->set_window_dimension (800, 600);
      })->then (sub {
        my $result = $_[0];
        test {
          is $result, undef;
        } $c;
        return $session->http_get (['window', 'rect']);
      })->then (sub {
        my $res = $_[0];
        test {
          is $res->json->{value}->{width}, 800;
          is $res->json->{value}->{height}, 600;
        } $c;
      });
    });
  });
} n => 3, name => 'set_window_dimension';

run_tests;

=head1 LICENSE

Copyright 2016-2020 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
