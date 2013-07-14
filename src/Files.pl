#
# Files.pl: Open and close, read and probably write files.
#   Author: dms
#  Version: v0.3 (20010120)
#  Created: 19991221
#

use strict;

use vars qw(%lang %ircPort);
use vars qw(@ircServers);
use vars qw($bot_config_dir);

# File: Language support.
sub loadLang {
    my ($file) = @_;
    my $langCount = 0;
    my $replyName;

    if ( !open( FILE, $file ) ) {
        &ERROR("Failed reading lang file ($file): $!");
        exit 0;
    }

    undef %lang;    # for rehash.

    while (<FILE>) {
        chop;
        if ( $_ eq '' || /^#/ ) {
            undef $replyName;
            next;
        }

        if ( !/^\s/ ) {
            $replyName = $_;
            next;
        }

        s/^[\s\t]+//g;
        if ( !$replyName ) {
            &status("loadLang: bad line ('$_')");
            next;
        }

        $lang{$replyName}{$_} = 1;
        $langCount++;
    }
    close FILE;

    $file =~ s/^.*\///;
    &status("Loaded $file ($langCount items)");
}

# File: Irc Servers list.
sub loadIRCServers {
    my ($file) = $bot_config_dir . '/infobot.servers';
    @ircServers = ();
    %ircPort    = ();

    if ( !open( FILE, $file ) ) {
        &ERROR("Failed reading server list ($file): $!");
        exit 0;
    }

    while (<FILE>) {
        chop;
        next if /^\s*$/;
        next if /^[\#\[ ]/;

        if (/^\s*(\S+?)(:(\d+))?\s*$/) {
            push( @ircServers, $1 );
            $ircPort{$1} = ( $3 || 6667 );
        }
        else {
            &status("loadIRCServers: invalid line => '$_'.");
        }
    }
    close FILE;

    $file =~ s/^.*\///;
    &status( "Loaded $file (" . scalar(@ircServers) . ' servers)' );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
