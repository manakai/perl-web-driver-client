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

test {
  my $c = shift;
  my $body1 = "\x{5323}" . rand;
  my $body2 = "\x{5323}" . rand;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => (encode_web_utf8 '<iframe src=bar.html></iframe><p id=data>' . $body1),
    '/bar.html' => (encode_web_utf8 '<p id=data>' . $body2),
  }, sub {
    my $url = shift;
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go (Web::URL->parse_string ('/foo.html', $url))->then (sub {
        my $res = $_[0];
        test {
          is $res, undef;
        } $c;
        return $session->switch_to_frame_by_selector ('iframe');
      })->then (sub {
        my $result = $_[0];
        test {
          is $result, undef;
        } $c;
        return $session->execute (q{ return document.getElementById ('data').textContent });
      })->then (sub {
        my $res = $_[0];
        test {
          is $res->json->{value}, $body2;
        } $c;
      });
    });
  });
} n => 3, name => 'navigate to frame';

test {
  my $c = shift;
  my $body1 = "\x{5323}" . rand;
  my $body2 = "\x{5323}" . rand;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => (encode_web_utf8 '<iframe src=bar.html></iframe><p id=data>' . $body1),
    '/bar.html' => (encode_web_utf8 '<p id=data>' . $body2),
  }, sub {
    my $url = shift;
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go (Web::URL->parse_string ('/foo.html', $url))->then (sub {
        my $res = $_[0];
        test {
          is $res, undef;
        } $c;
        return $session->switch_to_frame_by_selector ('iframe[abc]');
      })->then (sub {
        test {
          ok 0, 'Should be rejected';
        } $c;
      }, sub {
        my $error = $_[0];
        test {
          like $error, qr{^Selector \|iframe\[abc\]\| selects no element};
        } $c;
      });
    });
  });
} n => 2, name => 'navigate to frame - selector no match';

test {
  my $c = shift;
  my $body1 = "\x{5323}" . rand;
  my $body2 = "\x{5323}" . rand;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => (encode_web_utf8 '<iframe src=bar.html></iframe><p id=data>' . $body1),
    '/bar.html' => (encode_web_utf8 '<p id=data>' . $body2),
  }, sub {
    my $url = shift;
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      return promised_cleanup {
        return $session->close;
      } $session->go (Web::URL->parse_string ('/foo.html', $url))->then (sub {
        my $res = $_[0];
        test {
          is $res, undef;
        } $c;
        return $session->switch_to_frame_by_selector ('#data');
      })->then (sub {
        test {
          ok 0, 'Should be rejected';
        } $c;
      }, sub {
        my $error = $_[0];
        test {
          isa_ok $error, 'Web::Driver::Client::Response';
          ok $error->is_error;
        } $c;
      });
    });
  });
} n => 3, name => 'navigate to frame - selector selects non frame';

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
        return $session->set_cookie ($name => $value, max_age => 3);
      })->then (sub {
        return promised_sleep 6;
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

run_tests;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
