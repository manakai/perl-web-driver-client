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
    '/index.html' => (encode_web_utf8 '<title>y</title><p>abcde<p>xyabcd'),
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
        return $session->text_content (selector => 'p + p');
      })->then (sub {
        my $result = $_[0];
        test {
          is $result, 'xyabcd';
        } $c;
        return $session->text_content (selector => 'p + p + p');
      })->then (sub {
        my $result = $_[0];
        test {
          is $result, undef;
        } $c;
        return $session->text_content;
      })->then (sub {
        my $result = $_[0];
        test {
          is $result, 'yabcdexyabcd';
        } $c;
      });
    });
  });
} n => 3, name => 'document and element text content';

test {
  my $c = shift;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/index.html' => (encode_web_utf8 '<title>y</title><p>abcde<p>xya<i>b</i>cd'),
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
        return $session->inner_html (selector => 'p + p');
      })->then (sub {
        my $result = $_[0];
        test {
          is $result, 'xya<i>b</i>cd';
        } $c;
        return $session->inner_html (selector => 'p + p + p');
      })->then (sub {
        my $result = $_[0];
        test {
          is $result, undef;
        } $c;
        return $session->inner_html;
      })->then (sub {
        my $result = $_[0];
        test {
          is $result, '<html><head><title>y</title></head><body><p>abcde</p><p>xya<i>b</i>cd</p></body></html>';
        } $c;
      });
    });
  });
} n => 3, name => 'document and element inner html';

run_tests;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
