use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use WDCTest;

test {
  my $c = shift;
  my $name = rand;
  my $value = rand;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo/bar.html' => (encode_web_utf8 '<html><title>Test</title><body>' . rand),
  }, sub {
    my $url = shift;
    my $go_url = Web::URL->parse_string ('/foo/bar.html', $url);
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go ($go_url)->then (sub {
        my $res = $_[0];
        return $session->set_cookie ($name => $value);
      })->then (sub {
        return $session->get_cookie ($name);
      })->then (sub {
        my $values = $_[0];
        test {
          is 0+@$values, 1;
          is $values->[0]->{name}, $name;
          is $values->[0]->{value}, $value;
        } $c;
        return $session->execute (q{
          return document.cookie;
        });
      })->then (sub {
        my $res = $_[0];
        test {
          is $res->json->{value}, $name . '=' . $value;
        } $c;
      });
    });
  });
} n => 4, name => 'cookie';

test {
  my $c = shift;
  my $name = rand;
  my $value = rand;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo/bar.html' => (encode_web_utf8 '<html><title>Test</title><body>' . rand),
  }, sub {
    my $url = shift;
    my $go_url = Web::URL->parse_string ('/foo/bar.html', $url);
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go ($go_url)->then (sub {
        my $res = $_[0];
        return $session->execute (q{
          document.cookie = 'abc=def';
          document.cookie = 'xya=abc def';
        });
      })->then (sub {
        return $session->get_all_cookies;
      })->then (sub {
        my $values = $_[0];
        test {
          is 0+@$values, 2;
          @$values = sort { $a->{name} cmp $b->{name} } @$values;
          is $values->[0]->{name}, 'abc';
          is $values->[0]->{value}, 'def';
          is $values->[1]->{name}, 'xya';
          is $values->[1]->{value}, 'abc def';
        } $c;
      });
    });
  });
} n => 5, name => 'get_all_cookies';

test {
  my $c = shift;
  my $name = rand;
  my $value = rand;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo/bar.html' => (encode_web_utf8 '<html><title>Test</title><body>' . rand),
  }, sub {
    my $url = shift;
    my $go_url = Web::URL->parse_string ('/foo/bar.html', $url);
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go ($go_url)->then (sub {
        my $res = $_[0];
        return $session->set_cookie ($name => $value, httponly => 1);
      })->then (sub {
        return $session->get_cookie ($name);
      })->then (sub {
        my $values = $_[0];
        test {
          is 0+@$values, 1;
          is $values->[0]->{name}, $name;
          is $values->[0]->{value}, $value;
          #ok $values->[0]->{httponly};
          #ok $values->[0]->{httpOnly};
        } $c;
        return $session->execute (q{
          return document.cookie;
        });
      })->then (sub {
        my $res = $_[0];
        test {
          #is $res->json->{value}, '';
        } $c;
      });
    });
  });
  ## ChromeDriver does not support httpOnly :-<
} n => 3 + 3*0, name => 'cookie httponly';

test {
  my $c = shift;
  my $name = rand;
  my $value = rand;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo/bar.html' => (encode_web_utf8 '<html><title>Test</title><body>' . rand),
  }, sub {
    my $url = shift;
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go (Web::URL->parse_string ('/foo/bar.html', $url))->then (sub {
        my $res = $_[0];
        return $session->set_cookie ($name => rand);
      })->then (sub {
        return $session->set_cookie ($name => $value, max_age => -3);
      })->then (sub {
        return $session->get_cookie ($name);
      })->then (sub {
        my $values = $_[0];
        test {
          is 0+@$values, 0;
        } $c;
      });
    });
  });
} n => 1, name => 'cookie max_age';

test {
  my $c = shift;
  my $name = rand;
  my $value = rand;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo/bar.txt' => rand,
  }, sub {
    my $url = shift;
    my $go_url = Web::URL->parse_string ('/foo/bar.txt', $url);
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go ($go_url)->then (sub {
        my $res = $_[0];
        return $session->set_cookie ($name => $value);
      })->then (sub {
        return $session->get_cookie ($name);
      })->then (sub {
        my $values = $_[0];
        test {
          is 0+@$values, 1;
          is $values->[0]->{name}, $name;
          is $values->[0]->{value}, $value;
        } $c;
        return $session->execute (q{
          return document.cookie;
        });
      })->then (sub {
        my $res = $_[0];
        test {
          is $res->json->{value}, $name . '=' . $value;
        } $c;
      });
    });
  });
} n => 4, name => 'cookie non-html';

run_tests;

=head1 LICENSE

Copyright 2016-2019 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
