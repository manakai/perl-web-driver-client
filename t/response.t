use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use WDCTest;

test {
  my $c = shift;
  my $res = Web::Driver::Client::Response->new_from_json ({});
  ok ! $res->is_error;
  is $res->stringify, 'OK';
  $res->mark_as_error;
  ok $res->is_error;
  is $res->stringify, 'Error';
  done $c;
} n => 4, name => 'mark_as_error';

run_tests;

=head1 LICENSE

Copyright 2021 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
