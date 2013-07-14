#
# IrcHooks.pl: IRC Hooks stuff.
#      Author: dms
#     Version: 20010413
#     Created: 20010413
#        NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#

#######################################################################
####### IRC HOOK HELPERS   IRC HOOK HELPERS   IRC HOOK HELPERS ########
#######################################################################

#####
# Usage: &hookMode($nick, $modes, @targets);
sub hookMode {
    my ( $nick, $modes, @targets ) = @_;
    my $parity = 0;

    my $mode;
    foreach $mode ( split( //, $modes ) ) {

        # sign. tmp parity needed to store current state
        if ( $mode =~ /[-+]/ ) {
            $parity = 1 if ( $mode eq '+' );
            $parity = 0 if ( $mode eq '-' );
            next;
        }

        # mode with target.
        if ( $mode =~ /[bklov]/ ) {
            my $target = shift @targets;

            if ($parity) {
                $chanstats{ lc $chan }{'Op'}++  if ( $mode eq 'o' );
                $chanstats{ lc $chan }{'Ban'}++ if ( $mode eq 'b' );
            }
            else {
                $chanstats{ lc $chan }{'Deop'}++  if ( $mode eq 'o' );
                $chanstats{ lc $chan }{'Unban'}++ if ( $mode eq 'b' );
            }

            # modes w/ target affecting nick => cache it.
            if ( $mode =~ /[bov]/ ) {
                $channels{ lc $chan }{$mode}{$target}++      if $parity;
                delete $channels{ lc $chan }{$mode}{$target} if !$parity;

                # lets do some custom stuff.
                if ( $mode =~ /o/ and not $parity ) {
                    if ( $target =~ /^\Q$ident\E$/i ) {
                        &VERB( 'hookmode: someone deopped us!', 2 );
                        &chanServCheck($chan);
                    }

                    &chanLimitVerify($chan);
                }
            }

            if ( $mode =~ /[l]/ ) {
                $channels{ lc $chan }{$mode} = $target if $parity;
                delete $channels{ lc $chan }{$mode} if !$parity;
            }
        }

        # important channel modes, targetless.
        if ( $mode =~ /[mt]/ ) {
            $channels{ lc $chan }{$mode}++      if $parity;
            delete $channels{ lc $chan }{$mode} if !$parity;
        }
    }
}

sub hookMsg {
    ( $msgType, $chan, $who, $message ) = @_;
    my $skipmessage = 0;
    $addressed      = 0;
    $addressedother = 0;
    $orig{message}  = $message;
    $orig{who}      = $who;
    $addrchar       = 0;

    $message =~ s/[\cA-\c_]//ig;    # strip control characters
    $message =~ s/^\s+//;           # initial whitespaces.
    $who     =~ tr/A-Z/a-z/;        # lowercase.
    my $mynick = $conn->nick();

    &showProc();

    # addressing.
    if ( $msgType =~ /private/ ) {

        # private messages.
        $addressed = 1;
        if ( &IsChanConf('addressCharacter') > 0 ) {
            $addressCharacter = getChanConf('addressCharacter');
            if ( $message =~ s/^\Q$addressCharacter\E// ) {
                &msg( $who,
"The addressCharacter \"$addressCharacter\" is to get my attention in a normal channel. Please leave it off when messaging me directly."
                );
            }
        }
    }
    else {

        # public messages.
        # addressing revamped by the xk.
        ### below needs to be fixed...
        if ( &IsChanConf('addressCharacter') > 0 ) {
            $addressCharacter = getChanConf('addressCharacter');
            if ( $message =~ s/^\Q$addressCharacter\E// ) {
                $addrchar  = 1;
                $addressed = 1;
            }
        }

        if ( $message =~ /^($mask{nick})([\;\:\>\, ]+) */ ) {
            my $newmessage = $';
            if ( $1 =~ /^\Q$mynick\E$/i ) {
                $message   = $newmessage;
                $addressed = 1;
            }
            else {

                # ignore messages addressed to other people or unaddressed.
                $skipmessage++ if ( $2 ne '' and $2 !~ /^ / );
            }
        }
    }

    # Determine floodwho.
    my $c = '_default';
    if ( $msgType =~ /public/i ) {

        # public.
        $floodwho = $c = lc $chan;
    }
    elsif ( $msgType =~ /private/i ) {

        # private.
        $floodwho = lc $who;
    }
    else {

        # dcc?
        &FIXME('floodwho = ???');
    }

    my $val = &getChanConfDefault( 'floodRepeat', '2:5', $c );
    my ( $count, $interval ) = split /:/, $val;

    # flood repeat protection.
    if ($addressed) {
        my $time = $flood{$floodwho}{$message} || 0;

        if (    !&IsFlag('o')
            and $msgType eq 'public'
            and ( time() - $time < $interval ) )
        {
            ### public != personal who so the below is kind of pointless.
            my @who;
            foreach ( keys %flood ) {
                next if (/^\Q$floodwho\E$/);
                next if ( defined $chan and /^\Q$chan\E$/ );

                push( @who, grep /^\Q$message\E$/i, keys %{ $flood{$_} } );
            }

            return if ($lobotomized);

            if ( !scalar @who ) {
                push( @who, 'Someone' );
            }
            &msg( $who,
                    join( ' ', @who )
                  . ' already said that '
                  . ( time - $time )
                  . ' seconds ago' );

            ### TODO: delete old floodwarn{} keys.
            my $floodwarn = 0;
            if ( !exists $floodwarn{$floodwho} ) {
                $floodwarn++;
            }
            else {
                $floodwarn++ if ( time() - $floodwarn{$floodwho} > $interval );
            }

            if ($floodwarn) {
                &status("FLOOD repetition detected from $floodwho.");
                $floodwarn{$floodwho} = time();
            }

            return;
        }

        if ($addrchar) {
            &status("$b_cyan$who$ob is short-addressing $mynick");
        }
        elsif ( $msgType eq 'private' ) {    # private.
            &status("$b_cyan$who$ob is /msg'ing $mynick");
        }
        else {                               # public?
            &status("$b_cyan$who$ob is addressing $mynick");
        }

        $flood{$floodwho}{$message} = time();
    }
    elsif ( $msgType eq 'public' and &IsChanConf('kickOnRepeat') > 0 ) {

        # unaddressed, public only.

        ### TODO: use a separate 'short-time' hash.
        my @data;
        @data = keys %{ $flood{$floodwho} } if ( exists $flood{$floodwho} );
    }

    $val = &getChanConfDefault( 'floodMessages', '5:30', $c );
    ( $count, $interval ) = split /:/, $val;

    # flood overflow protection.
    if ($addressed) {
        foreach ( keys %{ $flood{$floodwho} } ) {
            next unless ( time() - $flood{$floodwho}{$_} > $interval );
            delete $flood{$floodwho}{$_};
        }

        my $i = scalar keys %{ $flood{$floodwho} };
        if ( $i > $count ) {
            my $expire = $param{'ignoreAutoExpire'} || 5;

            #	    &msg($who,"overflow of messages ($i > $count)");
            &msg( $who,
                "Too many queries from you, ignoring for $expire minutes." );
            &status("FLOOD overflow detected from $floodwho; ignoring");

            &ignoreAdd( "*!$uh", $chan, $expire,
                'flood overflow auto-detected.' );
            return;
        }

        $flood{$floodwho}{$message} = time();
    }

    my @ignore;
    if ( $msgType =~ /public/i ) {    # public.
        $talkchannel = $chan;
        &status("<$orig{who}/$chan> $orig{message}");
        push( @ignore, keys %{ $ignore{$chan} } ) if ( exists $ignore{$chan} );
    }
    elsif ( $msgType =~ /private/i ) {    # private.
        &status("[$orig{who}] $orig{message}");
        $talkchannel = undef;
        $chan        = '_default';
    }
    else {
        &DEBUG("unknown msgType => $msgType.");
    }
    push( @ignore, keys %{ $ignore{'*'} } ) if ( exists $ignore{'*'} );

    if (    ( !$skipmessage or &IsChanConf('seenStoreAll') > 0 )
        and &IsChanConf('sed') > 0
        and &IsChanConf('seen') > 0
        and $msgType       =~ /public/
        and $orig{message} =~ /^s\/([^;\/]*)\/([^;\/]*)\/([g]*)$/ )
    {
        my $sedmsg = $seencache{$who}{'msg'};
        eval "\$sedmsg =~ s/\Q$1\E/\Q$2\E/$3;";
        $sedmsg =~ s/^(.{255}).*$/$1.../;    # 255 char max to prevent flood

        if ( $sedmsg ne $seencache{$who}{'msg'} ) {
            &DEBUG( "sed \""
                  . $orig{message} . "\" \""
                  . $seencache{$who}{'msg'} . "\" \""
                  . $sedmsg
                  . "\"" );
            &msg( $talkchannel, "$orig{who} meant: $sedmsg" );
        }
    }
    elsif ( ( !$skipmessage or &IsChanConf('seenStoreAll') > 0 )
        and &IsChanConf('seen') > 0
        and $msgType =~ /public/ )
    {
        $seencache{$who}{'time'} = time();
        $seencache{$who}{'nick'} = $orig{who};
        $seencache{$who}{'host'} = $uh;
        $seencache{$who}{'chan'} = $talkchannel;
        $seencache{$who}{'msg'}  = $orig{message};
        $seencache{$who}{'msgcount'}++;
    }
    if ( &IsChanConf('minVolunteerLength') > 0 ) {

        # FIXME hack to treat unaddressed as if using addrchar
        $addrchar = 1;
    }
    return if ($skipmessage);
    return unless ( $addrchar or $addressed );

    foreach (@ignore) {
        s/\*/\\S*/g;

        next unless ( eval { $nuh =~ /^$_$/i } );

        # better to ignore an extra message than to allow one to get
        # through, although it would be better to go through ignore
        # checking again.
        if ( time() - ( $cache{ignoreCheckTime} || 0 ) > 60 ) {
            &ignoreCheck();
        }

        &status("IGNORE <$who> $message");
        return;
    }

    if ( defined $nuh ) {
        if ( !defined $userHandle ) {
            &DEBUG('line 1074: need verifyUser?');
            &verifyUser( $who, $nuh );
        }
    }
    else {
        &DEBUG("hookMsg: 'nuh' not defined?");
    }

### For extra debugging purposes...
    if ( $_ = &process() ) {

        #	&DEBUG("IrcHooks: process returned '$_'.");
    }

    # hack to remove +o from ppl with +O flag.
    if (   exists $users{$userHandle}
        && exists $users{$userHandle}{FLAGS}
        && $users{$userHandle}{FLAGS} =~ /O/ )
    {
        $users{$userHandle}{FLAGS} =~ s/o//g;
    }

    return;
}

# this is basically run on on_join or on_quit
sub chanLimitVerify {
    my ($c) = @_;
    $chan = $c;
    my $l = $channels{$chan}{'l'};

    return unless ( &IsChanConf('chanlimitcheck') > 0 );

    if ( scalar keys %netsplit ) {
        &WARN("clV: netsplit active (1, chan = $chan); skipping.");
        return;
    }

    if ( !defined $l ) {
        &DEBUG("$chan: running chanlimitCheck from chanLimitVerify.");
        &chanlimitCheck();
        return;
    }

    # only change it if it's not set.
    my $plus  = &getChanConfDefault( 'chanlimitcheckPlus', 5, $chan );
    my $count = scalar( keys %{ $channels{$chan}{''} } );
    my $int   = &getChanConfDefault( 'chanlimitcheckInterval', 10, $chan );

    my $delta = $count + $plus - $l;

    #   $delta    =~ s/^\-//;

    if ( $plus <= 3 ) {
        &WARN("clc: stupid to have plus at $plus, fix it!");
    }

    if ( exists $cache{chanlimitChange}{$chan} ) {
        if ( time() - $cache{chanlimitChange}{$chan} < $int * 60 ) {
            return;
        }
    }

    &chanServCheck($chan);

    ### TODO: unify code with chanlimitcheck()
    return if ( $delta > 5 );

    &status("clc: big change in limit for $chan ($delta);"
          . "going for it. (was: $l; now: "
          . ( $count + $plus )
          . ')' );

    $conn->mode( $chan, '+l', $count + $plus );
    $cache{chanlimitChange}{$chan} = time();
}

sub chanServCheck {
    ($chan) = @_;

    if ( !defined $chan or $chan =~ /^\s*$/ ) {
        &WARN('chanServCheck: chan == NULL.');
        return 0;
    }

    return unless ( &IsChanConf('chanServCheck') > 0 );

    &VERB( "chanServCheck($chan) called.", 2 );

    if ( &IsParam('nickServ_pass') and !$nickserv ) {
        $conn->who('NickServ');
        return 0;
    }

    # check for first hash then for next hash.
    # TODO: a function for &ischanop()? &isvoice()?
    if (    exists $channels{ lc $chan }
        and exists $channels{ lc $chan }{'o'}{$ident} )
    {
        return 0;
    }

    &status("ChanServ ==> Requesting ops for $chan. (chanServCheck)");
    &msg( 'ChanServ', "OP $chan" );
    return 1;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
