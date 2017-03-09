use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Web::URL;
use Web::Driver::Client::Connection;

my $WD_URL = Web::URL->parse_string ($ENV{TEST_WD_URL});

test {
  my $c = shift;

  my $wd = Web::Driver::Client::Connection->new_from_url ($WD_URL);

  $wd->new_session (desired => {})->then (sub {
    my $session = $_[0];
    return $session->go (Web::URL->parse_string (q<https://manakai.github.io>))->then (sub {
      return $session->execute (q{
        return document.documentElement.innerHTML;
      });
    })->then (sub {
      my $res = $_[0];
      my $value = $res->json->{value};
      test {
        like $value, qr{The manakai project};
      } $c;
    })->catch (sub {
      my $error = $_[0];
      test {
        is $error, undef, 'No exception';
      } $c;
    })->then (sub {
      return $session->close;
    });
  })->catch (sub {
    my $error = $_[0];
    test {
      is $error, undef, 'No exception';
    } $c;
  })->then (sub {
    return $wd->close;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => '/', timeout => 60*10;

test {
  my $c = shift;

  my $wd = Web::Driver::Client::Connection->new_from_url ($WD_URL);

  $wd->new_session (desired => {
    proxy => {proxyType => 'manual', httpProxy => 'http://manakai.github.io'},
  })->then (sub {
    my $session = $_[0];
    return $session->go (Web::URL->parse_string (q<http://manakai.github.io>))->then (sub {
      return $session->execute (q{
        return document.documentElement.innerHTML;
      });
    })->then (sub {
      my $res = $_[0];
      my $value = $res->json->{value};
      test {
        like $value, qr{The manakai project};
      } $c;
    })->catch (sub {
      my $error = $_[0];
      test {
        is $error, undef, 'No exception';
      } $c;
    })->then (sub {
      return $session->close;
    });
  })->catch (sub {
    my $error = $_[0];
    test {
      is $error, undef, 'No exception';
    } $c;
  })->then (sub {
    return $wd->close;
  })->then (sub {
    done $c;
    undef $c;
  });
} n => 1, name => '/ with proxy', timeout => 60*10;

run_tests;

=head1 LICENSE

Copyright 2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
