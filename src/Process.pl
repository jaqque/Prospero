###
### Process.pl: Kevin Lenzo 1997-1999
###

#
# process the incoming message
#

use strict;

use vars qw($who $msgType $addressed $message $ident $user $host $chan
  $learnok $talkok $force_public_reply $noreply $addrchar
  $literal $addressedother $userHandle $lobotomized);
use vars qw(%channels %users %param %cache %chanconf %mask %orig %lang);

sub process {
    $learnok            = 0;    # Able to learn?
    $talkok             = 0;    # Able to yap?
    $force_public_reply = 0;
    $literal            = 0;

    return 'X' if $who eq $ident;    # self-message.
    return 'addressedother set' if ($addressedother);

    $talkok = ( $param{'addressing'} =~ /^OPTIONAL$/i or $addressed );
    $learnok = 1 if ($addressed);
    if ( $param{'learn'} =~ /^HUNGRY$/i ) {
        $learnok  = 1;
        #FIXME: why can we talk if we just want to learn?
        #$addrchar = 1;
        #$talkok   = 1;
    }

    &shmFlush();                     # hack.

    # hack to support channel +o as '+o' in bot user file.
    # requires +O in user file.
    # is $who arg lowercase?
    if ( exists $channels{$chan}{o}{ $orig{who} } && &IsFlag('O') eq 'O' ) {
        &status("Gave $who/$chan +o (+O)\'ness");
        $users{$userHandle}{FLAGS} .= 'o';
    }

    # check if we have our head intact.
    if ($lobotomized) {
        if ( $addressed and IsFlag('o') eq 'o' ) {
            my $delta_time = time() - ( $cache{lobotomy}{$who} || 0 );
            &msg( $who, 'give me an unlobotomy.' ) if ( $delta_time > 60 * 60 );
            $cache{lobotomy}{$who} = time();
        }
        return 'LOBOTOMY' unless IsFlag('A');
    }

    # talkMethod.
    if ( $param{'talkMethod'} =~ /^PRIVATE$/i ) {
        if ( $msgType =~ /public/ and $addressed ) {
            &msg( $who,
                    "sorry. i'm in 'PRIVATE' talkMethod mode "
                  . "while you sent a message to me ${msgType}ly." );

            return 'TALKMETHOD';
        }
    }

    # join, must be done before outsider checking.
    if ( $message =~ /^join(\s+(.*))?\s*$/i ) {
        return 'join: not addr' unless ($addressed);

        $2 =~ /^($mask{chan})(\s+(\S+))?/;
        my ( $joinchan, $key ) = ( lc $1, $3 );

        if ( $joinchan eq '' ) {
            &help('join');
            return;
        }

        if ( $joinchan !~ /^$mask{chan}$/ ) {
            &msg( $who, "$joinchan is not a valid channel name." );
            return;
        }

        if ( &IsFlag('o') ne 'o' ) {
            if ( !exists $chanconf{$joinchan} ) {
                &msg( $who, "I am not allowed to join $joinchan." );
                return;
            }

            if ( &validChan($joinchan) ) {
                &msg( $who,
                    "warn: I'm already on $joinchan, joining anyway..." );
            }
        }
        $cache{join}{$joinchan} = $who;    # used for on_join self.

        &status("JOIN $joinchan $key <$who>");
        &msg( $who, "joining $joinchan $key" );
        &joinchan( $joinchan, $key );
        &joinNextChan();                   # hack.

        return;
    }

    # 'identify'
    if ( $msgType =~ /private/ and $message =~ s/^identify//i ) {
        $message =~ s/^\s+|\s+$//g;
        my @array = split / /, $message;

        if ( $who =~ /^_default$/i ) {
            &performStrictReply('you are too eleet.');
            return;
        }

        if ( !scalar @array or scalar @array > 2 ) {
            &help('identify');
            return;
        }

        my $do_nick = $array[1] || $who;

        if ( !exists $users{$do_nick} ) {
            &performStrictReply("nick $do_nick is not in user list.");
            return;
        }

        my $crypt = $users{$do_nick}{PASS};
        if ( !defined $crypt ) {
            &performStrictReply("user $do_nick has no passwd set.");
            return;
        }

        if ( !&ckpasswd( $array[0], $crypt ) ) {
            &performStrictReply("invalid passwd for $do_nick.");
            return;
        }

        my $mask = "$who!$user@" . &makeHostMask($host);
        ### TODO: prevent adding multiple dupe masks?
        ### TODO: make &addHostMask() CMD?
        &performStrictReply("Added $mask for $do_nick...");
        $users{$do_nick}{HOSTS}{$mask} = 1;

        return;
    }

    # 'pass'
    if ( $msgType =~ /private/ and $message =~ s/^pass//i ) {
        $message =~ s/^\s+|\s+$//g;
        my @array = split ' ', $message;

        if ( $who =~ /^_default$/i ) {
            &performStrictReply('you are too eleet.');
            return;
        }

        if ( scalar @array != 1 ) {
            &help('pass');
            return;
        }

        # TODO: use &getUser()?
        my $first = 1;
        foreach ( keys %users ) {
            if ( $users{$_}{FLAGS} =~ /n/ ) {
                $first = 0;
                last;
            }
        }

        if ( !exists $users{$who} and !$first ) {
            &performStrictReply("nick $who is not in user list.");
            return;
        }

        if ($first) {
            &performStrictReply('First time user... adding you as Master.');
            $users{$who}{FLAGS} = 'aemnorst';
        }

        my $crypt = $users{$who}{PASS};
        if ( defined $crypt ) {
            &performStrictReply("user $who already has pass set.");
            return;
        }

        if ( !defined $host ) {
            &WARN('pass: host == NULL.');
            return;
        }

        if ( !scalar keys %{ $users{$who}{HOSTS} } ) {
            my $mask = "*!$user@" . &makeHostMask($host);
            &performStrictReply("Added hostmask '\002$mask\002' to $who");
            $users{$who}{HOSTS}{$mask} = 1;
        }

        $crypt = &mkcrypt( $array[0] );
        $users{$who}{PASS} = $crypt;
        &performStrictReply("new pass for $who, crypt $crypt.");

        return;
    }

    # allowOutsiders.
    if ( &IsParam('disallowOutsiders') and $msgType =~ /private/i ) {
        my $found = 0;

        foreach ( keys %channels ) {

            # don't test for $channel{_default} elsewhere !!!
            next if ( /^\s*$/ || /^_?default$/ );
            next unless ( &IsNickInChan( $who, $_ ) );

            $found++;
            last;
        }

        if ( !$found and scalar( keys %channels ) ) {
            &status("OUTSIDER <$who> $message");
            return 'OUTSIDER';
        }
    }

    # override msgType.
    if ( $msgType =~ /public/ and $message =~ s/^\+// ) {
        &status("Process: '+' flag detected; changing reply to public");
        $msgType = 'public';
        $who     = $chan;      # major hack to fix &msg().
        $force_public_reply++;

        # notice is still NOTICE but to whole channel => good.
    }

    # User Processing, for all users.
    if ($addressed) {
        my $retval;
        return 'SOMETHING parseCmdHook' if &parseCmdHook($message);

        $retval = &userCommands();
        return unless ( defined $retval );
        return if ( $retval eq $noreply );
    }

    ###
    # once useless messages have been parsed out, we match them.
    ###

    # confused? is this for infobot communications?
    foreach ( keys %{ $lang{'confused'} } ) {
        my $y = $_;

        next unless ( $message =~ /^\Q$y\E\s*/ );
        return 'CONFUSO';
    }

    # hello. [took me a while to fix this. -xk]
    if ( $orig{message} =~
/^(\Q$ident\E\S?[:, ]\S?)?\s*(h(ello|i( there)?|owdy|ey|ola))( \Q$ident\E)?\s*$/i
      )
    {
        return '' unless ($talkok);

        # 'mynick: hi' or 'hi mynick' or 'hi'.
        &status('somebody said hello');

        # 50% chance of replying to a random greeting when not addressed
        if ( !defined $5 and $addressed == 0 and rand() < 0.5 ) {
            &status('not returning unaddressed greeting');
            return;
        }

        # customized random message.
        my $tmp = ( rand() < 0.5 ) ? ", $who" : '';
        &performStrictReply( &getRandom( keys %{ $lang{'hello'} } ) . $tmp );
        return;
    }

    # greetings.
    if ( $message =~ /how (the hell )?are (ya|you)( doin\'?g?)?\?*$/ && $talkok ) {

        &performReply( &getRandom( keys %{ $lang{'howareyou'} } ) );
        return;
    }

    # praise.
    if (   $message =~ /you (rock|rewl|rule|are so+ coo+l)/
        || $message =~ /(good (bo(t|y)|g([ui]|r+)rl))|(bot( |\-)?snack)/i )
    {
        return 'praise: no addr' unless ($addressed);

        &performReply( &getRandom( keys %{ $lang{'praise'} } ) );
        return;
    }

    # thanks.
    if ( $message =~ /^than(ks?|x)( you)?( \S+)?/i ) {
        return 'thank: no addr' unless ( $message =~ /$ident/ or $talkok );

        &performReply( &getRandom( keys %{ $lang{'welcome'} } ) );
        return;
    }

    ###
    ### bot commands...
    ###

    # karma. set...
    if (   $msgType =~ /public/i
        && $message =~ /^(\S+)(--|\+\+)\s*$/
        && $addressed
        && &IsChanConfOrWarn('karma') )
    {

    # to request factoids such as 'g++' or 'libstdc++', append '?' to the query.
        my ( $term, $inc ) = ( lc $1, $2 );

        if ( lc $term eq lc $who ) {
            &msg( $who, "please don't karma yourself" );
            return;
        }

        my $karma =
          &sqlSelect( 'stats', 'counter', { nick => $term, type => 'karma' } )
          || 0;
        if ( $inc eq '++' ) {
            $karma++;
        }
        else {
            $karma--;
        }

        &sqlSet(
            'stats',
            { 'nick' => $term, type => 'karma', channel => 'PRIVATE' },
            {
                'time'  => time(),
                counter => $karma,
            }
        );

        return;
    }

    # here's where the external routines get called.
    # if they return anything but null, that's the 'answer'.
    if ($addressed) {
        my $er = &Modules();
        if ( !defined $er ) {
            return 'SOMETHING 1';
        }

        # allow administration of bot via messages (default is DCC CHAT only)
        if ( &IsFlag('A') ) {
            # UserDCC.pl should autoload now from IRC/. Remove if desired
            #&loadMyModule('UserDCC');
            $er = &userDCC();
            if ( !defined $er ) {
                return 'SOMETHING 2';
            }
        }

        if ( 0 and $addrchar ) {
            &msg( $who,
"I don't trust people to use the core commands while addressing me in a short-cut way."
            );
            return;
        }
    }

    if (    &IsParam('factoids')
        and $param{'DBType'} =~ /^(mysql|sqlite(2)?|pgsql)$/i )
    {
        &FactoidStuff();
    }
    elsif ( $param{'DBType'} =~ /^none$/i ) {
        return 'NO FACTOIDS.';
    }
    else {
        &ERROR("INVALID FACTOID SUPPORT? ($param{'DBType'})");
        &shutdown();
        exit 0;
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
