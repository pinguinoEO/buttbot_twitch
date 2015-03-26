#!/usr/bin/env perl

use strict;
use warnings;

use POE;
use POE::Component::Server::TCP;

use Butts;
# search $PATH by default.
my $fortune = 'fortune';

# Start a TCP server.  Client input will be logged to the console and
# echoed back to the client, one line at a time.
my $butter = Butts->new();

POE::Component::Server::TCP->new
  (
   Alias       => "echo_server",
   Port        => $ARGV[0] // 1096,
   ClientInput => sub {
       $_[KERNEL]->yield('shutdown');
   },
   ClientConnected => sub {
       my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
       #print "Session ", $session->ID(), " got input: $input\n";

       my $fortune_str = qx/$fortune/; # ick. But Fortune.pm is shit.
       $heap->{client}->put($butter->buttify_string($fortune_str));
       $kernel->yield("shutdown");
   }
  );

# Start the server.
$poe_kernel->run();
exit 0;
