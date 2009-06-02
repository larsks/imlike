use strict;
use IO::File;
use Data::Dumper;

use Irssi qw(command_bind signal_add
	settings_add_str settings_add_int settings_add_bool
	settings_get_str settings_get_int settings_get_bool
);

use vars qw($VERSION %IRSSI $ICONPATH);

$VERSION = '1.0';
%IRSSI = (
	authors     => 'Lars Kellogg-Stedman',
	contact     => 'lars@oddbit.com',
	name        => 'imlike',
	description => 'do stuff',
	license     => 'GPLv2 or later',
	url         => 'http://oddbit.com/',
	changed     => 'recently',
);

sub tilde_subst {
	my $path = shift @_;
	return $path unless $path =~ /~/;

	$path =~ s{
		^ ~             # find a leading tilde
		(               # save this in $1
			[^/]        # a non-slash character
			*     # repeated 0 or more times (0 means me)
		)
	}{
		$1
		? (getpwnam($1))[7]
		: ( $ENV{HOME} || $ENV{LOGDIR} )
	}ex;

	return $path;
}

sub notify {
	my ($msg, $title, $timeout) = @_;

	my @cmd = (tilde_subst(settings_get_str("$IRSSI{name}_notify_path")));

	if ($title) {
		push @cmd, '--title';
		push @cmd, $title
	}

	if (settings_get_str("$IRSSI{name}_icon_path")) {
		push @cmd, '--icon';
		push @cmd, settings_get_str("$IRSSI{name}_icon_path");
	}

	if ($timeout) {
		push @cmd, '--timeout';
		push @cmd, $timeout;
	}

	if (settings_get_bool("$IRSSI{name}_debug")) {
		Irssi::print("Sending notification:");
		Irssi::print(join(' ', (@cmd, $msg)));
	}

	system(@cmd, $msg);
}

sub handle_query_created {
	my $query = shift;
	my $auto = shift;

	notify("New query with $query->{name}", "$query->{name}",
		settings_get_int("$IRSSI{name}_query_notification_timeout"));
}

sub handle_nick_mode_changed {
	my ($channel, $nick, $mode, $type) = @_;

	if ($type eq "-") {
		notify("$nick has become idle.", "$nick",
			settings_get_int("$IRSSI{name}_mode_notification_timeout"));
	} else {
		notify("$nick is no longer idle.", "$nick",
			settings_get_int("$IRSSI{name}_mode_notification_timeout"));
	}
}

# SERVER_REC, char *args, char *sender_nick, char *sender_address
sub handle_event_mode {
	my ($server, $event_args, $nickname, $address) = @_;
	my ($target, $modes, $modeargs) = split(/ /, $event_args, 3);

	return if ! $server->ischannel($target);

	my (@modeargs) = split(/ /,$modeargs);
	my ($pos, $type, $event_type, $arg) = (0, '+');
	foreach my $char (split(//,$modes)) {
			if ($char eq "+" || $char eq "-") {
				$type = $char;
			} else {
				if ($char = 'v') { # nick +-v
					$arg = $modeargs[$pos++];
					handle_nick_mode_changed($target, $arg, $char, $type);
				}
			}
	}
}

signal_add('query created', \&handle_query_created);
signal_add('event mode', \&handle_event_mode);

settings_add_bool($IRSSI{'name'}, "$IRSSI{name}_debug", 0);
settings_add_str($IRSSI{'name'}, "$IRSSI{name}_notify_path", 'irssi-notify');
settings_add_str($IRSSI{'name'}, "$IRSSI{name}_icon_path", '');
settings_add_int($IRSSI{'name'}, "$IRSSI{name}_mode_notification_timeout", 0);
settings_add_int($IRSSI{'name'}, "$IRSSI{name}_query_notification_timeout", 0);

#settings_add_str($IRSSI{'name'}, "$IRSSI{name}_channel_list", '');

