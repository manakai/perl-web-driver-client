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
    '/foo.html' => (encode_web_utf8 '<html><title>Test</title><body>' . $body),
  }, sub {
    my $url = shift;
    my $go_url = Web::URL->parse_string ('/foo.html?%FE%81#%12%EE' . rand, $url);
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go ($go_url)->then (sub {
        my $res = $_[0];
        test {
          is $res, undef;
        } $c;
        return $session->url;
      })->then (sub {
        my $result = $_[0];
        test {
          isa_ok $result, 'Web::URL';
          is $result->stringify, $go_url->stringify;
        } $c;
      });
    });
  });
} n => 3, name => '->go, ->url';

test {
  my $c = shift;
  my $go_url = Web::URL->parse_string ('about:blank');
  my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
  return promised_cleanup {
    done $c;
    undef $c;
  } promised_cleanup {
    return $wd->close;
  } $wd->new_session->then (sub {
    my $session = $_[0];
    return promised_cleanup {
      return $session->close;
    } $session->go ($go_url)->then (sub {
      my $res = $_[0];
      test {
        is $res, undef;
      } $c;
      return $session->url;
    })->then (sub {
      my $result = $_[0];
      test {
        isa_ok $result, 'Web::URL';
        is $result->stringify, $go_url->stringify;
      } $c;
    });
  });
} n => 3, name => 'about:blank';

run_tests;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
