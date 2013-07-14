#
#   Shm.pl: Shared Memory stuff.
#    Author: dms
#   Version: 20000201
#   Created: 20000124
#

# use strict;	# TODO

use POSIX qw(_exit);

my %shm_keys;

sub openSHM {
    my $IPC_PRIVATE = 0;
    my $size        = 2000;

    if ( &IsParam('noSHM') ) {
        &status('Shared memory: Disabled. WARNING: bot may become unreliable');
        return 0;
    }

    if ( defined( $_ = shmget( $IPC_PRIVATE, $size, 0777 ) ) ) {
        &status("Created shared memory (shm) key: [$_]");
        $shm_keys{$_} = {
            time     => time,
            accessed => 0,
            key      => $_,
        };
        return $_;
    }
    else {
        &ERROR('openSHM: failed.');
        &ERROR('Please delete some shared memory with ipcs or ipcrm.');
        exit 1;
    }
}

sub closeSHM {
    my ($key) = @_;
    my $IPC_RMID = 0;

    return '' if ( !defined $key );

    &shmFlush();
    &status("Closed shared memory (shm) key: [$key]");
    return shmctl( $key, $IPC_RMID, 0 );
}

sub shmRead {
    my ($key)    = @_;
    my $position = 0;
    my $size     = 3 * 80;
    my $retval   = '';

    return '' if ( &IsParam('noSHM') );

    if ( shmread( $key, $retval, $position, $size ) ) {

        #&DEBUG("shmRead($key): $retval");
        return $retval;
    }
    else {
        &ERROR("shmRead: failed: $!");
        if ( exists $shm_keys{$_} ) {
            closeSHM($key);
        }
        ### TODO: if this fails, never try again.
        # What use is opening a SHM segment if we're not going to read it?
        # &openSHM();
        return '';
    }
}

sub shmWrite {
    my ( $key, $str ) = @_;
    my $position = 0;
    my $size     = 80 * 3;

    return if ( &IsParam('noSHM') );

    $shm_keys{$keys}{accessed} = 1;

    if ( length($str) > $size ) {
        &status("ERROR: length(str) (..)>$size...");
        return;
    }

    if ( length($str) == 0 ) {

        # does $size overwrite the whole lot?
        # if not, set to 2000.
        if ( !shmwrite( $key, '', $position, $size ) ) {
            &ERROR("shmWrite: failed: $!");
        }
        return;
    }

    my $read = &shmRead($key);
    $read =~ s/\0+//g;
    if ( $read eq '' ) {
        $str = sprintf( '%s:%d:%d: ', $param{ircUser}, $bot_pid, time() );
    }
    else {
        $str = $read . '||' . $str;
    }

    if ( !shmwrite( $key, $str, $position, $size ) ) {
        &DEBUG("shmWrite($key, $str)");
        &ERROR("shmWrite: failed: $!");
    }
}

##############
### Helpers
###

# Usage: &addForked($name);
# Return: 1 for success, 0 for failure.
sub addForked {
    my ($name) = @_;
    my $forker_timeout = 360;    # 6mins, in seconds.
    $forker = $name;

    if ( !defined $name ) {
        &WARN('addForked: name == NULL.');
        return 0;
    }

    foreach ( keys %forked ) {
        my $n    = $_;
        my $time = time() - $forked{$n}{Time};
        next unless ( $time > $forker_timeout );

        ### TODO: use &time2string()?
        &WARN("Fork: looks like we lost '$n', executed $time ago");

        my $pid = $forked{$n}{PID};
        if ( !defined $pid ) {
            &WARN("Fork: no pid for $n.");
            delete $forked{$n};
            next;
        }

        if ( $pid == $bot_pid ) {

            # don't kill parent, just warn.
            &status("Fork: pid == \$bot_pid == \$\$ ($bot_pid)");

        }
        elsif ( -d "/proc/$pid" ) {    # pid != bot_pid.
            &status("Fork: killing $name ($pid)");
            kill 9, $pid;
        }

        delete $forked{$n};
    }

    my $count = 0;
    while ( scalar keys %forked > 1 ) {    # 2 or more == fail.
        sleep 1;

        if ( $count > 3 ) {                # 3 seconds.
            my $list = join( ', ', keys %forked );
            if ( defined $who ) {
                &msg( $who, "exceeded allowed forked count (shm $shm): $list" );
            }
            else {
                &status(
"Fork: I ran too many forked processes :) Giving up $name. Shm: $shm"
                );
            }

            return 0;
        }

        $count++;
    }

    if ( exists $forked{$name} and !scalar keys %{ $forked{$name} } ) {
        &WARN("addF: forked{$name} exists but is empty; deleting.");
        undef $forked{$name};
    }

    if ( exists $forked{$name} and scalar keys %{ $forked{$name} } ) {
        my $time     = $forked{$name}{Time};
        my $continue = 0;

        $continue++ if ( $forked{$name}{PID} == $$ );

        if ($continue) {
            &WARN("hrm.. fork pid == mypid == $$; how did this happen?");

        }
        elsif ( -d "/proc/$forked{$name}{PID}" ) {
            &status('fork: still running; good. BAIL OUT.');
            return 0;

        }
        else {
            &WARN('Found dead fork; removing and resetting.');
            $continue = 1;
        }

        if ($continue) {

            # NOTHING.

        }
        elsif ( time() - $time > 900 ) {    # stale fork > 15m.
            &status(
                "forked: forked{$name} presumably exited without notifying us."
            );

        }
        else {                              # fresh fork.
            &msg( $who,
                "$name is already running " . &Time2String( time() - $time ) );
            return 0;
        }
    }

    $forked{$name}{Time} = time();
    $forked{$name}{PID}  = $$;
    $forkedtime          = time();
    $count{'Fork'}++;
    return 1;
}

sub delForked {
    my ($name) = @_;

    return if ( $$ == $bot_pid );

    if ( !defined $name ) {
        &WARN('delForked: name == NULL.');
        POSIX::_exit(0);
    }

    if ( $name =~ /\.pl/ ) {
        &WARN("dF: name is name of source file ($name). FIX IT!");
    }

    &showProc();    # just for informational purposes.

    if ( exists $forked{$name} ) {
        my $timestr = &Time2String( time() - $forked{$name}{Time} );
        &status("fork: took $timestr for $name.");
        &shmWrite( $shm, "DELETE FORK $name" );
    }
    else {
        &ERROR("delForked: forked{$name} does not exist. should not happen.");
    }

    &status("--- fork finished for '$name' ---");

    POSIX::_exit(0);
}

sub shmFlush {
    return if ( $$ != $::bot_pid );    # fork protection.

    if (@_) {
        &ScheduleThis( 15 * 60, 'shmFlush' );    # 15 minutes
        return if ( $_[0] eq '2' );
    }

    my $time;
    my $shmmsg = &shmRead($shm);

    # remove padded \0's.
    $shmmsg =~ s/\0//g;
    return if ( length($shmmsg) == 0 );
    if ( $shmmsg =~ s/^(\S+):(\d+):(\d+): // ) {
        my $n   = $1;
        my $pid = $2;
        $time = $3;
    }
    else {
        &status("warn: shmmsg='$shmmsg'.");
        return;
    }

    foreach ( split '\|\|', $shmmsg ) {
        next if (/^$/);
        &VERB( "shm: Processing '$_'.", 2 );

        if (/^DCC SEND (\S+) (\S+)$/) {
            my ( $nick, $file ) = ( $1, $2 );
            if ( exists $dcc{'SEND'}{$who} ) {
                &msg( $nick, 'DCC already active.' );
            }
            else {
                &DEBUG("shm: dcc sending $2 to $1.");
                $conn->new_send( $1, $2 );
                $dcc{'SEND'}{$who} = time();
            }
        }
        elsif (/^SET FORKPID (\S+) (\S+)/) {
            $forked{$1}{PID} = $2;
        }
        elsif (/^DELETE FORK (\S+)$/) {
            delete $forked{$1};
        }
        elsif (/^EVAL (.*)$/) {
            &DEBUG("evaling '$1'.");
            eval $1;
        }
        else {
            &DEBUG("shm: unknown msg. ($_)");
        }
    }

    &shmWrite( $shm, '' ) if ( $shmmsg ne '' );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
