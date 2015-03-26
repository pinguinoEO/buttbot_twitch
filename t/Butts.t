use strict;
use warnings;

use Test::More tests => 125;

BEGIN { use_ok('Butts'); }

my $meme = "butt";
my $butter = Butts->new(meme => $meme, debug => 1);

isa_ok($butter, 'Butts', 'butter Object');
can_ok($butter, qw(buttify buttify_string meme));

is($butter->meme, $meme, 'fetching meme');

my $meme2 = "bacon";
is($butter->meme($meme2), $meme2, 'changing meme');

# set it back
$butter->meme($meme);

my @buttify_data = qw(The rain in Spain falls mainly on the plain.);

for (1 .. 100) {
  my @output = $butter->buttify(@buttify_data);
  {
    local $" = ' ';
    print "@output\n";
  }

  my $has_butt = grep { /\Q$meme\E/i } @output;
  ok($has_butt, 'buttify array has butt');
}

my $buttify_str_sample = "An idle hand is worth two in the bush\n";

for (1 .. 10) {
    my $output = $butter->buttify_string($buttify_str_sample);
    #print $output, $/;
    like( $output, qr/\Q$meme\E/i, 'buttify_string has butt');
}

my $long_str_sample
  = "The alias-rejection-mixture method is a general and exact method for the "
  . "computer generation of random variables from an arbitrary discrete, "
  . "continuous, or mixed probability distribution.";

for (1..10) {
    my $output = $butter->buttify_string($long_str_sample);
    #print $output, $/;
    like( $output, qr/\Q$meme\E.*?\Q$meme\E/i, 'buttify_string has double-butt');
}
