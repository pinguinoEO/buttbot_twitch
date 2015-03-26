use strict;
use warnings;

use Irssi;
use Butts;

use vars qw($VERSION %IRSSI);

$VERSION = '1.0';
%IRSSI = (
	authors	    => 'Benjamin Herr',
	contact     => 'ben@0x539.de',
	name        => 'irssibutt',
	description => 'This script randomly repeats lines replacing ' .
	               'syllables with "butt".'
);

sub on_privmsg {
	my ($server, $data, $nick, $address) = @_;
	my ($target, $text) = split(/ :/, $data, 2);

	return unless ($target =~ Irssi::settings_get_str("butt_target_pattern"));
	return 0 unless (rand(Irssi::settings_get_int("butt_frequency")) < 1);
	return 0 if ($text =~ /^!|^http:\/\/\S+$|butt|^\W+$/i);

    my $butter = Butts->new(meme => 'butt');
	my $replaced_text = $butter->buttify_string($text);

	unless ($text eq $replaced_text) {
		Irssi::timeout_add_once(rand(8000) + 1000,
		  sub { $server->command("msg $target " . $replaced_text); },
			0);
	}
}

sub on_kick {
	my ($server, $channel, $nick, $kicker, $address, $reason) = @_;

	return unless ($channel =~ Irssi::settings_get_str("butt_target_pattern"));

	Irssi::timeout_add_once(rand(20000) + 10000,
		sub { $server->command("join $channel"); }, 0);
}

Irssi::settings_add_str("irssibutt", "butt_target_pattern", "^#cobol\$");
Irssi::settings_add_int("irssibutt", "butt_frequency", "50");

Irssi::signal_add("event privmsg", \&on_privmsg);
Irssi::signal_add("message kick", \&on_kick);

return 1;
