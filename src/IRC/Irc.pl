#
#    Irc.pl: IRC core stuff.
#    Author: dms
#   Version: 20000126
#      NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#

use strict;

no strict 'refs';
no strict 'subs';    # IN/STDIN

use vars qw(%floodjoin %nuh %dcc %cache %conns %channels %param %mask
  %chanconf %orig %ircPort %ircstats %last %netsplit);
use vars qw($irc $nickserv $conn $msgType $who $talkchannel
  $addressed $postprocess);
use vars qw($notcount $nottime $notsize $msgcount $msgtime $msgsize
  $pubcount $pubtime $pubsize);
use vars qw($b_blue $ob);
use vars qw(@ircServers);

#use open ':utf8';
#use open ':std';

$nickserv = 0;

# It's probably closer to 510, but let's be cautious until we calculate it extensively.
my $maxlinelen = 490;

# Keep track of last time we displayed Chans: to avoid spam in logs
my $lastChansTime = 0;

sub ircloop {
    my $error   = 0;
    my $lastrun = 0;

  loop:;
    while ( my $host = shift @ircServers ) {

        # JUST IN CASE. irq was complaining about this.
        if ( $lastrun == time() ) {
            &DEBUG('ircloop: hrm... lastrun == time()');
            $error++;
            sleep 10;
            next;
        }

        if ( !defined $host ) {
            &DEBUG('ircloop: ircServers[x] = NULL.');
            $lastrun = time();
            next;
        }
        next unless ( exists $ircPort{$host} );

        my $retval = &irc( $host, $ircPort{$host} );
        next unless ( defined $retval and $retval == 0 );
        $error++;

        if ( $error % 3 == 0 and $error != 0 ) {
            &status('IRC: Could not connect.');
            &status('IRC: ');
            next;
        }

        if ( $error >= 3 * 2 ) {
            &status('IRC: cannot connect to any IRC servers; stopping.');
            &shutdown();
            exit 1;
        }
    }

    &status('IRC: ok, done one cycle of IRC servers; trying again.');

    &loadIRCServers();
    goto loop;
}

sub irc {
    my ( $server, $port ) = @_;

    $irc = new Net::IRC;

    # TODO: move all this to an sql table
    my $iaddr = inet_aton($server);
    my $paddr = sockaddr_in( $port, $iaddr );
    my $proto = getprotobyname('tcp');

    # why was this here?
    #select STDOUT;

    # host->ip.
    my $resolve;
    if ( $server =~ /\D$/ ) {
        my $packed = scalar( gethostbyname($server) );

        if ( !defined $packed ) {
            &status("  cannot resolve $server.");
            return 0;
        }

        $resolve = inet_ntoa($packed);
        ### warning in Sys/Hostname line 78???
        ### caused inside Net::IRC?
    }

    my %args = (
        Nick    => $param{'ircNick'},
        Server  => $server,
        Port    => $port,
        Ircname => $param{'ircName'},
    );
    $args{'LocalAddr'} = $param{'ircHost'}   if ( $param{'ircHost'} );
    $args{'Password'}  = $param{'ircPasswd'} if ( $param{'ircPasswd'} );

    foreach my $mynick ( split ',', $param{'ircNick'} ) {
        &status(
"Connecting to port $port of server $server ($resolve) as $mynick ..."
        );
        $args{'Nick'} = $mynick;
        $conns{$mynick} = $irc->newconn(%args);
        if ( !defined $conns{$mynick} ) {
            &ERROR('IRC: connection failed.');
            &ERROR(
"add \"set ircHost 0.0.0.0\" to your config. If that does not work"
            );
            &ERROR(
'Please check /etc/hosts to see if you have a localhost line like:'
            );
            &ERROR('127.0.0.1   localhost    localhost');
            &ERROR(
                'If this is still a problem, please contact the maintainer.');
        }
        $conns{$mynick}->maxlinelen($maxlinelen);

        # handler stuff.
        $conns{$mynick}->add_global_handler( 'caction',   \&on_action );
        $conns{$mynick}->add_global_handler( 'cdcc',      \&on_dcc );
        $conns{$mynick}->add_global_handler( 'cping',     \&on_ping );
        $conns{$mynick}->add_global_handler( 'crping',    \&on_ping_reply );
        $conns{$mynick}->add_global_handler( 'cversion',  \&on_version );
        $conns{$mynick}->add_global_handler( 'crversion', \&on_crversion );
        $conns{$mynick}->add_global_handler( 'dcc_open',  \&on_dcc_open );
        $conns{$mynick}->add_global_handler( 'dcc_close', \&on_dcc_close );
        $conns{$mynick}->add_global_handler( 'chat',      \&on_chat );
        $conns{$mynick}->add_global_handler( 'msg',       \&on_msg );
        $conns{$mynick}->add_global_handler( 'public',    \&on_public );
        $conns{$mynick}->add_global_handler( 'join',      \&on_join );
        $conns{$mynick}->add_global_handler( 'part',      \&on_part );
        $conns{$mynick}->add_global_handler( 'topic',     \&on_topic );
        $conns{$mynick}->add_global_handler( 'invite',    \&on_invite );
        $conns{$mynick}->add_global_handler( 'kick',      \&on_kick );
        $conns{$mynick}->add_global_handler( 'mode',      \&on_mode );
        $conns{$mynick}->add_global_handler( 'nick',      \&on_nick );
        $conns{$mynick}->add_global_handler( 'quit',      \&on_quit );
        $conns{$mynick}->add_global_handler( 'notice',    \&on_notice );
        $conns{$mynick}
          ->add_global_handler( 'whoischannels', \&on_whoischannels );
        $conns{$mynick}
          ->add_global_handler( 'useronchannel', \&on_useronchannel );
        $conns{$mynick}->add_global_handler( 'whois',      \&on_whois );
        $conns{$mynick}->add_global_handler( 'other',      \&on_other );
        $conns{$mynick}->add_global_handler( 'disconnect', \&on_disconnect );
        $conns{$mynick}
          ->add_global_handler( [ 251, 252, 253, 254, 255 ], \&on_init );

        #	$conns{$mynick}->add_global_handler(302, \&on_init); # userhost
        $conns{$mynick}->add_global_handler( 303, \&on_ison );         # notify.
        $conns{$mynick}->add_global_handler( 315, \&on_endofwho );
        $conns{$mynick}->add_global_handler( 422, \&on_endofwho );     # nomotd.
        $conns{$mynick}->add_global_handler( 324, \&on_modeis );
        $conns{$mynick}->add_global_handler( 333, \&on_topicinfo );
        $conns{$mynick}->add_global_handler( 352, \&on_who );
        $conns{$mynick}->add_global_handler( 353, \&on_names );
        $conns{$mynick}->add_global_handler( 366, \&on_endofnames );
        $conns{$mynick}->add_global_handler( "001", \&on_connected )
          ;    # on_connect.
        $conns{$mynick}->add_global_handler( 433, \&on_nick_taken );
        $conns{$mynick}->add_global_handler( 439, \&on_targettoofast );

        # for proper joinnextChan behaviour
        $conns{$mynick}->add_global_handler( 471, \&on_chanfull );
        $conns{$mynick}->add_global_handler( 473, \&on_inviteonly );
        $conns{$mynick}->add_global_handler( 474, \&on_banned );
        $conns{$mynick}->add_global_handler( 475, \&on_badchankey );
        $conns{$mynick}->add_global_handler( 443, \&on_useronchan );

        # end of handler stuff.
    }

    &clearIRCVars();

    # change internal timeout value for scheduler.
    $irc->{_timeout} = 10;    # how about 60?
                              # Net::IRC debugging.
    $irc->{_debug}   = 1;

    $ircstats{'Server'} = "$server:$port";

    # works? needs to actually do something
    # should likely listen on a tcp port instead
    #$irc->addfh(STDIN, \&on_stdin, 'r');

    &status('starting main loop');

    $irc->start;
}

######################################################################
######## IRC ALIASES   IRC ALIASES   IRC ALIASES   IRC ALIASES #######
######################################################################

sub rawout {
    my ($buf) = @_;
    $buf =~ s/\n//gi;

    # slow down a bit if traffic is 'high'.
    # need to take into account time of last message sent.
    if ( $last{buflen} > 256 and length($buf) > 256 ) {
        sleep 1;
    }

    $conn->sl($buf) if ( &whatInterface() =~ /IRC/ );

    $last{buflen} = length($buf);
}

sub say {
    my ($msg) = @_;
    my $mynick = $conn->nick();
    if ( !defined $msg ) {
        $msg ||= 'NULL';
        &WARN("say: msg == $msg.");
        return;
    }

    if ( &getChanConf( 'silent', $talkchannel )
        and not( &IsFlag('s') and &verifyUser( $who, $nuh{ lc $who } ) ) )
    {
        &DEBUG("say: silent in $talkchannel, not saying $msg");
        return;
    }

    if ($postprocess) {
        undef $postprocess;
    }
    elsif ( $postprocess = &getChanConf( 'postprocess', $talkchannel ) ) {
        &DEBUG("say: $postprocess $msg");
        &parseCmdHook( $postprocess . ' ' . $msg );
        undef $postprocess;
        return;
    }

    &status("<$mynick/$talkchannel> $msg");

    return unless ( &whatInterface() =~ /IRC/ );

    $msg = 'zero' if ( $msg =~ /^0+$/ );

    my $t = time();

    if ( $t == $pubtime ) {
        $pubcount++;
        $pubsize += length $msg;

        my $i = &getChanConfDefault( 'sendPublicLimitLines', 3,    $chan );
        my $j = &getChanConfDefault( 'sendPublicLimitBytes', 1000, $chan );

        if ( ( $pubcount % $i ) == 0 and $pubcount ) {
            sleep 1;
        }
        elsif ( $pubsize > $j ) {
            sleep 1;
            $pubsize -= $j;
        }

    }
    else {
        $pubcount = 0;
        $pubtime  = $t;
        $pubsize  = length $msg;
    }

    $conn->privmsg( $talkchannel, $msg );
}

sub msg {
    my ( $nick, $msg ) = @_;
    if ( !defined $nick ) {
        &ERROR('msg: nick == NULL.');
        return;
    }

    if ( !defined $msg ) {
        $msg ||= 'NULL';
        &WARN("msg: msg == $msg.");
        return;
    }

    # some say() end up here (eg +help)
    if ( &getChanConf( 'silent', $nick )
        and not( &IsFlag('s') and &verifyUser( $who, $nuh{ lc $who } ) ) )
    {
        &DEBUG("msg: silent in $nick, not saying $msg");
        return;
    }

    &status(">$nick< $msg");

    return unless ( &whatInterface() =~ /IRC/ );
    my $t = time();

    if ( $t == $msgtime ) {
        $msgcount++;
        $msgsize += length $msg;

        my $i = &getChanConfDefault( 'sendPrivateLimitLines', 3,    $chan );
        my $j = &getChanConfDefault( 'sendPrivateLimitBytes', 1000, $chan );
        if ( ( $msgcount % $i ) == 0 and $msgcount ) {
            sleep 1;
        }
        elsif ( $msgsize > $j ) {
            sleep 1;
            $msgsize -= $j;
        }

    }
    else {
        $msgcount = 0;
        $msgtime  = $t;
        $msgsize  = length $msg;
    }

    $conn->privmsg( $nick, $msg );
}

# Usage: &action(nick || chan, txt);
sub action {
    my $mynick = $conn->nick();
    my ( $target, $txt ) = @_;
    if ( !defined $txt ) {
        &WARN('action: txt == NULL.');
        return;
    }

    if ( &getChanConf( 'silent', $target )
        and not( &IsFlag('s') and &verifyUser( $who, $nuh{ lc $who } ) ) )
    {
        &DEBUG("action: silent in $target, not doing $txt");
        return;
    }

    if ( length $txt > 480 ) {
        &status('action: txt too long; truncating.');
        chop($txt) while ( length $txt > 480 );
    }

    &status("* $mynick/$target $txt");
    $conn->me( $target, $txt );
}

# Usage: &notice(nick || chan, txt);
sub notice {
    my ( $target, $txt ) = @_;
    if ( !defined $txt ) {
        &WARN('notice: txt == NULL.');
        return;
    }

    &status("-$target- $txt");

    my $t = time();

    if ( $t == $nottime ) {
        $notcount++;
        $notsize += length $txt;

        my $i = &getChanConfDefault( 'sendNoticeLimitLines', 3,    $chan );
        my $j = &getChanConfDefault( 'sendNoticeLimitBytes', 1000, $chan );

        if ( ( $notcount % $i ) == 0 and $notcount ) {
            sleep 1;
        }
        elsif ( $notsize > $j ) {
            sleep 1;
            $notsize -= $j;
        }

    }
    else {
        $notcount = 0;
        $nottime  = $t;
        $notsize  = length $txt;
    }

    $conn->notice( $target, $txt );
}

sub DCCBroadcast {
    my ( $txt, $flag ) = @_;

    ### FIXME: flag not supported yet.

    foreach ( keys %{ $dcc{'CHAT'} } ) {
        $conn->privmsg( $dcc{'CHAT'}{$_}, $txt );
    }
}

##########
### perform commands.
###

# Usage: &performReply($reply);
sub performReply {
    my ($reply) = @_;

    if ( !defined $reply or $reply =~ /^\s*$/ ) {
        &DEBUG('performReply: reply == NULL.');
        return;
    }

    $reply =~ /([\.\?\s]+)$/;

    # FIXME need real throttling....
    if ( length($reply) > $maxlinelen - 30 ) {
        $reply = substr( $reply, 0, $maxlinelen - 33 );
        $reply =~ s/ [^ ]*?$/ .../;
    }
    &checkMsgType($reply);

    if ( $msgType eq 'public' ) {
        if ( rand() < 0.5 or $reply =~ /[\.\?]$/ ) {
            $reply = "$orig{who}: " . $reply;
        }
        else {
            $reply = "$reply, " . $orig{who};
        }
        &say($reply);

    }
    elsif ( $msgType eq 'private' ) {
        if ( rand() > 0.5 ) {
            $reply = "$reply, " . $orig{who};
        }
        &msg( $who, $reply );

    }
    elsif ( $msgType eq 'chat' ) {
        if ( !exists $dcc{'CHAT'}{$who} ) {
            &VERB( "pSR: dcc{'CHAT'}{$who} does not exist.", 2 );
            return;
        }
        $conn->privmsg( $dcc{'CHAT'}{$who}, $reply );

    }
    else {
        &ERROR("PR: msgType invalid? ($msgType).");
    }
}

# ...
sub performAddressedReply {
    return unless ($addressed);
    &performReply(@_);
}

# Usage: &performStrictReply($reply);
sub performStrictReply {
    my ($reply) = @_;

    # FIXME need real throttling....
    if ( length($reply) > $maxlinelen - 30 ) {
        $reply = substr( $reply, 0, $maxlinelen - 33 );
        $reply =~ s/ [^ ]*?$/ .../;
    }
    &checkMsgType($reply);

    if ( $msgType eq 'private' ) {
        &msg( $who, $reply );
    }
    elsif ( $msgType eq 'public' ) {
        &say($reply);
    }
    elsif ( $msgType eq 'chat' ) {
        &dccsay( lc $who, $reply );
    }
    else {
        &ERROR("pSR: msgType invalid? ($msgType).");
    }
}

sub dccsay {
    my ( $who, $reply ) = @_;

    if ( !defined $reply or $reply =~ /^\s*$/ ) {
        &WARN('dccsay: reply == NULL.');
        return;
    }

    if ( !exists $dcc{'CHAT'}{$who} ) {
        &VERB( "pSR: dcc{'CHAT'}{$who} does not exist. (2)", 2 );
        return;
    }

    &status("=>$who<= $reply");    # dcc chat.
    $conn->privmsg( $dcc{'CHAT'}{$who}, $reply );
}

sub dcc_close {
    my ($who) = @_;
    my $type;

    foreach $type ( keys %dcc ) {
        &FIXME("dcc_close: $who");
        my @who = grep /^\Q$who\E$/i, keys %{ $dcc{$type} };
        next unless ( scalar @who );
        $who = $who[0];
        &DEBUG("dcc_close... close $who!");
    }
}

sub joinchan {
    my ( $chan, $key ) = @_;
    $key ||= &getChanConf( 'chankey', $chan );
    $key ||= '';

    # forgot for about 2 years to implement channel keys when moving
    # over to Net::IRC...

    # hopefully validChan is right.
    if ( &validChan($chan) ) {
        &status("join: already on $chan?");
    }

    #} else {
    &status("joining $b_blue$chan $key$ob");

    return if ( $conn->join( $chan, $key ) );
    return if ( &validChan($chan) );

    &DEBUG('joinchan: join failed. trying connect!');
    &clearIRCVars();
    $conn->connect();

    #}
}

sub part {
    my $chan;

    foreach $chan (@_) {
        next if ( $chan eq '' );
        $chan =~ tr/A-Z/a-z/;    # lowercase.

        if ( $chan !~ /^$mask{chan}$/ ) {
            &WARN("part: chan is invalid ($chan)");
            next;
        }

        &status("parting $chan");
        if ( !&validChan($chan) ) {
            &WARN("part: not on $chan; doing anyway");

            #	    next;
        }

        $conn->part($chan);

        # deletion of $channels{chan} is done in &entryEvt().
    }
}

sub mode {
    my ( $chan, @modes ) = @_;
    my $modes = join( ' ', @modes );

    if ( &validChan($chan) == 0 ) {
        &ERROR("mode: invalid chan => '$chan'.");
        return;
    }

    &DEBUG("mode: MODE $chan $modes");

    # should move to use Net::IRC's $conn->mode()... but too lazy.
    rawout("MODE $chan $modes");
}

sub op {
    my ( $chan, @who ) = @_;
    my $os = 'o' x scalar(@who);

    &mode( $chan, "+$os @who" );
}

sub deop {
    my ( $chan, @who ) = @_;
    my $os = 'o' x scalar(@who);

    &mode( $chan, "-$os " . @who );
}

sub kick {
    my ( $nick, $chan, $msg ) = @_;
    my (@chans) = ( $chan eq '' ) ? ( keys %channels ) : lc($chan);
    my $mynick = $conn->nick();

    if ( $chan ne '' and &validChan($chan) == 0 ) {
        &ERROR("kick: invalid channel $chan.");
        return;
    }

    $nick =~ tr/A-Z/a-z/;

    foreach $chan (@chans) {
        if ( !&IsNickInChan( $nick, $chan ) ) {
            &status("kick: $nick is not on $chan.") if ( scalar @chans == 1 );
            next;
        }

        if ( !exists $channels{$chan}{o}{$mynick} ) {
            &status("kick: do not have ops on $chan :(");
            next;
        }

        &status("Kicking $nick from $chan.");
        $conn->kick( $chan, $nick, $msg );
    }
}

sub ban {
    my ( $mask, $chan ) = @_;
    my (@chans) = ( $chan =~ /^\*?$/ ) ? ( keys %channels ) : lc($chan);
    my $mynick = $conn->nick();
    my $ban    = 0;

    if ( $chan !~ /^\*?$/ and &validChan($chan) == 0 ) {
        &ERROR("ban: invalid channel $chan.");
        return;
    }

    foreach $chan (@chans) {
        if ( !exists $channels{$chan}{o}{$mynick} ) {
            &status("ban: do not have ops on $chan :(");
            next;
        }

        &status("Banning $mask from $chan.");
        &rawout("MODE $chan +b $mask");
        $ban++;
    }

    return $ban;
}

sub unban {
    my ( $mask, $chan ) = @_;
    my (@chans) = ( $chan =~ /^\*?$/ ) ? ( keys %channels ) : lc($chan);
    my $mynick = $conn->nick();
    my $ban    = 0;

    &DEBUG("unban: mask = $mask, chan = @chans");

    foreach $chan (@chans) {
        if ( !exists $channels{$chan}{o}{$mynick} ) {
            &status("unBan: do not have ops on $chan :(");
            next;
        }

        &status("Removed ban $mask from $chan.");
        &rawout("MODE $chan -b $mask");
        $ban++;
    }

    return $ban;
}

sub quit {
    my ($quitmsg) = @_;
    if ( defined $conn ) {
        &status( 'QUIT ' . $conn->nick() . " has quit IRC ($quitmsg)" );
        $conn->quit($quitmsg);
    }
    else {
        &WARN('quit: could not quit!');
    }
}

sub nick {
    my ($newnick) = @_;
    my $mynick = $conn->nick();

    if ( !defined $newnick ) {
        &ERROR('nick: nick == NULL.');
        return;
    }

    if ( !defined $mynick ) {
        &WARN('nick: mynick == NULL.');
        return;
    }

    my $bad = 0;
    $bad++ if ( exists $nuh{$newnick} );
    $bad++ if ( &IsNickInAnyChan($newnick) );

    if ($bad) {
        &WARN(  "Nick: not going to try to change from $mynick to $newnick. ["
              . scalar(gmtime)
              . ']' );

        # hrm... over time we lose track of our own nick.
        #return;
    }

    if ( $newnick =~ /^$mask{nick}$/ ) {
        &status("nick: Changing nick from $mynick to $newnick");

        # ->nick() will NOT change cause we are using rawout?
        &rawout("NICK $newnick");
        return 1;
    }
    &DEBUG("nick: failed... why oh why (mynick=$mynick, newnick=$newnick)");
    return 0;
}

sub invite {
    my ( $who, $chan ) = @_;

    # TODO: check if $who or $chan are invalid.

    $conn->invite( $who, $chan );
}

##########
# Channel related functions...
#

# Usage: &joinNextChan();
sub joinNextChan {
    my $joined = 0;
    foreach ( sort keys %conns ) {
        $conn = $conns{$_};
        my $mynick = $conn->nick();
        my @join   = getJoinChans(1);

        if ( scalar @join ) {
            my $chan = shift @join;
            &joinchan($chan);

            if ( my $i = scalar @join ) {
                &status("joinNextChan: $mynick $i chans to join.");
            }
            $joined = 1;
        }
    }
    return if $joined;

    if ( exists $cache{joinTime} ) {
        my $delta   = time() - $cache{joinTime} - 5;
        my $timestr = &Time2String($delta);

        # FIXME: @join should be @in instead (hacked to 10)
        #my $rate	= sprintf('%.1f', $delta / @in);
        my $rate = sprintf( '%.1f', $delta / 10 );
        delete $cache{joinTime};

        &status("time taken to join all chans: $timestr; rate: $rate sec/join");
    }

    # chanserv check: global channels, in case we missed one.
    foreach ( &ChanConfList('chanServ_ops') ) {
        &chanServCheck($_);
    }
}

# Usage: &getNickInChans($nick);
sub getNickInChans {
    my ($nick) = @_;
    my @array;

    foreach ( keys %channels ) {
        next unless ( grep /^\Q$nick\E$/i, keys %{ $channels{$_}{''} } );
        push( @array, $_ );
    }

    return @array;
}

# Usage: &getNicksInChan($chan);
sub getNicksInChan {
    my ($chan) = @_;
    my @array;

    return keys %{ $channels{$chan}{''} };
}

sub IsNickInChan {
    my ( $nick, $chan ) = @_;

    $chan =~ tr/A-Z/a-z/;    # not lowercase unfortunately.

    if ( $chan =~ /^$/ ) {
        &DEBUG('INIC: chan == NULL.');
        return 0;
    }

    if ( &validChan($chan) == 0 ) {
        &ERROR("INIC: invalid channel $chan.");
        return 0;
    }

    if ( grep /^\Q$nick\E$/i, keys %{ $channels{$chan}{''} } ) {
        return 1;
    }
    else {
        foreach ( keys %channels ) {
            next unless (/[A-Z]/);
            &DEBUG('iNIC: hash channels contains mixed cased chan!!!');
        }
        return 0;
    }
}

sub IsNickInAnyChan {
    my ($nick) = @_;
    my $chan;

    foreach $chan ( keys %channels ) {
        next unless ( grep /^\Q$nick\E$/i, keys %{ $channels{$chan}{''} } );
        return 1;
    }
    return 0;
}

# Usage: &validChan($chan);
sub validChan {

    # TODO: use $c instead?
    my ($chan) = @_;

    if ( !defined $chan or $chan =~ /^\s*$/ ) {
        return 0;
    }

    if ( lc $chan ne $chan ) {
        &WARN("validChan: lc chan != chan. ($chan); fixing.");
        $chan =~ tr/A-Z/a-z/;
    }

    # it's possible that this check creates the hash if empty.
    if ( defined $channels{$chan} or exists $channels{$chan} ) {
        if ( $chan =~ /^_?default$/ ) {

            #	    &WARN('validC: chan cannot be _default! returning 0!');
            return 0;
        }

        return 1;
    }
    else {
        return 0;
    }
}

###
# Usage: &delUserInfo($nick,@chans);
sub delUserInfo {
    my ( $nick, @chans ) = @_;
    my ( $mode, $chan );

    foreach $chan (@chans) {
        foreach $mode ( keys %{ $channels{$chan} } ) {

            # use grep here?
            next unless ( exists $channels{$chan}{$mode}{$nick} );

            delete $channels{$chan}{$mode}{$nick};
        }
    }
}

sub clearChanVars {
    my ($chan) = @_;

    delete $channels{$chan};
}

sub clearIRCVars {
    undef %channels;
    undef %floodjoin;

    $cache{joinTime} = time();
}

sub getJoinChans {

    # $show should contain the min number of seconds between display
    # of the Chans: status line. Use 0 to disable
    my $show = shift;

    my @in;
    my @skip;
    my @join;

    # Display 'Chans:' only if more than $show seconds since last display
    if ( time() - $lastChansTime > $show ) {
        $lastChansTime = time();
    }
    else {
        $show = 0;    # Don't display since < 15min since last
    }

    # can't join any if not connected
    return @join if ( !$conn );

    my $nick = $conn->nick();

    foreach ( keys %chanconf ) {
        next if ( $_ eq '_default' );

        my $skip = 0;
        my $val  = $chanconf{$_}{autojoin};

        if ( defined $val ) {
            $skip++ if ( $val eq '0' );
            if ( $val eq '1' ) {

                # convert old +autojoin to autojoin <nick>
                $val = lc $nick;
                $chanconf{$_}{autojoin} = $val;
            }
            $skip++ if ( lc $val ne lc $nick );
        }
        else {
            $skip++;
        }

        if ($skip) {
            push( @skip, $_ );
        }
        else {
            if ( defined $channels{$_} or exists $channels{$_} ) {
                push( @in, $_ );
            }
            else {
                push( @join, $_ );
            }
        }
    }

    my $str;
    $str .= ' in:' . join( ',',   sort @in )   if scalar @in;
    $str .= ' skip:' . join( ',', sort @skip ) if scalar @skip;
    $str .= ' join:' . join( ',', sort @join ) if scalar @join;

    &status("Chans: ($nick)$str") if ($show);

    return sort @join;
}

sub closeDCC {

    #    &DEBUG('closeDCC called.');
    my $type;

    foreach $type ( keys %dcc ) {
        next if ( $type ne uc($type) );

        my $nick;
        foreach $nick ( keys %{ $dcc{$type} } ) {
            next unless ( defined $nick );
            &status("DCC CHAT: closing DCC $type to $nick.");
            next unless ( defined $dcc{$type}{$nick} );

            my $ref = $dcc{$type}{$nick};
            &dccsay( $nick, "bye bye, $nick" ) if ( $type =~ /^chat$/i );
            $dcc{$type}{$nick}->close();
            delete $dcc{$type}{$nick};
            &DEBUG("after close for $nick");
        }
        delete $dcc{$type};
    }
}

sub joinfloodCheck {
    my ( $who, $chan, $userhost ) = @_;

    return unless ( &IsChanConf('joinfloodCheck') > 0 );

    if ( exists $netsplit{ lc $who } ) {    # netsplit join.
        &DEBUG("joinfloodCheck: $who was in netsplit; not checking.");
    }

    if ( exists $floodjoin{$chan}{$who}{Time} ) {
        &WARN("floodjoin{$chan}{$who} already exists?");
    }

    $floodjoin{$chan}{$who}{Time} = time();
    $floodjoin{$chan}{$who}{Host} = $userhost;

    ### Check...
    foreach ( keys %floodjoin ) {
        my $c     = $_;
        my $count = scalar keys %{ $floodjoin{$c} };
        next unless ( $count > 5 );
        &DEBUG("joinflood: count => $count");

        my $time;
        foreach ( keys %{ $floodjoin{$c} } ) {
            my $t = $floodjoin{$c}{$_}{Time};
            next unless ( defined $t );

            $time += $t;
        }
        &DEBUG("joinflood: time => $time");
        $time /= $count;

        &DEBUG("joinflood: new time => $time");
    }

    ### Clean it up.
    my $delete = 0;
    my $time   = time();
    foreach $chan ( keys %floodjoin ) {
        foreach $who ( keys %{ $floodjoin{$chan} } ) {
            my $t = $floodjoin{$chan}{$who}{Time};
            next unless ( defined $t );

            my $delta = $time - $t;
            next unless ( $delta > 10 );

            delete $floodjoin{$chan}{$who};
            $delete++;
        }
    }

    &DEBUG("joinfloodCheck: $delete deleted.") if ($delete);
}

sub getHostMask {
    my ($n) = @_;

    if ( exists $nuh{$n} ) {
        return &makeHostMask( $nuh{$n} );
    }
    else {
        $cache{on_who_Hack} = 1;
        $conn->who($n);
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
