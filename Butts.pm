=head1 NAME

Butts - replace random syllables with the arbitrary memes.

=head1 SYNOPSIS

  # with all defaults
  my $butter = Butts->new;
  $butter->buttify_string("hello there");

  # with all known options
  my $butter = Butts->new(
      meme => 'butt',
      replace_freq => (1/11),
      debug => 0,
      hyphen_file => 'hyphens.tex',
      stopwords_file => 'stopwords',
  );

  $butter->buttify(@tokens);
  $butter->buttify_string($string);


=head1 DESCRIPTION

Yes.

=cut

=head1 CONSTRUCTOR

=over

=item C<new>

Takes a number of optional arguments:
    'debug', sets module debugging output on or off.
    'hyphen_file', specify a different hyphen file for L<TeX::Hyphen>,
                  defaults to C<$module_dir/hyphen.tex>.
    'stopwords_file', specify a different source of stopwords,
                      defaults to C<$module_dir/stopwords>.

=back

=cut

use strict;
use warnings;

{

    package Butts;

    use Moose;

    use Math::Random;
    use TeX::Hyphen;
    use Data::Dumper;
    use Dir::Self;
    use Carp;


    has 'replace_freq' =>
      (
       isa => 'Num',
       is  => 'rw',
       default => sub { 1/11 }
      );


    has 'meme' =>
      (
       isa      => 'Str',
       is       => 'rw',
       default  => sub { 'butt' },
       required => 1,
      );

    has 'hyphen_file' =>
      (
       isa     => 'Str',
       is      => 'ro',
       default => sub { __DIR__ . '/hyphen.tex' },
      );

    has 'stopwords_file' =>
      (
       isa     => 'Str',
       is      => 'ro',
       default => sub { __DIR__ . '/stopwords' },
      );

    has 'debug' =>
      (
       isa      => 'Bool',
       is       => 'rw',
       required => 1,
       default  => sub { 0 },
      );

    has 'hyphenator' =>
      (
       isa  => 'TeX::Hyphen',
       is   => 'ro',
       lazy => 1,
       builder => '_build_hyphenator',
      );

    has 'stopwords' => 
      (
       isa => 'HashRef[Str]',
       is => 'ro',
       lazy => 1,
       builder => '_build_stopwords',
      );

    has 'words' =>
      (
       isa     => 'ArrayRef[Str]',
       is      => 'ro',
       writer  => '_set_words',
       default => sub { [] },
      );

    has 'word_indices' =>
      (
       isa     => 'ArrayRef[Int]',
       is      => 'ro',
       default => sub { [] },
       writer  => '_set_word_indices',
      );


=head1 METHODS

=cut

    sub _build_hyphenator {
        my $self = shift;
        return TeX::Hyphen->new(file => $self->hyphen_file);
    }

    sub _build_stopwords {
        my $self = shift;
        my @stopwords;
        if (open my $sfh, $self->stopwords_file) {
            chomp(@stopwords = <$sfh>);
            close $sfh;
        } else {
            carp "Couldn't read stopwords file "
              . $self->stopwords_file . ' ' . $!;
            @stopwords = qw/a an and or but it in its It's it's the of you I i/;
        }

        return { map { lc($_) => 1 } @stopwords };
    }

=head2 meme($value)

Method which sets / returns the current replacement meme.  If called without
additional arguments, it returns the current meme. Calling it with a scalar
replaces the old meme with a new one.

=head2 replace_freq($value)

Getter/Setter Method for the replacement frequency.  Value should be passed as a
fractional value, which corresponds to the number of words considered for meme
replacement via the following calculation:

=head2 debug($value)

Turn debugging output on (C<1>) or off (C<0>).  Debugging output is printed to
C<STDERR>.

=cut

    # helpers
    sub is_stop_word {
        my ($self, $word) = @_;
        return exists $self->stopwords->{lc($word)};
    }
    sub is_url {
        my ($self, $word) = @_;
        return $word =~ /^https?:\/\//i;
    }

    sub is_meme {
        my ($self, $word) = @_;
        return lc($word) eq lc($self->meme);

    }

    sub _split_preserving_whitespace {
        my ($self, $string) = @_;

        my ($leading_ws, $remainder) = ($string =~ m/^(\s*)(.*)$/s);
        $leading_ws = defined $leading_ws ? $leading_ws : '';

        my @all_split = split(/(\s+)/, $remainder);
        my (@words, @ws);
        foreach my $tok (@all_split) {
            if ($tok =~ m/^\s+$/) {
                push @ws, $tok
            } else {
                push @words, $tok
            }
        }
        return ($leading_ws, \@words, \@ws);
    }


    sub _reassemble_with_whitespace {
        my ($self, $leading, $words, $ws) = @_;

        # interleave the two arrays. Words always come first, because
        # any leading space is in $leading.
        # http://www.perlmonks.org/?node_id=53605

        # if things are different sizes we'll end up with some undefs,
        # so grep them out.
        my @ret = grep { defined } map { $words->[$_], $ws->[$_] }
          0 .. ($#$words > $#$ws ? $#$words : $#$ws);
        # and convert back to a string.
        return $leading . join('', @ret);
    }

=head2 buttify_string

This method is the core of Butts.pm.  It takes a string argument (or defaults
to C<$_> if none is given, and returns a string in which random parts of words
have been replaced with the contents of C<$self-E<gt>meme>.

The original whitespace of the string is preserved as far as possible.

=cut

    sub buttify_string($_) {
        my $self = shift;
        # glom a string from $_ if we didn't get one passed.
        my $str = (@_ ? $_[0] : $_);
        chomp($str);

        # FIX for http://code.google.com/p/buttbot/issues/detail?id=7
        my ($leading, $words, $whitespace)
          = $self->_split_preserving_whitespace($str);

        my @butted_words = $self->buttify(@$words);

        return $self->_reassemble_with_whitespace($leading,
                                                  \@butted_words,
                                                  $whitespace);
    }

=head2 buttify(@words)

Operates in a similar fashion to L</buttify_string>, but should be passed a
pre-tokenised array of words.  It returns an array of equal length in which some
portion of (some of) the tokens have been replaced by the meme in
C<$self-E<gt>meme>.

=cut

    sub buttify {
        my ($self, @words) = @_;
        my $how_many_butts = int(@words * $self->replace_freq) + 1;
        my $debug = $self->debug;

        $self->_set_words(\@words);
        # sort indices by word length
        my @word_idxs_len_sorted = do {
            my $c;

            map  { $_->[0] }
            sort { $b->[1] <=> $a->[1] }
            map  { [$c++ , length($_) ] } @words;
        };

        # remove stop words
        @word_idxs_len_sorted = grep {
            my $word = $words[$_];

            my $is_word = $word !~ /^[\d\W+]+$/;
            my $is_stop = $self->is_stop_word($word);
            my $is_meme = $self->is_meme($word);
            my $is_url  = $self->is_url($word);

            $is_word and not $is_stop and not $is_meme and not $is_url;
        } @word_idxs_len_sorted;

        $self->_set_word_indices(\@word_idxs_len_sorted);

        # bail out if we've got nothing left. This happens
        # when a string is comprised entirely of stop-words.
        unless (@word_idxs_len_sorted) {
            $self->log("Couldn't buttify ", join(' ', @words),
                       ": entirely stopwords");
            return @words;
        }

        # make sure we're not trying to butt too hard.
        if ($how_many_butts > @word_idxs_len_sorted) {
            $how_many_butts = scalar(@word_idxs_len_sorted);
        }

        $self->log("buttifying with $how_many_butts repetitions");
        my $words_butted = {};
        my @initial_weights = _sq_weight_indices(scalar @word_idxs_len_sorted);

        # Selecting words to butt works in the following way:

        #  * each (non-stop) word-index is assigned a weighting based on it's
        #    ordinal when sorted by (word) length. So, the longest word has weight =
        #    num_words ** 2, second longest is (num_words-1)**2, ...

        #  * A random distribution selects some index proportional to its weight.
        #  * The word at this index is butted.
        #  * The index is removed from consideration for subsequent buttings.

        for my $c (0 .. $how_many_butts-1) {
            my ($xx_n, $xx_p, $xx_x)
              = $self->_build_weightings_for_index(\@initial_weights, $words_butted);

            my $random_idx  = get_walker_rand($xx_n, $xx_p, $xx_x);
            my $idx_to_butt = $word_idxs_len_sorted[$random_idx];

            $self->log("Butting word idx: $idx_to_butt [",
                       $words[$idx_to_butt], "]");

            $words[$idx_to_butt]
              = $self->_buttsub($words[$idx_to_butt]);

            $words_butted->{$random_idx} = 1;
        }

        return @words;
    }

    sub _find_repeating_vowel {
        my ($self, $word) = @_;
        my $vowels = "aeiouAEIOU";

        my $j = 0;
        my $j_record = 0;
        my $k_record = 0;
        while ($j < length($word)) {
            if (index($vowels, substr($word,$j,1)) > -1) {
                # $word[$j] is a vowel; how many times does it repeat?
                my $k = 0;
                do {
                    ++$k;
                } while (($j + $k < length($word)) && (substr($word,$j+$k,1) eq substr($word,$j,1)));
        # save the vowel that repeats most
                if ($k > $k_record) {
                    $j_record = $j;
                    $k_record = $k;
                }
            }
            ++$j;
        }
        return ($j_record, $k_record);
    }

    sub _buttsub {
        my ($self, $word) = @_;

        my $meme = $self->meme;

        # split off leading and trailing punctuation
        my ($lp, $actual_word, $rp) = $word =~ /^([^A-Za-z]*)(.*?)([^A-Za-z]*)$/;

        return $word unless $actual_word;

        my @points = (0, $self->hyphenator->hyphenate($actual_word));

        my $factor = 2;
        my $length = scalar @points;
        my $replace = $length - 1 - int(rand($length ** $factor) ** (1 / $factor));
        push @points, length($actual_word);

        my $l = $points[$replace];
        my $r = $points[$replace + 1] - $l;

        while (substr($actual_word, $l + $r, 1) eq 't') {
            $r++;
        }
        while ($l > 0 && substr($actual_word, $l - 1, 1) eq 'b') {
            $l--;
        }
        my $sub = substr($actual_word, $l, $r);
        my $butt = lc($meme);

        if ($sub eq uc $sub) {
            $butt = uc($meme);
        } elsif ($sub =~/^[A-Z]/) {
            $butt = ucfirst($meme);
        }
        #append S or s to plural butts
	if (substr($sub,-2,2) eq '\'s') {
	    $butt = $meme . '\'s';
	} elsif (substr($sub,-1,1) eq 's') {
	    $butt = $meme . 's';
	} elsif (substr($sub,-2,2) eq '\'S') {
	    $butt = uc($meme . '\'S');
	} elsif (substr($sub,-1,1) eq 'S') {
	    $butt = uc($meme . 'S');
	} elsif (substr($sub,-1,1) eq '\'ll') {
	    $butt = $meme . '\'ll';
	} elsif (substr($sub,-1,1) eq '\'LL') {
	    $butt = uc($meme . '\'LL');
	}

        my ($j, $k) = $self->_find_repeating_vowel($sub);

        if ($k > 2) {
                my $k2;
                ($j, $k2) = $self->_find_repeating_vowel($butt);
                substr($butt, $j, 1) = substr($butt, $j, 1) x $k;
        }

        substr($actual_word, $l, $r) = $butt;
        return $lp . $actual_word . $rp;
    }

    sub _build_weightings_for_index {
        my ($self, $initial_weights, $butted_indices) = @_;

        #$self->log("Word indices remaining: ", @indices);

        my $i = 0;

        if ($self->debug) {
            $self->log(Dumper($butted_indices));
            $self->log(Dumper($initial_weights));
        }

        my @idx_weights = map {
            exists($butted_indices->{$i++})?0:$_
        } @$initial_weights;

        my $str;
        $i = 0;
        for (@{$self->word_indices}) {
            $str .= "\tIndex: $_: " . $self->words->[$_]
              . " ,weight=" . $idx_weights[$i++] . "\n";
        }
        $self->log("index weightings:\n" . $str);

        my ($n, $p, $x) = setup_walker_rand(\@idx_weights);
        return ($n, $p, $x)
    }

    sub _sq_weight_indices {
        my $max = shift;
        return map { $max-- ** 2 } (0..$max-1);
    }


    # stealed from http://code.activestate.com/recipes/576564/
    # and http://prxq.wordpress.com/2006/04/17/the-alias-method/
    # Copyright someone maybe somewhere?
    sub setup_walker_rand {
        my ($weight_ref) = @_;

        my @weights = @$weight_ref;
        my $n = scalar @weights;
        my @in_x = (-1) x $n;
        my $sum_w = 0;
        $sum_w += $_ for @weights;

        # normalise weights to have an average value of 1.
        @weights = map { $_ * $n / $sum_w } @weights;

        my (@short, @long);
        my $i = 0;

        # split into long and short groups (excluding those which == 1)
        for my $p (@weights) {
            if ($p < 1) {
                push @short, $i;
            } elsif ($p > 1) {
                push @long, $i;
            }
            $i++;
        }

        # build alias map by combining short and long elements.
        while (scalar @short and scalar @long) {
            my $j = pop @short;
            my $k = $long[-1];

            $in_x[$j] = $k;
            $weights[$k] -= (1 - $weights[$j]);

            if ($weights[$k] < 1) {
                push @short, $k;
                pop @long;
            }
            #        printf("test: j=%d k=%d pk=%.2f\n", $j, $k, $prob[$k]);
        }
        return ($n, \@weights, \@in_x)
    }

    sub get_walker_rand {
        my ($n, $prob, $in_x) = @_;
        my ($u, $j);
        $u = random_uniform(1,0,1);
        $j = random_uniform_integer(1, 0, $n-1);
        return ($u <= $prob->[$j]) ? $j : $in_x->[$j];
    }

    sub log {
        my ($self, @msg) = @_;
        if ($self->debug) {
            print STDERR join(" ", @msg) . $/;
        }
    }

    no Moose;
    __PACKAGE__->meta->make_immutable;

}
