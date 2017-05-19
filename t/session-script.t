use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use WDCTest;

test {
  my $c = shift;
  my $text1 = generate_text;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => encode_web_utf8 ('<p>' . $text1 . '</p>' . generate_text),
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
        return $session->execute (q{ return document.querySelector ('p').textContent });
      })->then (sub {
        my $res = $_[0];
        test {
          isa_ok $res, 'Web::Driver::Client::Response';
          ok ! $res->is_error;
          is $res->json->{value}, $text1;
        } $c;
      });
    });
  });
} n => 3, name => 'execute';

test {
  my $c = shift;
  my $text1 = generate_text;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => encode_web_utf8 ('<p></p><p></p>'),
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
        return $session->execute (q{ return document.querySelector (arguments[0]).textContent = arguments[1] }, ['p+p', $text1]);
      })->then (sub {
        return $session->execute (q{ return document.querySelector (arguments[0].selector).textContent }, [{selector => 'p+p'}]);
      })->then (sub {
        my $res = $_[0];
        test {
          isa_ok $res, 'Web::Driver::Client::Response';
          ok ! $res->is_error;
          is $res->json->{value}, $text1;
        } $c;
      });
    });
  });
} n => 3, name => 'execute with arguments';

test {
  my $c = shift;
  my $text1 = generate_text;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => encode_web_utf8 ('<p>' . $text1 . '</p>' . generate_text),
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
        return $session->execute (q{
          return Promise.resolve ().then (function () {
            return document.querySelector ('p').textContent;
          });
        });
      })->then (sub {
        my $res = $_[0];
        test {
          isa_ok $res, 'Web::Driver::Client::Response';
          ok ! $res->is_error;
          is $res->json->{value}, $text1;
        } $c;
      });
    });
  });
} n => 3, name => 'execute promise';

test {
  my $c = shift;
  my $text1 = generate_text;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => encode_web_utf8 ('<p>' . $text1 . '</p>' . generate_text),
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
        return $session->execute (q{
          foo bar baz
        });
      })->then (sub {
        my $res = $_[0];
        test {
          ok 0, 'Exception expected';
        } $c;
      }, sub {
        my $error = $_[0];
        test {
          isa_ok $error, 'Web::Driver::Client::Response';
          ok $error->is_error;
          #warn $error;
        } $c;
      });
    });
  });
} n => 2, name => 'execute syntax error';

test {
  my $c = shift;
  my $text1 = generate_text;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => encode_web_utf8 ('<p>' . $text1 . '</p>' . generate_text),
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
        return $session->execute (q{
          throw "foo "+"bar "+"baz";
        });
      })->then (sub {
        my $res = $_[0];
        test {
          ok 0, 'Exception expected';
        } $c;
      }, sub {
        my $error = $_[0];
        test {
          isa_ok $error, 'Web::Driver::Client::Response';
          ok $error->is_error;
          like ''.$error, qr{foo bar baz};
        } $c;
      });
    });
  });
} n => 3, name => 'execute runtime error';

test {
  my $c = shift;
  my $text1 = generate_text;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => encode_web_utf8 ('<p>' . $text1 . '</p>' . generate_text),
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
        return $session->execute (q{
          return Promise.resolve ().then (function () {
            throw "foo "+"bar "+"baz";
          });
        });
      })->then (sub {
        my $res = $_[0];
        test {
          ok 0, 'Exception expected';
        } $c;
      }, sub {
        my $error = $_[0];
        test {
          isa_ok $error, 'Web::Driver::Client::Response';
          ok $error->is_error;
          like ''.$error, qr{foo bar baz};
        } $c;
      });
    });
  });
} n => 3, name => 'execute promise rejection';

test {
  my $c = shift;
  return promised_cleanup {
    done $c;
    undef $c;
  } server ({
    '/foo.html' => rand,
  }, sub {
    my $url = shift;
    my $wd = Web::Driver::Client::Connection->new_from_url (wd_url);
    return promised_cleanup {
      return $wd->close;
    } $wd->new_session->then (sub {
      my $session = $_[0];
      my $time1;
      return promised_cleanup {
        return $session->close;
      } $session->go (Web::URL->parse_string ('/foo.html', $url))->then (sub {
        $time1 = time;
        return $session->execute (q{
          return new Promise (function () { });
        }, [], timeout => 4);
      })->then (sub {
        my $res = $_[0];
        test {
          ok 0, 'Exception expected';
        } $c;
      }, sub {
        my $error = $_[0];
        my $elapsed = time - $time1;
        test {
          isa_ok $error, 'Web::Driver::Client::Response';
          ok $error->is_error;
          ok $elapsed > 3, "Elapsed time $elapsed (s)";
        } $c;
      });
    });
  });
} n => 3, name => 'execute promise timeout';

run_tests;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
