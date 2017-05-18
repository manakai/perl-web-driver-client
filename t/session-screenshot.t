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
    '/index.html' => (encode_web_utf8 '<html><title>Test</title><body>' . rand),
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
        return $session->screenshot;
      })->then (sub {
        my $result = $_[0];
        test {
          like $result, qr{^\x89PNG};
        } $c;
      });
    });
  });
} n => 1, name => 'window screenshot';

test {
  my $c = shift;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/index.html' => (encode_web_utf8 '<p>abcde<p>xyabcd'),
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
        return $session->screenshot (selector => 'p + p');
      })->then (sub {
        my $result = $_[0];
        test {
          like $result, qr{^\x89PNG};
          my $path = path (__FILE__)->parent->parent->child ('local/hogfe.png');
          $path->spew ($result);
        } $c;
      });
    });
  });
} n => 1, name => 'element screenshot';

run_tests;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
