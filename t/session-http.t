use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use WDCTest;

test {
  my $c = shift;
  my $body = "\x{5323}" . rand;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/index.html' => (encode_web_utf8 '<html><title>Test</title><body>' . $body),
  }, sub {
    my $url = shift;
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->http_post (['url'], {
        url => Web::URL->parse_string ('/index.html', $url)->stringify,
      })->then (sub {
        my $res = $_[0];
        test {
          isa_ok $res, 'Web::Driver::Client::Response';
        } $c;
        return $session->http_post (['execute'], {
          script => q{
            return document.body.textContent;
          },
          args => [],
        });
      })->then (sub {
        my $res = $_[0];
        test {
          isa_ok $res, 'Web::Driver::Client::Response';
          my $value = $res->json->{value};
          is $value, $body;
        } $c;
        return $session->http_get (['url']);
      })->then (sub {
        my $res = $_[0];
        test {
          is $res->json->{value}, Web::URL->parse_string ('/index.html', $url)->stringify;
        } $c;
      });
    });
  });
} n => 4, name => 'http_* API';

run_tests;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
