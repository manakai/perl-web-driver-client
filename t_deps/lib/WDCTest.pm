package WDCTest;
use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->parent->child ('t_deps/modules/*/lib');
use Carp;
use Test::X1;
use Test::More;
use Time::HiRes qw(time);
use Promised::Flow;
use Web::Encoding;
use Web::URL;
use Web::Driver::Client::Connection;

my $WD_URL = Web::URL->parse_string ($ENV{TEST_WD_URL})
    or die "Environment variable |TEST_WD_URL| is not specified";

our @EXPORT = (grep { not /^\$/ }
               @Web::Encoding::EXPORT, @Test::More::EXPORT, @Test::X1::EXPORT,
               @Promised::Flow::EXPORT,
               'time');

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

push @EXPORT, qw(wd_url);
sub wd_url () {
  return $WD_URL;
} # wd_url

{
  use Socket;
  my $EphemeralStart = 1024;
  my $EphemeralEnd = 5000;

  sub is_listenable_port ($) {
    my $port = $_[0];
    return 0 unless $port;
    
    my $proto = getprotobyname('tcp');
    socket(my $server, PF_INET, SOCK_STREAM, $proto) || die "socket: $!";
    setsockopt($server, SOL_SOCKET, SO_REUSEADDR, pack("l", 1)) || die "setsockopt: $!";
    bind($server, sockaddr_in($port, INADDR_ANY)) || return 0;
    listen($server, SOMAXCONN) || return 0;
    close($server);
    return 1;
  } # is_listenable_port

  my $using = {};
  sub find_listenable_port () {
    for (1..10000) {
      my $port = int rand($EphemeralEnd - $EphemeralStart);
      next if $using->{$port}++;
      return $port if is_listenable_port $port;
    }
    die "Listenable port not found";
  } # find_listenable_port
}

use AnyEvent;
use AnyEvent::Socket qw(tcp_server);
use Web::Transport::PSGIServerConnection;
sub psgi_server ($$) {
  my $app = shift;
  my $cb = shift;
  return Promise->new (sub {
    my ($ok, $ng) = @_;
    my $cv = AE::cv;
    $cv->begin;
    my $host = $ENV{TEST_SERVER_LISTEN_HOST} || '127.0.0.1';
    my $port = find_listenable_port;
    my $con;
    my $server = tcp_server $host, $port, sub {
      $cv->begin;
      $con = Web::Transport::PSGIServerConnection->new_from_app_and_ae_tcp_server_args
          ($app, [@_]);
      promised_cleanup { $cv->end } $con->completed;
    };
    $cv->cb ($ok);
    $host = $ENV{TEST_SERVER_HOSTNAME} || $host;
    my $origin = Web::URL->parse_string ("http://$host:$port");
    my $close = sub { undef $server; $cv->end };
    $cb->($origin, $close);
  });
} # psgi_server

push @EXPORT, qw(server);
sub server ($$) {
  my ($defs, $cb) = @_;
  return psgi_server (sub {
    my $env = $_[0];
    my $body = $defs->{$env->{PATH_INFO}};
    if (defined $body) {
      my $headers = [];
      if ($env->{PATH_INFO} =~ /\.html\z/) {
        push @$headers, 'content-type','text/html;charset=utf-8';
      } elsif ($env->{PATH_INFO} =~ /\.txt\z/) {
        push @$headers, 'content-type','text/plain;charset=utf-8';
      }
      $body =~ s/\@\@ENV:(\w+)\@\@/$env->{$1}/g;
      return [200, $headers, [$body]];
    } else {
      return [404, [], ['404 not found']];
    }
  }, sub {
    my ($url, $close) = @_;
    return promised_cleanup {
      $close->();
    } Promise->resolve ($url)->then ($cb);
  });
} # server

push @EXPORT, qw(generate_text);
sub generate_text () {
  my $v = rand;
  $v .= chr int rand 0x10FFFF for 3..(3 + rand 10);
  return decode_web_utf8 encode_web_utf8 $v;
} # generate_text

1;

=head1 LICENSE

Copyright 2016-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
