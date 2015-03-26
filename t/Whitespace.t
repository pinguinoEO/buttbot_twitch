use strict;
use warnings;

use Test::More tests => 13;

BEGIN { use_ok('Butts'); }

foreach my $test_str (<DATA>) {
    chomp($test_str);
    my ($l, $words, $ws) = Butts::split_preserving_whitespace($test_str);
    my $recovered_str = Butts::reassemble_with_whitespace($l, $words, $ws);
    cmp_ok($recovered_str, 'eq', $test_str);
}

__DATA__
normal spaced string
 leading space
trailing space 
some  extra   inner space
 leading  and   weird-sp-ace
 leading and trailing 
 leading and  weird in       ner
   lots     of    space    
   
!!!  
   ! !! @%@£
 !! ; $$$ 55    5	fff
