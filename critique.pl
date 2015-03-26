use strict;
use warnings;

use Perl::Critic;

my @FILES = qw(
  buttbot.pl
  Butts.pm
  t/Butts.t
  critique.pl
);

my $critic = new Perl::Critic;

for my $file (@FILES) {
  print "Critiquing $file...\n";
  print $critic->critique($file);
}