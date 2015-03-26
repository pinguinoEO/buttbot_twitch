#!/usr/bin/env perl

use strict;
use warnings;

use POE;
use POE::Component::Server::TCP;

use Butts;

# Start a TCP server.  Client input will be logged to the console and
# echoed back to the client, one line at a time.
my $butter = Butts->new();

POE::Component::Server::TCP->new
  (
   Alias       => "echo_server",
   Port        => $ARGV[0] // 1095,
   ClientInput => sub {
       my ($session, $heap, $input) = @_[SESSION, HEAP, ARG0];
       #print "Session ", $session->ID(), " got input: $input\n";
       $heap->{client}->put($butter->buttify_string($input));
   }
  );

# Start the server.
$poe_kernel->run();
exit 0;
