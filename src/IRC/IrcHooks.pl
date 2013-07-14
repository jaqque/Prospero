#
# IrcHooks.pl: IRC Hooks stuff.
#      Author: dms
#     Version: 20000126
#        NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#
use vars qw(%chanconf);

# GENERIC. TO COPY.
sub on_generic {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick    = $event->nick();
    my $chan    = ( $event->to )[0];

    &DEBUG("on_generic: nick => '$nick'.");
    &DEBUG("on_generic: chan => '$chan'.");

    foreach ( $event->args ) {
        &DEBUG("on_generic: args => '$_'.");
    }
}

sub on_action {
    $conn = shift(@_);
    my ($event) = @_;
    my ( $nick, $args ) = ( $event->nick, $event->args );
    my $chan = ( $event->to )[0];

    if ( $chan eq $ident ) {
        &status("* [$nick] $args");
    }
    else {
        &status("* $nick/$chan $args");
    }
}

sub on_chat {
    $conn = shift(@_);
    my ($event) = @_;
    my $msg     = ( $event->args )[0];
    my $sock    = ( $event->to )[0];
    my $nick    = lc $event->nick();

    if ( !exists $nuh{$nick} ) {
        &DEBUG("chat: nuh{$nick} doesn't exist; trying WHOIS .");
        $conn->whois($nick);
        return;
    }

    ### set vars that would have been set in hookMsg.
    $userHandle    = '';                        # reset.
    $who           = lc $nick;
    $message       = $msg;
    $orig{who}     = $nick;
    $orig{message} = $msg;
    $nuh           = $nuh{$who};
    $uh            = ( split /\!/, $nuh )[1];
    $h             = ( split /\@/, $uh )[1];
    $addressed     = 1;
    $msgType       = 'chat';

    if ( !exists $dcc{'CHATvrfy'}{$nick} ) {
        $userHandle = &verifyUser( $who, $nuh );
        my $crypto  = $users{$userHandle}{PASS};
        my $success = 0;

        if ( $userHandle eq '_default' ) {
            &WARN('DCC CHAT: _default/guest not allowed.');
            return;
        }

        ### TODO: prevent users without CRYPT chatting.
        if ( !defined $crypto ) {
            &TODO('dcc close chat');
            &msg( $who, 'nope, no guest logins allowed...' );
            return;
        }

        if ( &ckpasswd( $msg, $crypto ) ) {

            # stolen from eggdrop.
            $conn->privmsg( $sock, "Connected to $ident" );
            $conn->privmsg( $sock,
                'Commands start with "." (like ".quit" or ".help")' );
            $conn->privmsg( $sock,
                'Everything else goes out to the party line.' );

            &dccStatus(2) unless ( exists $sched{'dccStatus'}{RUNNING} );

            $success++;

        }
        else {
            &status('DCC CHAT: incorrect pass; closing connection.');
            &DEBUG("chat: sock => '$sock'.");
###	    $sock->close();
            delete $dcc{'CHAT'}{$nick};
            &FIXME('chat: after closing sock.');
            ### BUG: close seizes bot. why?
        }

        if ($success) {
            &status("DCC CHAT: user $nick is here!");
            &DCCBroadcast("*** $nick ($uh) joined the party line.");

            $dcc{'CHATvrfy'}{$nick} = $userHandle;

            return if ( $userHandle eq '_default' );

            &dccsay( $nick, "Flags: $users{$userHandle}{FLAGS}" );
        }

        return;
    }

    &status("$b_red=$b_cyan$who$b_red=$ob $message");

    if ( $message =~ s/^\.// ) {    # dcc chat commands.
        ### TODO: make use of &Forker(); here?
        &loadMyModule('UserDCC');

        &DCCBroadcast( "#$who# $message", 'm' );

        my $retval = &userDCC();
        return unless ( defined $retval );
        return if ( $retval eq $noreply );

        $conn->privmsg( $dcc{'CHAT'}{$who}, 'Invalid command.' );

    }
    else {    # dcc chat arena.

        foreach ( keys %{ $dcc{'CHAT'} } ) {
            $conn->privmsg( $dcc{'CHAT'}{$_}, "<$who> $orig{message}" );
        }
    }

    return 'DCC CHAT MESSAGE';
}

# is there isoff? how do we know if someone signs off?
sub on_ison {
    $conn = shift(@_);
    my ($event) = @_;
    my $x1      = ( $event->args )[0];
    my $x2      = ( $event->args )[1];
    $x2 =~ s/\s$//;

    &DEBUG("on_ison: x1 = '$x1', x2 => '$x2'");
}

sub on_connected {
    $conn = shift(@_);

    # update IRCStats.
    $ident = $conn->nick();
    $ircstats{'ConnectTime'} = time();
    $ircstats{'ConnectCount'}++;
    if ( defined $ircstats{'DisconnectTime'} ) {
        $ircstats{'OffTime'} += time() - $ircstats{'DisconnectTime'};
    }

    # first time run.
    if ( !exists $users{_default} ) {
        &status('!!! First time run... adding _default user.');
        $users{_default}{FLAGS} = 'amrt';
        $users{_default}{HOSTS}{'*!*@*'} = 1;
    }

    if ( scalar keys %users < 2 ) {
        &status( '!' x 40 );
        &status(
"!!! Ok.  Now type '/msg $ident PASS <pass>' to get master access through DCC CHAT."
        );
        &status( '!' x 40 );
    }

    # end of first time run.

    if ( &IsChanConf('Wingate') > 0 ) {
        my $file = "$bot_base_dir/$param{'ircUser'}.wingate";
        open( IN, $file );
        while (<IN>) {
            chop;
            next unless (/^(\S+)\*$/);
            push( @wingateBad, $_ );
        }
        close IN;
    }

    if ($firsttime) {
        &ScheduleThis( 1, 'setupSchedulers' );
        $firsttime = 0;
    }

    if ( &IsParam('ircUMode') ) {
        &VERB( "Attempting change of user modes to $param{'ircUMode'}.", 2 );
        if ( $param{'ircUMode'} !~ /^[-+]/ ) {
            &WARN('ircUMode had no +- prefix; adding +');
            $param{'ircUMode'} = '+' . $param{'ircUMode'};
        }

        &rawout("MODE $ident $param{'ircUMode'}");
    }

    # ok, we're free to do whatever we want now. go for it!
    $running = 1;

    # add ourself to notify.
    $conn->ison( $conn->nick() );

    # Q, as on quakenet.org.
    if ( &IsParam('Q_pass') ) {
        &status('Authing to Q...');
        &rawout(
"PRIVMSG Q\@CServe.quakenet.org :AUTH $param{'Q_user'} $param{'Q_pass'}"
        );
    }

    &status('End of motd. Now lets join some channels...');

    #&joinNextChan();
}

sub on_endofwho {
    $conn = shift(@_);
    my ($event) = @_;

    #    &DEBUG("endofwho: chan => $chan");
    $chan ||= ( $event->args )[1];

    #    &DEBUG("endofwho: chan => $chan");

    if ( exists $cache{countryStats} ) {
        &do_countrystats();
    }
}

sub on_dcc {
    $conn = shift(@_);
    my ($event) = @_;
    my $type = uc( ( $event->args )[1] );
    my $nick = lc $event->nick();

    &status("on_dcc type=$type nick=$nick sock=$sock");

    # pity Net::IRC doesn't store nuh. Here's a hack :)
    if ( !exists $nuh{ lc $nick } ) {
        $conn->whois($nick);
        $nuh{$nick} = 'GETTING-NOW';    # trying.
    }
    $type ||= '???';

    if ( $type eq 'SEND' ) {            # GET for us.
            # incoming DCC SEND. we're receiving a file.
        my $get = ( $event->args )[2];
        &status(
            "DCC: not Initializing GET from $nick to '$param{tempDir}/$get'");

        # FIXME: do we want to get anything?
        return;

        #open(DCCGET,">$param{tempDir}/$get");
        #$conn->new_get($event, \*DCCGET);

    }
    elsif ( $type eq 'GET' ) {    # SEND for us?
        &status("DCC: not Initializing SEND for $nick.");

        # FIXME: do we want to do anything?
        return;
        $conn->new_send( $event->args );

    }
    elsif ( $type eq 'CHAT' ) {
        &status("DCC: Initializing CHAT for $nick.");
        $conn->new_chat($event);

        #	$conn->new_chat(1, $nick, $event->host);

    }
    else {
        &WARN("${b_green}DCC $type$ob (1)");
    }
}

sub on_dcc_close {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick    = $event->nick();
    my $sock    = ( $event->to )[0];

    # DCC CHAT close on fork exit workaround.
    if ( $bot_pid != $$ ) {
        &WARN('run-away fork; exiting.');
        &delForked($forker);
    }

    if ( exists $dcc{'SEND'}{$nick} and -f "$param{tempDir}/$nick.txt" ) {
        &status("${b_green}DCC SEND$ob close from $b_cyan$nick$ob");

        &status("dcc_close: purging DCC send $nick.txt");
        unlink "$param{tempDir}/$nick.txt";

        delete $dcc{'SEND'}{$nick};
    }
    elsif ( exists $dcc{'CHAT'}{$nick} and $dcc{'CHAT'}{$nick} eq $sock ) {
        &status("${b_green}DCC CHAT$ob close from $b_cyan$nick$ob");
        delete $dcc{'CHAT'}{$nick};
        delete $dcc{'CHATvrfy'}{$nick};
    }
    else {
        &status("${b_green}DCC$ob UNKNOWN close from $b_cyan$nick$ob (2)");
    }
}

sub on_dcc_open {
    $conn = shift(@_);
    my ($event) = @_;
    my $type = uc( ( $event->args )[0] );
    my $nick = lc $event->nick();
    my $sock = ( $event->to )[0];

    &status("on_dcc_open type=$type nick=$nick sock=$sock");

    $msgType = 'chat';
    $type ||= '???';
    ### BUG: who is set to bot's nick?

    # lets do it.
    if ( $type eq 'SEND' ) {
        &status("${b_green}DCC lGET$ob established with $b_cyan$nick$ob");

    }
    elsif ( $type eq 'CHAT' ) {

        # very cheap hack.
        ### TODO: run ScheduleThis inside on_dcc_open_chat recursively
        ###	1,3,5,10 seconds then fail.
        if ( $nuh{$nick} eq 'GETTING-NOW' ) {
            &ScheduleThis( 3 / 60, 'on_dcc_open_chat', $nick, $sock );
        }
        else {
            on_dcc_open_chat( undef, $nick, $sock );
        }

    }
    elsif ( $type eq 'SEND' ) {
        &status('Starting DCC receive.');
        foreach ( $event->args ) {
            &status("  => '$_'.");
        }

    }
    else {
        &WARN("${b_green}DCC $type$ob (3)");
    }
}

# really custom sub to get NUH since Net::IRC doesn't appear to support
# it.
sub on_dcc_open_chat {
    my ( undef, $nick, $sock ) = @_;

    if ( $nuh{$nick} eq 'GETTING-NOW' ) {
        &FIXME("getting nuh for $nick failed.");
        return;
    }

    &status(
"${b_green}DCC CHAT$ob established with $b_cyan$nick$ob $b_yellow($ob$nuh{$nick}$b_yellow)$ob"
    );

    &verifyUser( $nick, $nuh{ lc $nick } );

    if ( !exists $users{$userHandle}{HOSTS} ) {
        &performStrictReply(
            'you have no hosts defined in my user file; rejecting.');
        $sock->close();
        return;
    }

    my $crypto = $users{$userHandle}{PASS};
    $dcc{'CHAT'}{$nick} = $sock;

    # TODO: don't make DCC CHAT established in the first place.
    if ( $userHandle eq '_default' ) {
        &dccsay( $nick, '_default/guest not allowed' );
        $sock->close();
        return;
    }

    if ( defined $crypto ) {
        &status( "DCC CHAT: going to use $nick\'s crypt." );
        &dccsay( $nick, 'Enter your password.' );
    }
    else {

        #	&dccsay($nick,"Welcome to infobot DCC CHAT interface, $userHandle.");
    }
}

sub on_disconnect {
    $conn = shift(@_);
    my ($event) = @_;
    my $from    = $event->from();
    my $what    = ( $event->args )[0];
    my $mynick  = $conn->nick();

    &status("$mynick disconnect from $from ($what).");
    $ircstats{'DisconnectTime'}   = time();
    $ircstats{'DisconnectReason'} = $what;
    $ircstats{'DisconnectCount'}++;
    $ircstats{'TotalTime'} += time() - $ircstats{'ConnectTime'}
      if ( $ircstats{'ConnectTime'} );

    # clear any variables on reconnection.
    $nickserv = 0;

    &clearIRCVars();

    if ( !defined $conn ) {
        &WARN('on_disconnect: self is undefined! WTF');
        &DEBUG('running function irc... lets hope this works.');
        &irc();
        return;
    }

    &WARN('scheduling call ircCheck() in 60s');
    &clearIRCVars();
    &ScheduleThis( 1, 'ircCheck' );
}

sub on_endofnames {
    $conn = shift(@_);
    my ($event) = @_;
    my $chan = ( $event->args )[1];

    # sync time should be done in on_endofwho like in BitchX
    if ( exists $cache{jointime}{$chan} ) {
        my $delta_time =
          sprintf( '%.03f', &timedelta( $cache{jointime}{$chan} ) );
        $delta_time = 0 if ( $delta_time <= 0 );
        if ( $delta_time > 100 ) {
            &WARN("endofnames: delta_time > 100 ($delta_time)");
        }

        &status("$b_blue$chan$ob: sync in ${delta_time}s.");
    }

    $conn->mode($chan);

    my $txt;
    my @array;
    foreach ( 'o', 'v', '' ) {
        my $count = scalar( keys %{ $channels{$chan}{$_} } );
        next unless ($count);

        $txt = 'total' if ( $_ eq '' );
        $txt = 'voice' if ( $_ eq 'v' );
        $txt = 'ops'   if ( $_ eq 'o' );

        push( @array, "$count $txt" );
    }
    my $chanstats = join( ' || ', @array );
    &status("$b_blue$chan$ob: [$chanstats]");

    &chanServCheck($chan);

    # schedule used to solve ircu (OPN) 'target too fast' problems.
    $conn->schedule( 5, sub { &joinNextChan(); } );
}

sub on_init {
    $conn = shift(@_);
    my ($event) = @_;
    my (@args)  = ( $event->args );
    shift @args;

    &status("@args");
}

sub on_invite {
    $conn = shift(@_);
    my ($event) = @_;
    my $chan = lc( ( $event->args )[0] );
    my $nick = $event->nick;

    if ( $nick =~ /^\Q$ident\E$/ ) {
        &DEBUG('on_invite: self invite.');
        return;
    }

    ### TODO: join key.
    if ( exists $chanconf{$chan} ) {

        # it's still buggy :/
        if ( &validChan($chan) ) {
            &msg( $who, "i'm already in \002$chan\002." );

            #	    return;
        }

        &status("invited to $b_blue$chan$ob by $b_cyan$nick$ob");
        &joinchan($chan);
    }
}

sub on_join {
    $conn = shift(@_);
    my ($event) = @_;
    my ( $user, $host ) = split( /\@/, $event->userhost );
    $chan    = lc( ( $event->to )[0] );    # CASING!!!!
    $who     = $event->nick();
    $msgType = 'public';
    my $i = scalar( keys %{ $channels{$chan} } );
    my $j = $cache{maxpeeps}{$chan} || 0;

    if ( !&IsParam('noSHM')
        && time() > ( $sched{shmFlush}{TIME} || time() ) + 3600 )
    {
        &DEBUG('looks like schedulers died somewhere... restarting...');
        &setupSchedulers();
    }

    $chanstats{$chan}{'Join'}++;
    $userstats{ lc $who }{'Join'} = time() if ( &IsChanConf('seenStats') > 0 );
    $cache{maxpeeps}{$chan} = $i if ( $i > $j );

    &joinfloodCheck( $who, $chan, $event->userhost );

    # netjoin detection.
    my $netsplit = 0;
    if ( exists $netsplit{ lc $who } ) {
        delete $netsplit{ lc $who };
        $netsplit = 1;

        if ( !scalar keys %netsplit ) {
            &DEBUG('on_join: netsplit hash is now empty!');
            undef %netsplitservers;
            &netsplitCheck();    # any point in running this?
            &chanlimitCheck();
        }
    }

    if ( $netsplit and !exists $cache{netsplit} ) {
        &VERB('on_join: ok.... re-running chanlimitCheck in 60.', 2);
        $conn->schedule(
            60,
            sub {
                &chanlimitCheck();
                delete $cache{netsplit};
            }
        );

        $cache{netsplit} = time();
    }

    # how to tell if there's a netjoin???

    my $netsplitstr = '';
    $netsplitstr = " $b_yellow\[${ob}NETSPLIT VICTIM$b_yellow]$ob"
      if ($netsplit);
    &status(
">>> join/$b_blue$chan$ob $b_cyan$who$ob $b_yellow($ob$user\@$host$b_yellow)$ob$netsplitstr"
    );

    $channels{$chan}{''}{$who}++;
    $nuh = $who . '!' . $user . '@' . $host;
    $nuh{ lc $who } = $nuh unless ( exists $nuh{ lc $who } );

    ### on-join bans.
    my @bans;
    push( @bans, keys %{ $bans{$chan} } ) if ( exists $bans{$chan} );
    push( @bans, keys %{ $bans{'*'} } )   if ( exists $bans{'*'} );

    foreach (@bans) {
        my $ban = $_;
        s/\?/./g;
        s/\*/\\S*/g;
        my $mask = $_;
        next unless ( $nuh =~ /^$mask$/i );

        ### TODO: check $channels{$chan}{'b'} if ban already exists.
        foreach ( keys %{ $channels{$chan}{'b'} } ) {
            &DEBUG(" bans_on_chan($chan) => $_");
        }

        my $reason = 'no reason';
        foreach ( $chan, '*' ) {
            next unless ( exists $bans{$_} );
            next unless ( exists $bans{$_}{$ban} );

            my @array = @{ $bans{$_}{$ban} };

            $reason = $array[4] if ( $array[4] );
            last;
        }

        &ban( $ban, $chan );
        &kick( $who, $chan, $reason );

        last;
    }

    # no need to go further.
    return if ($netsplit);

    # who == bot.
    if ( $who =~ /^\Q$ident\E$/i ) {
        if ( defined( my $whojoin = $cache{join}{$chan} ) ) {
            &msg( $chan, "Okay, I'm here. (courtesy of $whojoin)" );
            delete $cache{join}{$chan};
            &joinNextChan();    # hack.
        }

        ### TODO: move this to &joinchan()?
        $cache{jointime}{$chan} = &timeget();
        $conn->who($chan);

        return;
    }

    ### ROOTWARN:
    &rootWarn( $who, $user, $host, $chan )
      if ( &IsChanConf('RootWarn') > 0
        && $user =~ /^~?r(oo|ew|00)t$/i );

    ### emit a message based on who just joined
    &onjoin( $who, $user, $host, $chan ) if ( &IsChanConf('OnJoin') > 0 );

    ### NEWS:
    if ( &IsChanConf('News') > 0 && &IsChanConf('newsKeepRead') > 0 ) {
        if ( !&loadMyModule('News') ) {    # just in case.
            &DEBUG('could not load news.');
        }
        else {
            &News::latest($chan);
        }
    }

    ### botmail:
    if ( &IsChanConf('botmail') > 0 ) {
        &botmail::check( lc $who );
    }

    ### wingate:
    &wingateCheck();
}

sub on_kick {
    $conn = shift(@_);
    my ($event) = @_;
    my ( $chan, $reason ) = $event->args;
    my $kicker = $event->nick;
    my $kickee = ( $event->to )[0];
    my $uh     = $event->userhost();

    &status(
">>> kick/$b_blue$chan$ob [$b$kickee!$uh$ob] by $b_cyan$kicker$ob $b_yellow($ob$reason$b_yellow)$ob"
    );

    $chan = lc $chan;    # forgot about this, found by xsdg, 20001229.
    $chanstats{$chan}{'Kick'}++;

    if ( $kickee eq $ident ) {
        &clearChanVars($chan);

        &status("SELF attempting to rejoin lost channel $chan");
        &joinchan($chan);
    }
    else {
        &delUserInfo( $kickee, $chan );
    }
}

sub on_mode {
    $conn = shift(@_);
    my ($event) = @_;
    my ( $user, $host ) = split( /\@/, $event->userhost );
    my @args = $event->args();
    my $nick = $event->nick();
    $chan = ( $event->to )[0];

    # last element is empty... so nuke it.
    pop @args while ( $args[$#args] eq '' );

    if ( $nick eq $chan ) {    # UMODE
        &status(
            ">>> mode $b_yellow\[$ob$b@args$b_yellow\]$ob by $b_cyan$nick$ob");
    }
    else {                     # MODE
        &status(
">>> mode/$b_blue$chan$ob $b_yellow\[$ob$b@args$b_yellow\]$ob by $b_cyan$nick$ob"
        );
        &hookMode( $nick, @args );
    }
}

sub on_modeis {
    $conn = shift(@_);
    my ($event) = @_;
    my ( $myself, undef, @args ) = $event->args();
    my $nick = $event->nick();
    $chan = ( $event->args() )[1];

    &hookMode( $nick, @args );
}

sub on_msg {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick    = $event->nick;
    my $msg     = ( $event->args )[0];

    ( $user, $host ) = split( /\@/, $event->userhost );
    $uh      = $event->userhost();
    $nuh     = $nick . '!' . $uh;
    $msgtime = time();
    $h       = $host;

    if ( $nick eq $ident ) {    # hopefully ourselves.
        if ( $msg eq 'TEST' ) {
            &status("IRCTEST: Yes, we're alive.");
            delete $cache{connect};
            return;
        }
    }

    &hookMsg( 'private', undef, $nick, $msg );
    $who     = '';
    $chan    = '';
    $msgType = '';
}

sub on_names {
    $conn = shift(@_);
    my ($event) = @_;
    my @args    = $event->args;
    my $chan    = lc $args[2];    # CASING, the last of them!

    foreach ( split / /, @args[ 3 .. $#args ] ) {
        $channels{$chan}{'o'}{$_}++ if s/\@//;
        $channels{$chan}{'v'}{$_}++ if s/\+//;
        $channels{$chan}{''}{$_}++;
    }
}

sub on_nick {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick    = $event->nick();
    my $newnick = ( $event->args )[0];

    if ( exists $netsplit{ lc $newnick } ) {
        &status(
"Netsplit: $newnick/$nick came back from netsplit and changed to original nick! removing from hash."
        );
        delete $netsplit{ lc $newnick };
        &netsplitCheck() if ( time() != $sched{netsplitCheck}{TIME} );
    }

    my ( $chan, $mode );
    foreach $chan ( keys %channels ) {
        foreach $mode ( keys %{ $channels{$chan} } ) {
            next unless ( exists $channels{$chan}{$mode}{$nick} );

            $channels{$chan}{$mode}{$newnick} = $channels{$chan}{$mode}{$nick};
        }
    }

    # TODO: do %flood* aswell.

    &delUserInfo( $nick, keys %channels );
    $nuh{ lc $newnick } = $nuh{ lc $nick };
    delete $nuh{ lc $nick };

    if ( $nick eq $conn->nick() ) {
        &status(">>> I materialized into $b_green$newnick$ob from $nick");
        $ident = $newnick;
        $conn->nick($newnick);
    }
    else {
        &status(">>> $b_cyan$nick$ob materializes into $b_green$newnick$ob");
        my $mynick = $conn->nick();
        if ( $nick =~ /^\Q$mynick\E$/i ) {
            &getNickInUse();
        }
    }
}

sub on_nick_taken {
    $conn = shift(@_);
    my $nick = $conn->nick();

    #my $newnick = $nick . int(rand 10);
    my $newnick = $nick . '_';

    &DEBUG("on_nick_taken: nick => $nick");

    &status("nick taken ($nick); preparing nick change.");

    $conn->whois($nick);

    #$conn->schedule(5, sub {
    &status("nick taken; changing to temporary nick ($nick -> $newnick).");
    &nick($newnick);

    #} );
}

sub on_notice {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick    = $event->nick();
    my $chan    = ( $event->to )[0];
    my $args    = ( $event->args )[0];

    if ( $nick =~ /^NickServ$/i ) {    # nickserv.
        &status("NickServ: <== '$args'");

        my $check = 0;
        $check++ if ( $args =~ /^This nickname is registered/i );
        $check++ if ( $args =~ /nickname.*owned/i );

        if ($check) {
            &status('nickserv told us to register; doing it.');

            if ( &IsParam('nickServ_pass') ) {
                &status('NickServ: ==> Identifying.');
                &rawout("PRIVMSG NickServ :IDENTIFY $param{'nickServ_pass'}");
                return;
            }
            else {
                &status("We can't tell nickserv a passwd ;(");
            }
        }

        # password accepted.
        if ( $args =~ /^Password a/i ) {
            my $done = 0;

            foreach ( &ChanConfList('chanServ_ops') ) {
                next unless &chanServCheck($_);
                next if ($done);
                &DEBUG(
                    'nickserv activated or restarted; doing chanserv check.');
                $done++;
            }

            $nickserv++;
        }

    }
    elsif ( $nick =~ /^ChanServ$/i ) {    # chanserv.
        &status("ChanServ: <== '$args'.");

    }
    else {
        if ( $chan =~ /^$mask{chan}$/ ) {    # channel notice.
            &status("-$nick/$chan- $args");
        }
        else {
            $server = $nick unless ( defined $server );
            &status("-$nick- $args");        # private or server notice.
        }
    }
}

sub on_other {
    $conn = shift(@_);
    my ($event) = @_;
    my $chan    = ( $event->to )[0];
    my $nick    = $event->nick;

    &status('!!! other called.');
    &status("!!! $event->args");
}

sub on_part {
    $conn = shift(@_);
    my ($event) = @_;
    $chan = lc( ( $event->to )[0] );    # CASING!!!
    my $mynick   = $conn->nick();
    my $nick     = $event->nick;
    my $userhost = $event->userhost;
    $who     = $nick;
    $msgType = 'public';

    if ( !exists $channels{$chan} ) {
        &DEBUG("on_part: found out $mynick is on $chan!");
        $channels{$chan} = 1;
    }

    if ( exists $floodjoin{$chan}{$nick}{Time} ) {
        delete $floodjoin{$chan}{$nick};
    }

    $chanstats{$chan}{'Part'}++;
    &delUserInfo( $nick, $chan );
    if ( $nick eq $ident ) {
        &clearChanVars($chan);
    }

    if ( !&IsNickInAnyChan($nick) and &IsChanConf('seenStats') > 0 ) {
        delete $userstats{ lc $nick };
    }

    &status(
">>> part/$b_blue$chan$ob $b_cyan$nick$ob $b_yellow($ob$userhost$b_yellow)$ob"
    );
}

sub on_ping {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick = $event->nick;

    $conn->ctcp_reply( $nick, join( ' ', ( $event->args ) ) );
    &status(
        ">>> ${b_green}CTCP PING$ob request from $b_cyan$nick$ob received.");
}

sub on_ping_reply {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick    = $event->nick;
    my $t       = ( $event->args )[1];
    if ( !defined $t ) {
        &WARN('on_ping_reply: t == undefined.');
        return;
    }

    my $lag = time() - $t;

    &status(">>> ${b_green}CTCP PING$ob reply from $b_cyan$nick$ob: $lag sec.");
}

sub on_public {
    $conn = shift(@_);
    my ($event) = @_;
    my $msg = ( $event->args )[0];
    $chan = lc( ( $event->to )[0] );    # CASING.
    my $nick = $event->nick;
    $who     = $nick;
    $uh      = $event->userhost();
    $nuh     = $nick . '!' . $uh;
    $msgType = 'public';

    # TODO: move this out of hookMsg to here?
    ( $user, $host ) = split( /\@/, $uh );
    $h = $host;

    # rare case should this happen - catch it just in case.
    if ( $bot_pid != $$ ) {
        &ERROR('run-away fork; exiting.');
        &delForked($forker);
    }

    $msgtime = time();
    $lastWho{$chan} = $nick;
    ### TODO: use $nick or lc $nick?
    if ( &IsChanConf('seenStats') > 0 ) {
        $userstats{ lc $nick }{'Count'}++;
        $userstats{ lc $nick }{'Time'} = time();
    }

    # cache it.
    my $time = time();
    if ( !$cache{ircTextCounters} ) {
        &DEBUG('caching ircTextCounters for first time.');
        my @str = split( /\s+/, &getChanConf('ircTextCounters') );
        for (@str) { $_ = quotemeta($_); }
        $cache{ircTextCounters} = join( '|', @str );
    }

    my $str = $cache{ircTextCounters};
    if ( $str && $msg =~ /^($str)[\s!\.]?$/i ) {
        my $x = $1;

        &VERB( "textcounters: $x matched for $who", 2 );
        my $c = $chan || 'PRIVATE';

        # better to do 'counter=counter+1'.
        # but that will avoid time check.
        my ( $v, $t ) = &sqlSelect(
            'stats',
            'counter,time',
            {
                nick    => $who,
                type    => $x,
                channel => $c,
            }
        );
        $v++;

        # don't allow ppl to cheat the stats :-)
        if ( ( defined $t && $time - $t > 60 ) or ( !defined $t ) ) {
            &sqlSet(
                'stats',
                {
			        'nick' => $who,
                    'type'    => $x,
                    'channel' => $c,
                },
                {
                    time    => $time,
                    counter => $v,
                }
            );
        }
    }

    &hookMsg( 'public', $chan, $nick, $msg );
    $chanstats{$chan}{'PublicMsg'}++;
    $who     = '';
    $chan    = '';
    $msgType = '';
}

sub on_quit {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick    = $event->nick();
    my $reason  = ( $event->args )[0];

    # hack for ICC.
    $msgType = 'public';
    $who     = $nick;
###    $chan	= $reason;	# no.

    my $count = 0;
    foreach ( grep !/^_default$/, keys %channels ) {

        # fixes inconsistent chanstats bug #1.
        if ( !&IsNickInChan( $nick, $_ ) ) {
            $count++;
            next;
        }
        $chanstats{$_}{'SignOff'}++;
    }

    if ( $count == scalar keys %channels ) {
        &DEBUG("on_quit: nick $nick was not found in any chan.");
    }

    # should fix chanstats inconsistencies bug #2.
    if ( $reason =~ /^($mask{host})\s($mask{host})$/ ) {    # netsplit.
        $reason = "NETSPLIT: $1 <=> $2";

        # chanlimit code.
        foreach $chan ( &getNickInChans($nick) ) {
            next unless ( &IsChanConf('chanlimitcheck') > 0 );
            next unless ( exists $channels{$_}{'l'} );

            &DEBUG("on_quit: netsplit detected on $_; disabling chan limit.");
            $conn->mode( $_, '-l' );
        }

        $netsplit{ lc $nick } = time();
        if ( !exists $netsplitservers{$1}{$2} ) {
            &status("netsplit detected between $1 and $2 at ["
                  . scalar(gmtime)
                  . ']' );
            $netsplitservers{$1}{$2} = time();
        }
    }

    my $chans = join( ' ', &getNickInChans($nick) );
    &status(
">>> $b_cyan$nick$ob has signed off IRC $b_red($ob$reason$b_red)$ob [$chans]"
    );

    ###
    ### ok... lets clear out the cache
    ###
    &delUserInfo( $nick, keys %channels );
    if ( exists $nuh{ lc $nick } ) {
        delete $nuh{ lc $nick };
    }
    else {

        # well.. it's good but weird that this has happened - lets just
        # be quiet about it.
    }
    delete $userstats{ lc $nick } if ( &IsChanConf('seenStats') > 0 );
    delete $chanstats{ lc $nick };
    ###

    # if we have a temp nick, and whoever is camping on our main nick leaves
    # revert to main nick. Note that Net::IRC only knows our main nick
    if ( $nick eq $conn->nick() ) {
        &status("nickchange: own nick \"$nick\" became free; changing.");
        &nick($mynick);
    }
}

sub on_targettoofast {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick = $event->nick();
    my ( $me, $chan, $why ) = $event->args();

    ### TODO: incomplete.
    if ( $why =~ /.* wait (\d+) second/ ) {
        my $sleep = $1;
        my $max   = 10;

        if ( $sleep > $max ) {
            &status("targettoofast: going to sleep for $max ($sleep)...");
            $sleep = $max;
        }
        else {
            &status("targettoofast: going to sleep for $sleep");
        }

        my $delta = time() - ( $cache{sleepTime} || 0 );
        if ( $delta > $max + 2 ) {
            sleep $sleep;
            $cache{sleepTime} = time();
        }

        return;
    }

    if ( !exists $cache{TargetTooFast} ) {
        &DEBUG("on_ttf: failed: $why");
        $cache{TargetTooFast}++;
    }
}

sub on_topic {
    $conn = shift(@_);
    my ($event) = @_;

    if ( scalar( $event->args ) == 1 ) {    # change.
        my $topic = ( $event->args )[0];
        my $chan  = ( $event->to )[0];
        my $nick  = $event->nick();

        ###
        # WARNING:
        #	race condition here. To fix, change '1' to '0'.
        #	This will keep track of topics set by bot only.
        ###
        # UPDATE:
        #	this may be fixed at a later date with topic queueing.
        ###

        $topic{$chan}{'Current'} = $topic if (1);
        $chanstats{$chan}{'Topic'}++;

        &status(">>> topic/$b_blue$chan$ob by $b_cyan$nick$ob -> $topic");
    }
    else {    # join.
        my ( $nick, $chan, $topic ) = $event->args;
        if ( &IsChanConf('Topic') > 0 ) {
            $topic{$chan}{'Current'} = $topic;
            &topicAddHistory( $chan, $topic );
        }

        $topic = &fixString( $topic, 1 );
        &status(">>> topic/$b_blue$chan$ob is $topic");
    }
}

sub on_topicinfo {
    $conn = shift(@_);
    my ($event) = @_;
    my ( $myself, $chan, $setby, $time ) = $event->args();

    my $timestr;
    if ( time() - $time > 60 * 60 * 24 ) {
        $timestr = 'at ' . gmtime $time;
    }
    else {
        $timestr = &Time2String( time() - $time ) . ' ago';
    }

    &status(">>> set by $b_cyan$setby$ob $timestr");
}

sub on_crversion {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick = $event->nick();
    my $ver;

    if ( scalar $event->args() != 1 ) {    # old.
        $ver = join ' ', $event->args();
        $ver =~ s/^VERSION //;
    }
    else {                                 # new.
        $ver = ( $event->args() )[0];
    }

    if ( grep /^\Q$nick\E$/i, @vernick ) {
        &WARN("nick $nick found in vernick ($ver); skipping.");
        return;
    }
    push( @vernick, $nick );

    &DEBUG("on_crversion: Got '$ver' from $nick");

    if ( $ver =~ /bitchx/i ) {
        $ver{bitchx}{$nick} = $ver;

    }
    elsif ( $ver =~ /infobot/i ) {
        $ver{infobot}{$nick} = $ver;

    }
    elsif ( $ver =~ /(xc\!|xchat)/i ) {
        $ver{xchat}{$nick} = $ver;

    }
    elsif ( $ver =~ /irssi/i ) {
        $ver{irssi}{$nick} = $ver;

    }
    elsif ( $ver =~ /(epic|Third Eye)/i ) {
        $ver{epic}{$nick} = $ver;

    }
    elsif ( $ver =~ /(ircII|PhoEniX)/i ) {
        $ver{ircII}{$nick} = $ver;

    }
    elsif ( $ver =~ /mirc/i ) {
        # Apparently, mIRC gets the reply as "VERSION " and doesnt like the
        # space, so mirc matching is considered bugged.
        $ver{mirc}{$nick} = $ver;

    }
    elsif ( $ver =~ /ircle/i ) {
        $ver{ircle}{$nick} = $ver;

    }
    elsif ( $ver =~ /chatzilla/i ) {
        $ver{chatzilla}{$nick} = $ver;

    }
    elsif ( $ver =~ /pirch/i ) {
        $ver{pirch}{$nick} = $ver;

    }
    elsif ( $ver =~ /sirc /i ) {
        $ver{sirc}{$nick} = $ver;

    }
    elsif ( $ver =~ /kvirc/i ) {
        $ver{kvirc}{$nick} = $ver;

    }
    elsif ( $ver =~ /eggdrop/i ) {
        $ver{eggdrop}{$nick} = $ver;

    }
    elsif ( $ver =~ /xircon/i ) {
        $ver{xircon}{$nick} = $ver;

    }
    else {
        &DEBUG("verstats: other: $nick => '$ver'.");
        $ver{other}{$nick} = $ver;
    }
}

sub on_version {
    $conn = shift(@_);
    my ($event) = @_;
    my $nick = $event->nick;

    &status(">>> ${b_green}CTCP VERSION$ob request from $b_cyan$nick$ob");
    $conn->ctcp_reply( $nick, "VERSION $bot_version" );
}

sub on_who {
    $conn = shift(@_);
    my ($event) = @_;
    my @args    = $event->args;
    my $str     = $args[5] . '!' . $args[2] . '@' . $args[3];

    if ( $cache{on_who_Hack} ) {
        $cache{nuhInfo}{ lc $args[5] }{Nick} = $args[5];
        $cache{nuhInfo}{ lc $args[5] }{User} = $args[2];
        $cache{nuhInfo}{ lc $args[5] }{Host} = $args[3];
        $cache{nuhInfo}{ lc $args[5] }{NUH}  = "$args[5]!$args[2]\@$args[3]";
        return;
    }

    if ( $args[5] =~ /^nickserv$/i and !$nickserv ) {
        &DEBUG('ok... we did a who for nickserv.');
        &rawout("PRIVMSG NickServ :IDENTIFY $param{'nickServ_pass'}");
    }

    $nuh{ lc $args[5] } = $args[5] . '!' . $args[2] . '@' . $args[3];
}

sub on_whois {
    $conn = shift(@_);
    my ($event) = @_;
    my @args = $event->args;

    $nuh{ lc $args[1] } = $args[1] . '!' . $args[2] . '@' . $args[3];
}

sub on_whoischannels {
    $conn = shift(@_);
    my ($event) = @_;
    my @args = $event->args;

    &DEBUG("on_whoischannels: @args");
}

sub on_useronchannel {
    $conn = shift(@_);
    my ($event) = @_;
    my @args = $event->args;

    &DEBUG("on_useronchannel: @args");
    &joinNextChan();
}

###
### since joinnextchan is hooked onto on_endofnames, these are needed.
###

sub on_chanfull {
    $conn = shift(@_);
    my ($event) = @_;
    my @args = $event->args;

    &status(">>> chanfull/$b_blue$args[1]$ob");

    &joinNextChan();
}

sub on_inviteonly {
    $conn = shift(@_);
    my ($event) = @_;
    my @args = $event->args;

    &status(">>> inviteonly/$b_cyan$args[1]$ob");

    &joinNextChan();
}

sub on_banned {
    $conn = shift(@_);
    my ($event) = @_;
    my @args    = $event->args;
    my $chan    = $args[1];

    &status(
">>> banned/$b_blue$chan$ob $b_cyan$args[0]$ob, removing autojoin for $chan"
    );
    delete $chanconf{$chan}{autojoin};
    &joinNextChan();
}

sub on_badchankey {
    $conn = shift(@_);
    my ($event) = @_;
    my @args    = $event->args;
    my $chan    = $args[1];

    &DEBUG("on_badchankey: args => @args, removing autojoin for $chan");
    delete $chanconf{$chan}{autojoin};
    &joinNextChan();
}

sub on_useronchan {
    $conn = shift(@_);
    my ($event) = @_;
    my @args = $event->args;

    &DEBUG("on_useronchan: args => @args");
    &joinNextChan();
}

# TODO not used yet
sub on_stdin {
    my $line = <STDIN>;
    chomp($line);
    &FIXME("on_stdin: line => \"$line\"");
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
