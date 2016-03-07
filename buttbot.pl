#!/usr/bin/perl

package main;

use strict;
use warnings;
use Data::Dumper;

my $badatperl = 1;

my $conf_file = $ARGV[0] || "./conf.yml";
my $bot = BasicButtBot->new(config => $conf_file);

# fly, my pretties, fly!
$bot->run;

package BasicButtBot;

use base qw/Bot::BasicBot/;

# What would you like to Butt today?
use Butts;
# config-parsing is a bit passe.
use YAML::Any;
use Data::Dumper;
# so we can hax our own handlers for things.
use POE;

sub init {

    my $self = shift;

    $self->{settings}->{friends} = {};
    $self->{settings}->{enemies} = {};

    $self->load_config(0);

    $self->{authed_nicks} = {};
    $self->{in_channels} = {};

    # TODO: should we pass more options in?
    $self->{butter} = Butts->new(meme => $self->config('meme'));

    if ($self->config('debug')) {
        $self->log("DBG: Debugging output enabled\n");
    }

    open(IGNORELIST,'<','ignorelist.txt');
    while (!eof(IGNORELIST)) {
	my $line = readline(IGNORELIST);
        $self->log("reading: ".substr($line, 0, -1));
	$self->enemy_set(lc(substr($line, 0, -1)),1);
    }
    close(IGNORELIST);
    $self->log("end of ignore file");

    open(FRIENDLIST,'<','friendlist.txt');
    while (!eof(FRIENDLIST)) {
	my $line = readline(FRIENDLIST);
        $self->log("friending: ".substr($line, 0, -1));
	$self->friend_set(lc(substr($line, 0, -1)),1);
    }
    close(FRIENDLIST);
    $self->log("end of friend file");

#    open(CHANLIST,'<','chanlist.txt');
#    while (!eof(CHANLIST)) {
#	my $line = readline(CHANLIST);
#	$self->log("joining: ".substr($line, 0, -1));
#	$self->join_channel(substr($line, 0, -1));
#    }
#    close(CHANLIST);
#    $self->log("end of chan file");

    1;
}

sub load_config {
    my ($self, $reload) = @_;
    $reload = 0 unless defined $reload;

    my $config = YAML::Any::LoadFile($conf_file);

    # only load these settings at startup.
    unless ($reload) {

        $self->{$_} = $config->{connection}->{$_}
          for (keys %{$config->{connection}});
    }

    my ($old_friends, $old_enemies)
      = ($self->{settings}->{friends},
         $self->{settings}->{enemies});

    $self->{settings}->{$_} = $config->{settings}->{$_}
      for (keys %{$config->{settings}});

    # merge the old copies with the new ones (in case we're reloading)

    $self->{settings}->{friends}->{keys %$old_friends}
      = values %{$old_friends};
    $self->{settings}->{enemies}->{keys %$old_enemies}
      = values %{$old_enemies};
}

#@OVERRIDE
sub start_state {
    # in ur states, adding extra events so we can invite and shiz.
    my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
    my $ret = $self->SUPER::start_state($self, $kernel, $session);
    $kernel->state('irc_invite', $self, 'handle_invite');
    $kernel->state('irc_405', $self, 'handle_err_too_many_chans');

    return $ret;
}

sub irc_001_state {
	my ($self, $kernel) = @_[OBJECT, KERNEL];
	my $ret = $self->SUPER::irc_001_state($self, $kernel);
    open(CHANLIST,'<','chanlist.txt');
	my $joinlist = "";
	my $joinlength = 0;
	my $length_limit = 300;
    while (!eof(CHANLIST)) {
		my $line = readline(CHANLIST);
		#Try to combine joins so we don't have to send a bunch of commands,
		#but make sure it's not so long that it gets truncated.
		if ($joinlength + length($line) + 1 > $length_limit)
		{
			$self->log("joining: ".$joinlist);
			$self->join_channel($joinlist);
			$joinlist = substr($line, 0, -1);
			$joinlength = length($line);
		}
		else
		{
			if ($joinlist ne "")
			{
				$joinlist .= ",";
				$joinlength++;
			}
			$joinlist .= substr($line, 0, -1);
			$joinlength += length($line);
		}
	}
	if ($joinlist ne "") {
		$self->log("joining: ".$joinlist);
		$self->join_channel($joinlist);
	}
	close(CHANLIST);
    $self->log("end of chan file");
	$badatperl = 0;
	return $ret;
}

sub handle_err_too_many_chans {
    my ($self, $server, $msg_text, $msg_parsed)
      = @_[OBJECT, ARG0, ARG1, ARG2];
    $self->log("IRC: too many channels:\n" . Dumper($msg_parsed) . "\n");
    # TODO: how can we let the user who requested us know that we're
    # unable to comply?  Maybe keep a queue of pending commands, and
    # only respond ok/err when we get an appropriate response from server.
    return;
}

sub handle_invite {
    my ($self, $inviter, $channel) = @_[OBJECT, ARG0, ARG1];
    $inviter = $self->nick_strip($inviter);
    if ($self->config_bool('invite')) {
        $self->log("IRC: Going to join $channel, invited by $inviter\n");
    } else {
        $self->pm_reply($inviter, "Sorry, inviting is disabled by the admin.");
        $self->log("IRC: invite refused from $inviter to $channel\n");
    }
    $self->join_channel($channel);
}

sub join_channel {
    my ($self, $channel, $key) = @_;
    $key = '' unless defined $key;
    $self->log("IRC: Joining channel [$channel]\n");
    $poe_kernel->post($self->{IRCNAME}, 'join', $channel, $key);
    if($badatperl eq '0') {
    open(CHANLIST,'>>','chanlist.txt');
    print CHANLIST "$channel\n";
    close(CHANLIST);
}
}

sub leave_channel {
    my ($self, $channel, $part_msg) = @_;
    $part_msg ||= "ButtBot Go Byebye!";
    $self->log("IRC: Leaving channel [$channel]: \"$part_msg\"\n");
    $poe_kernel->post($self->{IRCNAME}, 'part', $channel, $part_msg);
    open(CHANLIST,"<",'chanlist.txt');
    open(NEWCHAN,">>",'newchan.txt');
    while(!eof(CHANLIST)){
        my $line = readline(CHANLIST);
        if (lc(substr($line, 0, -1)) ne lc($channel)) {
            print NEWCHAN "$line";
        }
    }
    close(CHANLIST);
    close(NEWCHAN);
    unlink 'chanlist.txt';
    rename 'newchan.txt', 'chanlist.txt';
}

sub in_channel {
    my ($self, $channel, $present) = @_;
    if (defined $present) {
        if (!$present) {
            delete $self->{in_channels}->{$channel}
              if exists $self->{in_channels}->{$channel};
        } else {
            $self->{in_channels}->{$channel} = 1;
        }
    }
    return $self->{in_channels}->{$channel};
}

sub get_all_channels {
    my ($self) = @_;
    return keys %{ $self->{in_channels} };
}

# TODO: refactor these 3 better. Emote should never have to deal with commands
# or prefixes.  Just a message to be re-butted.
sub emoted {
    my ($self, $ref) = @_;
    $self->handle_said_emoted($ref, 1);
}

sub said {
    my ($self, $ref) = @_;
    $self->handle_said_emoted($ref, 0);
}

sub handle_said_emoted {
    my ($self, $ref, $reply_as_emote) = @_;
    # slicin' ma hashes.
    my ($channel, $body, $address, $who) =
      @{$ref}{qw/channel body address who/};

    # address doesn't even get set unless it's true :(
    $address ||= 0;

#    print STDERR Dumper($ref);
#    print STDERR "\n---------\n";

    if ($channel ne 'msg') {
        # address is what is stripped off the front 
        my $addressed = $address && $address ne 'msg';
        # normal command
        # eg: <bob> ButtBot: stop it
        return if $self->handle_channel_command($who,
                                                $channel,
                                                $body,
                                                $addressed);
    } elsif ($channel eq 'msg') {
        # parse for command
        return if $self->handle_pm_command($who, $body);

    }

    # butting is the default behaviour.
    $self->log("BUTT: Might butt\n");
    if ($self->to_butt_or_not_to_butt($who, $body)) {
        $self->log("BUTT: Butting $who in [$channel]\n");
        $self->buttify_message($who, $channel, $body, $reply_as_emote, 0);
    }

    return;
}

sub parse_command {
    my ($self, $msg, $require_prefix) = @_;
    my $cmd_prefix = quotemeta($self->config('cmd_prefix'));

    $require_prefix = 1 unless defined $require_prefix;
    if (!$require_prefix) {
        $cmd_prefix .= '?';
    }

    if ($msg =~ m/^$cmd_prefix([\w_-]+)\s*(.*)$/) {
        return ($1, $2);
    } else {
        return ();
    }
}

sub _parse_channel {
    # parse a string into a channel (optionally with a leading # or &), and the
    # remainder of the string.
    my ($str) = @_;
    if ($str =~ m/^([#&]?)([^,\s\x07]+)\s*(.*)$/) {
        return ($1.$2, $3) if $1;
        return ('#'.$2, $3);
    }
    return (undef, $str);
}

sub handle_channel_command {
    my ($self, $who, $channel, $msg, $addressed) = @_;
    # return false if we don't handle a command, so things can
    # be appropriately butted.

    $self->log("CMD: testing user command [$channel]\n");
    # if we were addressed (as <foo> BotNick: CMD), don't require
    # the command prefix char.  Otherwise do.
    my ($cmd, $args) = $self->parse_command($msg, $addressed?0:1);
    return 0 unless defined $cmd && length $cmd;

    if ($cmd eq $self->config('meme') || $cmd eq $self->config('meme').'ify') {
	$self->buttify_message($who, $channel, $args, 0,1);
	return 1;
    } elsif ($cmd eq 'no') {
        $self->say(channel => $channel, body => ":(");
        return 1;
    } elsif ($cmd eq 'yes') {
	$self->say(channel => $channel, body => "FrankerZ");
	return 1;
    } elsif ($cmd eq 'why') {
	$self->say(channel => $channel, body => "EvilFetus");
	return 1;
    } elsif ($cmd eq 'buttabout') {
	$self->say(channel => $channel, body => "I'm buttbot! I say butt! Visit me at twitch.tv/buttsbot for commands and stuff. (by pinguino age 6)");
    } elsif (($cmd eq 'leaveme') && ('#'.$who eq $channel)) {
	$self->say(channel => $channel, body => "Okay, bye!");
	$self->leave_channel($channel);
    } elsif ($cmd eq 'ignoreme') {
	$self->say(channel => $channel, body => "Okay, I won't butt you anymore.");
	$self->enemy_set($who, 1);
        $self->pm_reply($who, "OK!");
	return 1;
    } elsif ($cmd eq 'unignoreme') {
	$self->say(channel => $channel, body => "Okay, I'm not ignoring you anymore! :D");
	$self->enemy_set($who, 0);
	$self->pm_reply($who, "Enemy unset!");
	return 1;
    }

	#Mod commands, should only be used in BBot's channel
	#Add actual authing later?
	
	#TODO TO DO TODO TODO IMPORTANT
	#Instead of adding an auth system that works on Twitch (where there's no PMs)
	#I hard-coded my nick here because I'm a good programmer
	#If you're gonna use this bot, you need to fix this
if($channel eq '#buttsbot'){
    if ($cmd eq 'join' && $who eq 'mynick') {
        my ($arg_chan, $arg_rem) = _parse_channel($args);
        if (defined $arg_chan) {
            if ($self->in_channel($arg_chan)) {
		$self->say(channel => $channel, body => "I'm already in that channel!");
	    } else {
                $self->join_channel($arg_chan);
                $self->say(channel => $channel, body => "Joining!");
            }
        } else {
            $self->say(channel => $channel, body => "Gonna need a channel name.");;
        }
    } elsif ($cmd eq 'leave' && $who eq 'mynick') {
        my ($arg_chan, $arg_msg) = _parse_channel($args);
        if (defined $arg_chan) {
 #           if (!$self->in_channel($arg_chan)) {
  #               $self->say(channel => $channel, body => "I'm not in that channel!");
   #         } else {
                $self->leave_channel($arg_chan, $arg_msg);
                 $self->say(channel => $channel, body => "Leaving!");
#            }
        } else {
             $self->say(channel => $channel, body => "Gonna need a channel name.");
        }
    } elsif ($cmd eq 'joinme') {
	if ($self->in_channel("#" . $who)) {
	    $self->say(channel => $channel, body => "I'm already in your channel!");
	} else {
	    $self->join_channel("#" . $who);
	    $self->say(channel => $channel, body => "Joining! :3");
	}
   } elsif ($cmd eq 'leaveme') {
#	if (!$self->in_channel("#" . $who)) {
#	     $self->say(channel => $channel, body => "I'm not in your channel!");
#	} else {
	    $self->leave_channel("#" . $who);
	    $self->say(channel => $channel, body => "Leaving! 3:");
#	}
    } elsif ($cmd eq 'reload') {
        $self->load_config(1);
         $self->say(channel => $channel, body => "Reloaded!");
    } elsif ($cmd eq 'friend') {
        $self->friend_set(lc($args), 1);
        $self->say(channel => $channel, body => "Friend set! :D");
    } elsif ($cmd eq 'unfriend') {
	$self->friend_set(lc($args), 0);
	$self->say(channel => $channel, body => "Friend unset :(");
    } elsif ($cmd eq 'enemy') {
	$self->enemy_set(lc($args), 1);
	$self->say(channel => $channel, body => "Ignore set! >:[");
    } elsif ($cmd eq 'unenemy') {
	$self->enemy_set(lc($args), 0);
	$self->say(channel => $channel, body => "Ignore unset :^I");
    }

  }  

    return 0;
}

sub buttify_message {
    my ($self, $who, $where,
        $what, $reply_as_emote,
        $prefix_addressee) = @_;

    my $meme = $self->config('meme');

    $prefix_addressee = 0 unless defined $prefix_addressee;
    $reply_as_emote = 0 unless defined $reply_as_emote;

    my $butt_msg = $self->{butter}->buttify_string($what);

    unless ($self->_was_string_butted($what, $butt_msg)) {
        $self->log("BUTT: String \"$butt_msg\" wasn't butted");
        return 0;
    }

    my $butt_msg_chk = $butt_msg;
    $butt_msg_chk =~ s/[[:punct:]]//g;
    if(lc(substr $butt_msg_chk,-1,1) eq 's'){
        chop($butt_msg_chk);}
    unless (lc($butt_msg_chk) eq lc($meme)) {
        if ($reply_as_emote) {
            $self->emote(channel => $where, who => $who,
                       body => $butt_msg, address => 0);
        } else {
            $self->say(channel => $where, who => $who,
                       body => $butt_msg);
        }
    } else {
        $self->log("BUTT: butting resulted in solo butt and was discarded.");
	#$self->say(channel => $where, who => $who, body=> "Sorry, can't ".$self->config('meme'));    
	}

    return 1;
}

sub to_butt_or_not_to_butt {
    my ($self, $sufferer, $message) = @_;
    my $rnd_max = 0;
    my $frequencies = $self->config('frequency');

    #return 0 if $self->might_be_a_bot($sufferer);

    # Fixes issue 6.
    unless ($self->_is_string_buttable($message)) {
        $self->log("BUTT: String is not buttable");
        return 0;
    }

    if ($self->is_enemy(lc($sufferer))) {
        $self->log("BUTT: [$sufferer:enemy] not butting\n");
        return 0;
    } elsif ($self->is_friend(lc($sufferer))) {
        $rnd_max = $frequencies->{friend};
        $self->log("BUTT: [$sufferer:friend] prob is 1/$rnd_max\n");
    } elsif (substr($message, 0, 1) eq '!') {
        $self->log("BUTT: [$sufferer:botcommand] not butting");
        return 0; 
    } else {
        $rnd_max = $frequencies->{normal};
        $self->log("BUTT: [$sufferer:normal] prob is 1/$rnd_max\n");
    }
    my $rnd = int rand $rnd_max;
    return ($rnd==0);
}


sub _is_string_buttable {
    my ($self, $str) = @_;
    return $str =~ m/[a-zA-Z]+/;
}

# test if a string is the same as it was pre- and post-butting.
# returns true if strings are different
sub _was_string_butted {
    my ($self, $in, $out) = @_;
    my $meme = $self->config('meme');

    # we can't trust whitespace, since we might have trimmed it differently.
    $in =~ s/\s+//g;
    $out =~ s/\s+//g;
    return (lc($in) ne lc($out));
}

sub is_me {
    my ($self, $who) = @_;
    # TODO: support B::BBot's alt_nicks param too?
    return $self->{nick} eq $who;
}

sub config {
    my ($self, $key, $value) = @_;
    if (defined $value) {
        $self->{settings}->{$key} = $value;
    }

    $self->log("CFG: $key requested doesn't exist\n")
      unless exists $self->{settings}->{$key};

    return $self->{settings}->{$key};
}

sub config_bool {
    # types :(
    my ($self, $key, $value) = @_;
    if (defined $value) {
        $self->{settings}->{$key} = $value?1:0;
    }
    my $val = $self->{settings}->{$key} || 0;
    if ($val =~ m/(?:[tT]rue)|(?:[Yy]es)|1/) {
        return 1;
    } else {
        return 0;
    }
}

sub is_friend {
    my ($self, $nick) = @_;
    return exists($self->{friends}->{$nick});
}

sub is_enemy {
    my ($self, $nick) = @_;
    return exists($self->{enemies}->{$nick});
}

sub friend_set {
    my ($self, $nick, $friend) = @_;
    if ($friend) {
        $self->{friends}->{$nick} = 1;
       if ($badatperl eq '0'){
	open(FRIENDLIST,'>>','friendlist.txt');
	print FRIENDLIST "$nick\n";
	close(FRIENDLIST);
       }
    } else {
        if ($self->is_friend($nick)) {
            delete($self->{friends}->{$nick});
        open(FRIENDLIST,"<",'friendlist.txt');
        open(NEWFRIEND,">>",'newfriend.txt');
        while(!eof(FRIENDLIST)){
            my $line = readline(FRIENDLIST);
            if (lc(substr($line, 0, -1)) ne lc($nick)) {
                print NEWFRIEND "$line";
            }
        }
        close(FRIENDLIST);
        close(NEWFRIEND);
        unlink 'friendlist.txt';
        rename 'newfriend.txt', 'friendlist.txt';
        } else {
            $self->log("Trying to de-friend someone who isn't friended: $nick\n");
        }
    }
}

sub enemy_set {
    my ($self, $nick, $enemy) = @_;
    if ($enemy) {
        $self->{enemies}->{$nick} = 1;
       if ($badatperl eq '0'){
	open(IGNORELIST,'>>','ignorelist.txt');
	print IGNORELIST "$nick\n";
	close(IGNORELIST);
    }
    } else {
        if ($self->is_enemy($nick)) {
            delete($self->{enemies}->{$nick});
        open(IGNORELIST,"<",'ignorelist.txt');
        open(NEWIGNORE,">>",'newignore.txt');
        while(!eof(IGNORELIST)){
            my $line = readline(IGNORELIST);
            if (lc(substr($line, 0, -1)) ne lc($nick)) {
                print NEWIGNORE "$line";
            }
        }
        close(IGNORELIST);
        close(NEWIGNORE);
        unlink 'ignorelist.txt';
        rename 'newignore.txt', 'ignorelist.txt';
        } else {
            $self->log("Trying to de-enemy someone who isn't an enemy: $nick\n");
        }
    }
}


sub log {
    my $self = shift;
    if ($self->config_bool('debug')) {
        $self->SUPER::log(@_);
    }
}
1;

