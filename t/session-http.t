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
        return $session->http_post (['element'], {
          using => 'xpath',
          value => '//body',
        });
      })->then (sub {
        my $res = $_[0];
        test {
          isa_ok $res, 'Web::Driver::Client::Response';
          ok !$res->is_error, 'Not error response';
          my $value = $res->json->{value};

          # The web element identifier is a constant with the string "element-6066-11e4-a52e-4f735466cecf".
          # See : https://www.w3.org/TR/webdriver/#dfn-web-element-identifier
          my $web_element_identifier = 'element-6066-11e4-a52e-4f735466cecf';
          # In Json Wire Protocol, "ELEMENT" is used.
          # See : https://github.com/SeleniumHQ/selenium/wiki/JsonWireProtocol#webelement-json-object
          my $web_element_identifier_for_jwp = 'ELEMENT';

          ok exists($value->{$web_element_identifier}) || exists($value->{$web_element_identifier_for_jwp}),
              'Response of `http_post` method contains a return value of command. ' .
              '(In this case that is JSON serialization of an element.)';
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
} n => 5, name => 'http_* API';

run_tests;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.
Copyright 2018 OND Inc. <https://ond-inc.com/>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
