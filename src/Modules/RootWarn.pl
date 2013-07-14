#
# RootWarn.pl: Warn people about usage of root on IRC.
#      Author: dms
#     Version: v0.3 (20000923)
#     Created: 19991008
#

use strict;

use vars qw(%channels %param);
use vars qw($dbh $found $ident);

sub rootWarn {
    my ( $nick, $user, $host, $chan ) = @_;
    my $n        = lc $nick;
    my $attempt  = &sqlSelect( 'rootwarn', 'attempt', { nick => $n } ) || 0;
    my $warnmode = &getChanConf('rootWarnMode');

    if ( $attempt == 0 ) {    # first timer.
        if ( defined $warnmode and $warnmode =~ /quiet/i ) {
            &status('RootWarn: Detected root user; notifying user');
        }
        else {
            &status(
                'RootWarn: Detected root user; notifying nick and channel.');
            &msg( $chan, 'ROO' . ( 'O' x int( rand 8 ) ) . "T has landed!" );
        }

        if ( $_ = &getFactoid('root') ) {
            &msg( $nick, "RootWarn: $attempt : $_" );
        }
        else {
            &status('"root" needs to be defined in database.');
        }

    }
    elsif ( $attempt < 2 ) {    # 2nd/3rd time occurrance.
        if ( $_ = &getFactoid('root again') ) {
            &status("RootWarn: not first time root user; msg'ing $nick.");
            &msg( $nick, "RootWarn: $attempt : $_" );
        }
        else {
            &status('"root again" needs to be defined in database.');
        }

    }
    else {                      # >3rd time occurrance.
                                # disable this for the time being.
        if ( 0 and $warnmode =~ /aggressive/i ) {
            if ( $channels{$chan}{'o'}{$ident} ) {
                &status("RootWarn: $nick... sigh... bye bye.");
                rawout("MODE $chan +b *!root\@$host");    # ban
                &kick( $chan, $nick, 'bye bye' );
            }
        }
        elsif ( $_ = &getFactoid('root again') ) {
            &status("RootWarn: $attempt times; msg'ing $nick.");
            &msg( $nick, "RootWarn: $attempt : $_" );
        }
        else {
            &status("root again needs to be defined in database.");
        }
    }

    $attempt++;
    ### TODO: OPTIMIZE THIS.
    # ok... don't record the attempt if nick==root.
    return if ( $nick eq 'root' );

    &sqlSet(
        'rootwarn',
        { nick => lc($nick) },
        {
            attempt => $attempt,
            time    => time(),
            host    => $user . "\@" . $host,
            channel => $chan,
        }
    );

    return;
}

# Extras function.
# TODO: support arguments to get info on a particular nick?
sub CmdrootWarn {
    my $reply;
    my $count = &countKeys('rootwarn');

    if ( $count == 0 ) {
        &performReply("no-one has been warned about root, woohoo");
        return;
    }

    # reply #1.
    $reply = 'there '
      . &fixPlural( 'has', $count )
      . " been \002$count\002 "
      . &fixPlural( 'rooter', $count )
      . " warned about root.";

    if ( $param{'DBType'} !~ /^(pg|my)sql$/i ) {
        &FIXME("rootwarn does not yet support non-{my,pg}sql.");
        return;
    }

    # reply #2.
    $found = 0;
    my $query = "SELECT attempt FROM rootwarn WHERE attempt > 2";
    my $sth   = $dbh->prepare($query);
    $sth->execute;

    while ( my @row = $sth->fetchrow_array ) {
        $found++;
    }

    $sth->finish;

    if ($found) {
        $reply .=
            " Of which, \002$found\002 "
          . &fixPlural( 'rooter', $found ) . ' '
          . &fixPlural( 'has',    $found )
          . " done it at least 3 times.";
    }

    &performStrictReply($reply);
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
