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
    } $wd->new_session (desired => {})->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go (Web::URL->parse_string ('/index.html', $url))->then (sub {
        return $session->execute (q{
          return document.body.textContent;
        });
      })->then (sub {
        my $res = $_[0];
        my $value = $res->json->{value};
        test {
          is $value, $body;
        } $c;
      });
    });
  });
} n => 1, name => 'direct access';

test {
  my $c = shift;
  my $host = rand . '.test';
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/host.html' => '<html><title>Test</title><body>@@ENV:HTTP_HOST@@',
  }, sub {
    my $url = shift;
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session (desired => {
      proxy => {proxyType => 'manual',
                httpProxy => $url->hostport,
                httpProxyPort => $url->port},
    })->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go (Web::URL->parse_string ("http://$host/host.html"))->then (sub {
        return $session->execute (q{
          return document.body.textContent;
        });
      })->then (sub {
        my $res = $_[0];
        my $value = $res->json->{value};
        test {
          is $value, $host;
        } $c;
      });
    });
  });
} n => 1, name => 'proxy access';

run_tests;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
