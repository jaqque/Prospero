#
#  UserDCC.pl: User Commands, DCC CHAT.
#      Author: dms
#     Version: v0.2 (20010119)
#     Created: 20000707 (from UserExtra.pl)
#

use strict;

use vars qw(%users %ignore %sched %bans %mask %cache %channels %param
  %chanconf %dcc);
use vars qw($who $chan $message $msgType $user $chnick $conn $ident
  $verifyUser $ucount_userfile $utime_userfile $lobotomized
  $utime_chanfile $ucount_chanfile);
use vars qw(@backlog);

sub userDCC {

    # hrm...
    $message =~ s/\s+$//;

    ### for all users.
    # quit.
    if ( $message =~ /^(exit|quit)$/i ) {

        # do ircII clients support remote close? if so, cool!
        &FIXME("userDCC: quit called.");
        &dcc_close($who);
        &status("userDCC: after dcc_close!");

        return;
    }

    # who.
    if ( $message =~ /^who$/ ) {
        my $count   = scalar( keys %{ $dcc{'CHAT'} } );
        my $dccCHAT = $message;

        &performStrictReply("Start of who ($count users).");
        foreach ( keys %{ $dcc{'CHAT'} } ) {
            &performStrictReply("=> $_");
        }
        &performStrictReply("End of who.");

        return;
    }

    ### for those users with enough flags.

    if ( $message =~ /^tellme(\s+(.*))?$/i ) {
        my $args = $2;
        if ( $args =~ /^\s*$/ ) {
            &help('tellme');
            return;
        }

        my $result = &doQuestion($args);
        &performStrictReply($result);

        return;
    }

    # 4op.
    if ( $message =~ /^4op(\s+($mask{chan}))?$/i ) {
        return unless ( &hasFlag('o') );

        my $chan = $2;

        if ( $chan eq '' ) {
            &help('4op');
            return;
        }

        if ( !$channels{$chan}{'o'}{$ident} ) {
            &msg( $who, "i don't have ops on $chan to do that." );
            return;
        }

        # on non-4mode(<4) servers, this may be exploited.
        if ( $channels{$chan}{'o'}{$who} ) {
            rawout( "MODE $chan -o+o-o+o" . ( " $who" x 4 ) );
        }
        else {
            rawout( "MODE $chan +o-o+o-o" . ( " $who" x 4 ) );
        }

        return;
    }

    # opme.
    if ( $message =~ /^opme(\s+($mask{chan}))?$/i ) {
        return unless ( &hasFlag('o') );
        return unless ( &hasFlag('A') );

        my $chan = $2;

        if ( $chan eq '' ) {
            &help('4op');
            return;
        }

        # can this be exploited?
        rawout("MODE $chan +o $who");

        return;
    }

    # backlog.
    if ( $message =~ /^backlog(\s+(.*))?$/i ) {
        return unless ( &hasFlag('o') );
        return unless ( &IsParam('backlog') );
        my $num = $2;
        my $max = $param{'backlog'};

        if ( !defined $num ) {
            &help('backlog');
            return;
        }
        elsif ( $num !~ /^\d+/ ) {
            &msg( $who, "error: argument is not positive integer." );
            return;
        }
        elsif ( $num > $max or $num < 0 ) {
            &msg( $who, "error: argument is out of range (max $max)." );
            return;
        }

        &msg( $who, "Start of backlog..." );
        for ( 0 .. $num - 1 ) {
            sleep 1 if ( $_ % 4 == 0 and $_ != 0 );
            $conn->privmsg( $who,
                "[" . ( $_ + 1 ) . "]: $backlog[$max-$num+$_]" );
        }
        &msg( $who, "End of backlog." );

        return;
    }

    # dump variables.
    if ( $message =~ /^dumpvars$/i ) {
        return unless ( &hasFlag('o') );
        return unless ( &IsParam('DumpVars') );

        &status("Dumping all variables...");
        &dumpallvars();

        return;
    }

    # dump variables ][.
    if ( $message =~ /^symdump$/i ) {
        return unless ( &hasFlag('o') );
        return unless ( &IsParam('DumpVars2') );

        &status("Dumping all variables...");
        &symdumpAllFile();

        return;
    }

    # kick.
    if ( $message =~ /^kick(\s+(.*?))$/ ) {
        return unless ( &hasFlag('o') );

        my $arg = $2;

        if ( $arg eq '' ) {
            &help('kick');
            return;
        }
        my @args = split( /\s+/, $arg );
        my ( $nick, $chan, $reason ) = @args;

        if ( &validChan($chan) == 0 ) {
            &msg( $who, "error: invalid channel \002$chan\002" );
            return;
        }

        if ( &IsNickInChan( $nick, $chan ) == 0 ) {
            &msg( $who, "$nick is not in $chan." );
            return;
        }

        &kick( $nick, $chan, $reason );

        return;
    }

    # mode.
    if ( $message =~ /^mode(\s+(.*))?$/ ) {
        return unless ( &hasFlag('n') );
        my ( $chan, $mode ) = split /\s+/, $2, 2;

        if ( $chan eq '' ) {
            &help('mode');
            return;
        }

        if ( &validChan($chan) == 0 ) {
            &msg( $who, "error: invalid channel \002$chan\002" );
            return;
        }

        if ( !$channels{$chan}{o}{$ident} ) {
            &msg( $who, "error: don't have ops on \002$chan\002" );
            return;
        }

        &mode( $chan, $mode );

        return;
    }

    # part.
    if ( $message =~ /^part(\s+(\S+))?$/i ) {
        return unless ( &hasFlag('o') );
        my $jchan = $2;

        if ( $jchan !~ /^$mask{chan}$/ ) {
            &msg( $who, "error, invalid chan." );
            &help('part');
            return;
        }

        if ( !&validChan($jchan) ) {
            &msg( $who, "error, I'm not on that chan." );
            return;
        }

        &msg( $jchan, "Leaving. (courtesy of $who)." );
        &part($jchan);
        return;
    }

    # lobotomy. sometimes we want the bot to be _QUIET_.
    if ( $message =~ /^(lobotomy|bequiet)$/i ) {
        return unless ( &hasFlag('o') );

        if ($lobotomized) {
            &performReply("i'm already lobotomized");
        }
        else {
            &performReply('i have been lobotomized');
            $lobotomized = 1;
        }

        return;
    }

    # unlobotomy.
    if ( $message =~ /^(unlobotomy|benoisy)$/i ) {
        return unless ( &hasFlag('o') );

        if ($lobotomized) {
            &performReply('i have been unlobotomized, woohoo');
            $lobotomized = 0;
            delete $cache{lobotomy};

            #	    undef $cache{lobotomy};	# ??
        }
        else {
            &performReply("i'm not lobotomized");
        }

        return;
    }

    # op.
    if ( $message =~ /^op(\s+(.*))?$/i ) {
        return unless ( &hasFlag('o') );
        my ($opee) = lc $2;
        my @chans;

        if ( $opee =~ / / ) {
            if ( $opee =~ /^(\S+)\s+(\S+)$/ ) {
                $opee  = $1;
                @chans = ($2);
                if ( !&validChan($2) ) {
                    &msg( $who, "error: invalid chan ($2)." );
                    return;
                }
            }
            else {
                &msg( $who, "error: invalid params." );
                return;
            }
        }
        else {
            @chans = keys %channels;
        }

        my $found = 0;
        my $op    = 0;
        foreach (@chans) {
            next unless ( &IsNickInChan( $opee, $_ ) );
            $found++;
            if ( $channels{$_}{'o'}{$opee} ) {
                &performStrictReply("op: $opee already has ops on $_");
                next;
            }
            $op++;

            &performStrictReply("opping $opee on $_");
            &op( $_, $opee );
        }

        if ( $found != $op ) {
            &performStrictReply("op: opped on all possible channels.");
        }
        else {
            &DEBUG("op: found => '$found'.");
            &DEBUG("op:    op => '$op'.");
        }

        return;
    }

    # deop.
    if ( $message =~ /^deop(\s+(.*))?$/i ) {
        return unless ( &hasFlag('o') );
        my ($opee) = lc $2;
        my @chans;

        if ( $opee =~ / / ) {
            if ( $opee =~ /^(\S+)\s+(\S+)$/ ) {
                $opee  = $1;
                @chans = ($2);
                if ( !&validChan($2) ) {
                    &msg( $who, "error: invalid chan ($2)." );
                    return;
                }
            }
            else {
                &msg( $who, "error: invalid params." );
                return;
            }
        }
        else {
            @chans = keys %channels;
        }

        my $found = 0;
        my $op    = 0;
        foreach (@chans) {
            next unless ( &IsNickInChan( $opee, $_ ) );
            $found++;
            if ( !exists $channels{$_}{'o'}{$opee} ) {
                &status("deop: $opee already has no ops on $_");
                next;
            }
            $op++;

            &status("deopping $opee on $_ at ${who}'s request");
            &deop( $_, $opee );
        }

        if ( $found != $op ) {
            &status("deop: deopped on all possible channels.");
        }
        else {
            &DEBUG("deop: found => '$found'.");
            &DEBUG("deop: op => '$op'.");
        }

        return;
    }

    # say.
    if ( $message =~ s/^say\s+(\S+)\s+(.*)// ) {
        return unless ( &hasFlag('o') );
        my ( $chan, $msg ) = ( lc $1, $2 );

        &DEBUG("chan => '$1', msg => '$msg'.");

        &msg( $chan, $msg );

        return;
    }

    # do.
    if ( $message =~ s/^do\s+(\S+)\s+(.*)// ) {
        return unless ( &hasFlag('o') );
        my ( $chan, $msg ) = ( lc $1, $2 );

        &DEBUG("chan => '$1', msg => '$msg'.");

        &action( $chan, $msg );

        return;
    }

    # die.
    if ( $message =~ /^die$/ ) {
        return unless ( &hasFlag('n') );

        &doExit();

        &status("Dying by $who\'s request");
        exit 0;
    }

    # global factoid substitution.
    if ( $message =~ m|^\* =~ s([/,#])(.+?)\1(.*?)\1;?\s*$| ) {
        my ( $delim, $op, $np ) = ( $1, $2, $3 );
        return unless ( &hasFlag('n') );
        ### TODO: support flags to do full-on global.

        # incorrect format.
        if ( $np =~ /$delim/ ) {
            &performReply(
"looks like you used the delimiter too many times. You may want to use a different delimiter, like ':' or '#'."
            );
            return;
        }

        ### TODO: fix up $op to support mysql/sqlite/pgsql
        ### TODO: => add db/sql specific function to fix this.
        my @list =
          &searchTable( 'factoids', 'factoid_key', 'factoid_value', $op );

        if ( !scalar @list ) {
            &performReply("Expression didn't match anything.");
            return;
        }

        if ( scalar @list > 100 ) {
            &performReply("regex found more than 100 matches... not doing.");
            return;
        }

        &status( "gsubst: going to alter " . scalar(@list) . " factoids." );
        &performReply( 'going to alter ' . scalar(@list) . " factoids." );

        my $error = 0;
        foreach (@list) {
            my $faqtoid = $_;

            next if ( &IsLocked($faqtoid) == 1 );
            my $result = &getFactoid($faqtoid);
            my $was    = $result;
            &DEBUG("was($faqtoid) => '$was'.");

            # global global
            # we could support global local (once off).
            if ( $result =~ s/\Q$op/$np/gi ) {
                if ( length $result > $param{'maxDataSize'} ) {
                    &performReply("that's too long (or was long)");
                    return;
                }
                &setFactInfo( $faqtoid, 'factoid_value', $result );
                &status("update: '$faqtoid' =is=> '$result'; was '$was'");
            }
            else {
                &WARN(
"subst: that's weird... thought we found the string ($op) in '$faqtoid'."
                );
                $error++;
            }
        }

        if ($error) {
            &ERROR("Some warnings/errors?");
        }

        &performReply( "Ok... did s/$op/$np/ for "
              . ( scalar(@list) - $error )
              . ' factoids' );

        return;
    }

    # jump.
    if ( $message =~ /^jump(\s+(\S+))?$/i ) {
        return unless ( &hasFlag('n') );

        if ( $2 eq '' ) {
            &help('jump');
            return;
        }

        my ( $server, $port );
        if ( $2 =~ /^(\S+)(:(\d+))?$/ ) {
            $server = $1;
            $port = $3 || 6667;
        }
        else {
            &msg( $who, "invalid format." );
            return;
        }

        &status("jumping servers... $server...");
        $conn->quit("jumping to $server");

        if ( &irc( $server, $port ) == 0 ) {
            &ircloop();
        }
    }

    # reload.
    if ( $message =~ /^reload$/i ) {
        return unless ( &hasFlag('n') );

        &status("USER reload $who");
        &performStrictReply("reloading...");
        &reloadAllModules();
        &performStrictReply("reloaded.");

        return;
    }

    # reset.
    if ( $message =~ /^reset$/i ) {
        return unless ( &hasFlag('n') );

        &msg( $who, "resetting..." );
        my @done;
        foreach ( keys %channels, keys %chanconf ) {
            my $c = $_;
            next if ( grep /^\Q$c\E$/i, @done );

            &part($_);

            push( @done, $_ );
            sleep 1;
        }
        &DEBUG('before clearircvars');
        &clearIRCVars();
        &DEBUG('before joinnextchan');
        &joinNextChan();
        &DEBUG('after joinnextchan');

        &status("USER reset $who");
        &msg( $who, 'reset complete' );

        return;
    }

    # rehash.
    if ( $message =~ /^rehash$/ ) {
        return unless ( &hasFlag('n') );

        &msg( $who, "rehashing..." );
        &restart('REHASH');
        &status("USER rehash $who");
        &msg( $who, 'rehashed' );

        return;
    }

    #####
    ##### USER//CHAN SPECIFIC CONFIGURATION COMMANDS
    #####

    if ( $message =~ /^chaninfo(\s+(.*))?$/ ) {
        my @args = split /[\s\t]+/, $2;    # hrm.

        if ( scalar @args != 1 ) {
            &help('chaninfo');
            return;
        }

        if ( !exists $chanconf{ $args[0] } ) {
            &performStrictReply("no such channel $args[0]");
            return;
        }

        &performStrictReply("showing channel conf.");
        foreach ( sort keys %{ $chanconf{ $args[0] } } ) {
            &performStrictReply("$chan: $_ => $chanconf{$args[0]}{$_}");
        }
        &performStrictReply("End of chaninfo.");

        return;
    }

    # chanadd.
    if ( $message =~ /^(chanset|chanadd)(\s+(.*?))?$/ ) {
        my $cmd     = $1;
        my $args    = $3;
        my $no_chan = 0;

        if ( !defined $args ) {
            &help($cmd);
            return;
        }

        my @chans;
        while ( $args =~ s/^($mask{chan})\s*// ) {
            push( @chans, lc($1) );
        }

        if ( !scalar @chans ) {
            push( @chans, '_default' );
            $no_chan = 1;
        }

        my ( $what, $val ) = split /[\s\t]+/, $args, 2;

        ### TODO: "cannot set values without +m".
        return unless ( &hasFlag('n') );

        # READ ONLY.
        if ( defined $what and $what !~ /^[-+]/ and !defined $val and $no_chan )
        {
            &performStrictReply("Showing $what values on all channels...");

            my %vals;
            foreach ( keys %chanconf ) {
                my $val;
                if ( defined $chanconf{$_}{$what} ) {
                    $val = $chanconf{$_}{$what};
                }
                else {
                    $val = "NOT-SET";
                }
                $vals{$val}{$_} = 1;
            }

            foreach ( keys %vals ) {
                &performStrictReply( "  $what = $_("
                      . scalar( keys %{ $vals{$_} } ) . "): "
                      . join( ' ', sort keys %{ $vals{$_} } ) );
            }

            &performStrictReply("End of list.");

            return;
        }

        ### TODO: move to UserDCC again.
        if ( $cmd eq 'chanset' and !defined $what ) {
            &DEBUG("showing channel conf.");

            foreach $chan (@chans) {
                if ( $chan eq '_default' ) {
                    &performStrictReply('Default channel settings');
                }
                else {
                    &performStrictReply("chan: $chan (see _default also)");
                }
                my @items;
                my $str = '';
                foreach ( sort keys %{ $chanconf{$chan} } ) {
                    my $newstr = join( ', ', @items );
                    ### TODO: make length use channel line limit?
                    if ( length $newstr > 370 ) {
                        &performStrictReply(" $str");
                        @items = ();
                    }
                    $str = $newstr;
                    push( @items, "$_ => $chanconf{$chan}{$_}" );
                }
                if (@items) {
                    my $str = join( ', ', @items );
                    &performStrictReply(" $str");
                }
            }
            return;
        }

        $cache{confvars}{$what} = $val;
        &rehashConfVars();

        foreach (@chans) {
            &chanSet( $cmd, $_, $what, $val );
        }

        return;
    }

    if ( $message =~ /^(chanunset|chandel)(\s+(.*))?$/ ) {
        return unless ( &hasFlag('n') );
        my $cmd     = $1;
        my $args    = $3;
        my $no_chan = 0;

        if ( !defined $args ) {
            &help($cmd);
            return;
        }

        my ($chan);
        my $delete = 0;
        if ( $args =~ s/^(\-)?($mask{chan})\s*// ) {
            $chan = $2;
            $delete = ($1) ? 1 : 0;
        }
        else {
            &VERB( "no chan arg; setting to default.", 2 );
            $chan    = '_default';
            $no_chan = 1;
        }

        if ( !exists $chanconf{$chan} ) {
            &performStrictReply("no such channel $chan");
            return;
        }

        if ( $args ne '' ) {

            if ( !&getChanConf( $args, $chan ) ) {
                &performStrictReply("$args does not exist for $chan");
                return;
            }

            my @chans = &ChanConfList($args);
            &DEBUG( "scalar chans => " . scalar(@chans) );
            if ( scalar @chans == 1 and $chans[0] eq '_default' and !$no_chan )
            {
                &performStrictReply(
"ok, $args was set only for _default; unsetting for _defaul but setting for other chans."
                );

                my $val = $chanconf{$_}{_default};
                foreach ( keys %chanconf ) {
                    $chanconf{$_}{$args} = $val;
                }
                delete $chanconf{_default}{$args};
                $cache{confvars}{$args} = 0;
                &rehashConfVars();

                return;
            }

            if ( $no_chan and !exists( $chanconf{_default}{$args} ) ) {
                &performStrictReply(
"ok, $args for _default does not exist, removing from all chans."
                );

                foreach ( keys %chanconf ) {
                    next unless ( exists $chanconf{$_}{$args} );
                    &DEBUG("delete chanconf{$_}{$args};");
                    delete $chanconf{$_}{$args};
                }
                $cache{confvars}{$args} = 0;
                &rehashConfVars();

                return;
            }

            &performStrictReply(
"Unsetting channel ($chan) option $args. (was $chanconf{$chan}{$args})"
            );
            delete $chanconf{$chan}{$args};

            return;
        }

        if ($delete) {
            &performStrictReply("Deleting channel $chan for sure!");
            $utime_chanfile = time();
            $ucount_chanfile++;

            &part($chan);
            &performStrictReply("Leaving $chan...");

            delete $chanconf{$chan};
        }
        else {
            &performStrictReply("Prefix channel with '-' to delete for sure.");
        }

        return;
    }

    if ( $message =~ /^newpass(\s+(.*))?$/ ) {
        my (@args) = split /[\s\t]+/, $2 || '';

        if ( scalar @args != 1 ) {
            &help('newpass');
            return;
        }

        my $u     = &getUser($who);
        my $crypt = &mkcrypt( $args[0] );

        &performStrictReply("Set your passwd to '$crypt'");
        $users{$u}{PASS} = $crypt;

        $utime_userfile = time();
        $ucount_userfile++;

        return;
    }

    if ( $message =~ /^chpass(\s+(.*))?$/ ) {
        my (@args) = split /[\s\t]+/, $2 || '';

        if ( !scalar @args ) {
            &help('chpass');
            return;
        }

        if ( !&IsUser( $args[0] ) ) {
            &performStrictReply("user $args[0] is not valid.");
            return;
        }

        my $u = &getUser( $args[0] );
        if ( !defined $u ) {
            &performStrictReply("Internal error, u = NULL.");
            return;
        }

        if ( scalar @args == 1 ) {

            # del pass.
            if ( !&IsFlag('n') and $who !~ /^\Q$verifyUser\E$/i ) {
                &performStrictReply("cannot remove passwd of others.");
                return;
            }

            if ( !exists $users{$u}{PASS} ) {
                &performStrictReply("$u does not have pass set anyway.");
                return;
            }

            &performStrictReply("Deleted pass from $u.");

            $utime_userfile = time();
            $ucount_userfile++;

            delete $users{$u}{PASS};

            return;
        }

        my $crypt = &mkcrypt( $args[1] );
        &performStrictReply("Set $u's passwd to '$crypt'");
        $users{$u}{PASS} = $crypt;

        $utime_userfile = time();
        $ucount_userfile++;

        return;
    }

    if ( $message =~ /^chattr(\s+(.*))?$/ ) {
        my (@args) = split /[\s\t]+/, $2 || '';

        if ( !scalar @args ) {
            &help('chattr');
            return;
        }

        my $chflag;
        my $user;
        if ( $args[0] =~ /^$mask{nick}$/i ) {

            # <nick>
            $user   = &getUser( $args[0] );
            $chflag = $args[1];
        }
        else {

            # <flags>
            $user = &getUser($who);
            &DEBUG("user $who... nope.") unless ( defined $user );
            $user   = &getUser($verifyUser);
            $chflag = $args[0];
        }

        if ( !defined $user ) {
            &performStrictReply("user does not exist.");
            return;
        }

        my $flags = $users{$user}{FLAGS};
        if ( !defined $chflag ) {
            &performStrictReply("Flags for $user: $flags");
            return;
        }

        &DEBUG("who => $who");
        &DEBUG("verifyUser => $verifyUser");
        if ( !&IsFlag('n') and $who !~ /^\Q$verifyUser\E$/i ) {
            &performStrictReply("cannto change attributes of others.");
            return 'REPLY';
        }

        my $state;
        my $change = 0;
        foreach ( split //, $chflag ) {
            if ( $_ eq "+" ) { $state = 1; next; }
            if ( $_ eq "-" ) { $state = 0; next; }

            if ( !defined $state ) {
                &performStrictReply("no initial + or - was found in attr.");
                return;
            }

            if ($state) {
                next if ( $flags =~ /\Q$_\E/ );
                $flags .= $_;
            }
            else {
                if (    &IsParam('owner')
                    and $param{owner} =~ /^\Q$user\E$/i
                    and $flags        =~ /[nmo]/ )
                {
                    &performStrictReply("not removing flag $_ for $user.");
                    next;
                }
                next unless ( $flags =~ s/\Q$_\E// );
            }

            $change++;
        }

        if ($change) {
            $utime_userfile = time();
            $ucount_userfile++;

            #$flags.*FLAGS sort
            $flags = join( '', sort split( '', $flags ) );
            &performStrictReply("Current flags: $flags");
            $users{$user}{FLAGS} = $flags;
        }
        else {
            &performStrictReply("No flags changed: $flags");
        }

        return;
    }

    if ( $message =~ /^chnick(\s+(.*))?$/ ) {
        my (@args) = split /[\s\t]+/, $2 || '';

        if ( $who eq '_default' ) {
            &WARN("$who or verifyuser tried to run chnick.");
            return 'REPLY';
        }

        if ( !scalar @args or scalar @args > 2 ) {
            &help('chnick');
            return;
        }

        if ( scalar @args == 1 ) {    # 1
            $user = &getUser($who);
            &DEBUG("nope, not $who.") unless ( defined $user );
            $user ||= &getUser($verifyUser);
            $chnick = $args[0];
        }
        else {                        # 2
            $user   = &getUser( $args[0] );
            $chnick = $args[1];
        }

        if ( !defined $user ) {
            &performStrictReply("user $who or $args[0] does not exist.");
            return;
        }

        if ( $user =~ /^\Q$chnick\E$/i ) {
            &performStrictReply("user == chnick. why should I do that?");
            return;
        }

        if ( &getUser($chnick) ) {
            &performStrictReply("user $chnick is already used!");
            return;
        }

        if ( !&IsFlag('n') and $who !~ /^\Q$verifyUser\E$/i ) {
            &performStrictReply("cannto change nick of others.");
            return 'REPLY' if ( $who eq '_default' );
            return;
        }

        foreach ( keys %{ $users{$user} } ) {
            $users{$chnick}{$_} = $users{$user}{$_};
            delete $users{$user}{$_};
        }
        undef $users{$user};    # ???

        $utime_userfile = time();
        $ucount_userfile++;

        &performStrictReply("Changed '$user' to '$chnick' successfully.");

        return;
    }

    if ( $message =~ /^(hostadd|hostdel)(\s+(.*))?$/ ) {
        my $cmd = $1;
        my (@args) = split /[\s\t]+/, $3 || '';
        my $state = ( $1 eq "hostadd" ) ? 1 : 0;

        if ( !scalar @args ) {
            &help($cmd);
            return;
        }

        if ( $who eq '_default' ) {
            &WARN("$who or verifyuser tried to run $cmd.");
            return 'REPLY';
        }

        my ( $user, $mask );
        if ( $args[0] =~ /^$mask{nick}$/i ) {    # <nick>
            return unless ( &hasFlag('n') );
            $user = &getUser( $args[0] );
            $mask = $args[1];
        }
        else {                                   # <mask>
                # FIXME: who or verifyUser. (don't remember why)
            $user = &getUser($who);
            $mask = $args[0];
        }

        if ( !defined $user ) {
            &performStrictReply("user $user does not exist.");
            return;
        }

        if ( !defined $mask ) {
            &performStrictReply( "Hostmasks for $user: "
                  . join( ' ', keys %{ $users{$user}{HOSTS} } ) );
            return;
        }

        if ( !&IsFlag('n') and $who !~ /^\Q$verifyUser\E$/i ) {
            &performStrictReply("cannto change masks of others.");
            return;
        }

        my $count = scalar keys %{ $users{$user}{HOSTS} };

        if ($state) {    # add.
            if ( $mask !~ /^$mask{nuh}$/ ) {
                &performStrictReply(
                    "error: mask ($mask) is not a real hostmask.");
                return;
            }

            if ( exists $users{$user}{HOSTS}{$mask} ) {
                &performStrictReply("mask $mask already exists.");
                return;
            }

            ### TODO: override support.
            $users{$user}{HOSTS}{$mask} = 1;

            &performStrictReply("Added $mask to list of masks.");

        }
        else {    # delete.

            if ( !exists $users{$user}{HOSTS}{$mask} ) {
                &performStrictReply("mask $mask does not exist.");
                return;
            }

            ### TODO: wildcard support. ?
            delete $users{$user}{HOSTS}{$mask};

            if ( scalar keys %{ $users{$user}{HOSTS} } != $count ) {
                &performStrictReply("Removed $mask from list of masks.");
            }
            else {
                &performStrictReply(
                    "error: could not find $mask in list of masks.");
                return;
            }
        }

        $utime_userfile = time();
        $ucount_userfile++;

        return;
    }

    if ( $message =~ /^(banadd|bandel)(\s+(.*))?$/ ) {
        my $cmd     = $1;
        my $flatarg = $3;
        my (@args) = split /[\s\t]+/, $3 || '';
        my $state = ( $1 eq "banadd" ) ? 1 : 0;

        if ( !scalar @args ) {
            &help($cmd);
            return;
        }

        my ( $mask, $chan, $time, $reason );

        if ( $flatarg =~ s/^($mask{nuh})\s*// ) {
            $mask = $1;
        }
        else {
            &DEBUG("arg does not contain nuh mask?");
        }

        if ( $flatarg =~ s/^($mask{chan})\s*// ) {
            $chan = $1;
        }
        else {
            $chan = '*';    # _default instead?
        }

        if ( $state == 0 ) {    # delete.
            my @c = &banDel($mask);

            foreach (@c) {
                &unban( $mask, $_ );
            }

            if (@c) {
                &performStrictReply("Removed $mask from chans: @c");
            }
            else {
                &performStrictReply("$mask was not found in ban list.");
            }

            return;
        }

        ###
        # add ban.
        ###

        # time.
        if ( $flatarg =~ s/^(\d+)\s*// ) {
            $time = $1;
            &DEBUG("time = $time.");
            if ( $time < 0 ) {
                &performStrictReply("error: time cannot be negatime?");
                return;
            }
        }
        else {
            $time = 0;
        }

        if ( $flatarg =~ s/^(.*)$// ) {    # need length?
            $reason = $1;
        }

        if ( !&IsFlag('n') and $who !~ /^\Q$verifyUser\E$/i ) {
            &performStrictReply("cannto change masks of others.");
            return;
        }

        if ( $mask !~ /^$mask{nuh}$/ ) {
            &performStrictReply("error: mask ($mask) is not a real hostmask.");
            return;
        }

        if ( &banAdd( $mask, $chan, $time, $reason ) == 2 ) {
            &performStrictReply("ban already exists; overwriting.");
        }
        &performStrictReply(
            "Added $mask for $chan (time => $time, reason => $reason)");

        return;
    }

    if ( $message =~ /^whois(\s+(.*))?$/ ) {
        my $arg = $2;

        if ( !defined $arg ) {
            &help('whois');
            return;
        }

        my $user = &getUser($arg);
        if ( !defined $user ) {
            &performStrictReply("whois: user '$arg' does not exist.");
            return;
        }

        ### TODO: better (eggdrop-like) output.
        &performStrictReply("user: $user");
        foreach ( keys %{ $users{$user} } ) {
            my $ref = ref $users{$user}{$_};

            if ( $ref eq 'HASH' ) {
                my $type = $_;
                ### DOES NOT WORK???
                foreach ( keys %{ $users{$user}{$type} } ) {
                    &performStrictReply("    $type => $_");
                }
                next;
            }

            &performStrictReply("    $_ => $users{$user}{$_}");
        }
        &performStrictReply("End of USER whois.");

        return;
    }

    if ( $message =~ /^bans(\s+(.*))?$/ ) {
        my $arg = $2;

        if ( defined $arg ) {
            if ( $arg ne '_default' and !&validChan($arg) ) {
                &performStrictReply("error: chan $chan is invalid.");
                return;
            }
        }

        if ( !scalar keys %bans ) {
            &performStrictReply("Ban list is empty.");
            return;
        }

        my $c;
        &performStrictReply(
            "     mask: expire, time-added, count, who-by, reason");
        foreach $c ( keys %bans ) {
            next unless ( !defined $arg or $arg =~ /^\Q$c\E$/i );
            &performStrictReply("  $c:");

            foreach ( keys %{ $bans{$c} } ) {
                my $val = $bans{$c}{$_};

                if ( ref $val eq 'ARRAY' ) {
                    my @array = @{$val};
                    &performStrictReply("    $_: @array");
                }
                else {
                    &DEBUG("unknown ban: $val");
                }
            }
        }
        &performStrictReply("END of bans.");

        return;
    }

    if ( $message =~ /^banlist(\s+(.*))?$/ ) {
        my $arg = $2;

        if ( defined $arg and $arg !~ /^$mask{chan}$/ ) {
            &performStrictReply("error: chan $chan is invalid.");
            return;
        }

        &DEBUG("bans for global or arg => $arg.");
        foreach ( keys %bans ) {    #CHANGE!!!
            &DEBUG("  $_ => $bans{$_}.");
        }

        &DEBUG("End of bans.");
        &performStrictReply("END of bans.");

        return;
    }

    if ( $message =~ /^save$/ ) {
        return unless ( &hasFlag('o') );

        &writeUserFile();
        &writeChanFile();
        &performStrictReply('saved user and chan files');

        return;
    }

    ### ALIASES.
    $message =~ s/^addignore/+ignore/;
    $message =~ s/^(del|un)ignore/-ignore/;

    # ignore.
    if ( $message =~ /^(\+|\-)ignore(\s+(.*))?$/i ) {
        return unless ( &hasFlag('o') );
        my $state = ( $1 eq "+" ) ? 1 : 0;
        my $str   = $1 . 'ignore';
        my $args  = $3;

        if ( !$args ) {
            &help($str);
            return;
        }

        my ( $mask, $chan, $time, $comment );

        # mask.
        if ( $args =~ s/^($mask{nuh})\s*// ) {
            $mask = $1;
        }
        else {
            &ERROR("no NUH mask?");
            return;
        }

        if ( !$state ) {    # delignore.
            if ( &ignoreDel($mask) ) {
                &performStrictReply("ok, deleted ignores for $mask.");
            }
            else {
                &performStrictReply("could not find $mask in ignore list.");
            }
            return;
        }

        ###
        # addignore.
        ###

        # chan.
        if ( $args =~ s/^($mask{chan}|\*)\s*// ) {
            $chan = $1;
        }
        else {
            $chan = '*';
        }

        # time.
        if ( $args =~ s/^(\d+)\s*// ) {
            $time = $1;    # time is in minutes
        }
        else {
            $time = 0;
        }

        # time.
        if ($args) {
            $comment = $args;
        }
        else {
            $comment = "added by $who";
        }

        if ( &ignoreAdd( $mask, $chan, $time, $comment ) > 1 ) {
            &performStrictReply(
                "FIXME: $mask already in ignore list; written over anyway.");
        }
        else {
            &performStrictReply("added $mask to ignore list.");
        }

        return;
    }

    if ( $message =~ /^ignore(\s+(.*))?$/ ) {
        my $arg = $2;

        if ( defined $arg ) {
            if ( $arg !~ /^$mask{chan}$/ ) {
                &performStrictReply("error: chan $chan is invalid.");
                return;
            }

            if ( !&validChan($arg) ) {
                &performStrictReply("error: chan $arg is invalid.");
                return;
            }

            &performStrictReply("Showing bans for $arg only.");
        }

        if ( !scalar keys %ignore ) {
            &performStrictReply("Ignore list is empty.");
            return;
        }

        ### TODO: proper (eggdrop-like) formatting.
        my $c;
        &performStrictReply("    mask: expire, time-added, who, comment");
        foreach $c ( keys %ignore ) {
            next unless ( !defined $arg or $arg =~ /^\Q$c\E$/i );
            &performStrictReply("  $c:");

            foreach ( keys %{ $ignore{$c} } ) {
                my $ref = ref $ignore{$c}{$_};
                if ( $ref eq 'ARRAY' ) {
                    my @array = @{ $ignore{$c}{$_} };
                    &performStrictReply("      $_: @array");
                }
                else {
                    &DEBUG("unknown ignore line?");
                }
            }
        }
        &performStrictReply("END of ignore.");

        return;
    }

    # useradd/userdel.
    if ( $message =~ /^(useradd|userdel)(\s+(.*))?$/i ) {
        my $cmd    = $1;
        my @args   = split /\s+/, $3 || '';
        my $args   = $3;
        my $state  = ( $cmd eq "useradd" ) ? 1 : 0;

        if ( !scalar @args ) {
            &help($cmd);
            return;
        }

        if ( $cmd eq 'useradd' ) {
            if ( scalar @args != 2 ) {
                &performStrictReply('useradd requires hostmask argument.');
                return;
            }
        }
        elsif ( scalar @args != 1 ) {
            &performStrictReply('too many arguments.');
            return;
        }

        if ($state) {

            # adduser.
            if ( scalar @args == 1 ) {
                $args[1] = &getHostMask( $args[0] );
                &performStrictReply(
                    "Attemping to guess $args[0]'s hostmask...");

                # crude hack... crappy Net::IRC
                $conn->schedule(
                    5,
                    sub {

                        # hopefully this is right.
                        my $nick = ( keys %{ $cache{nuhInfo} } )[0];
                        if ( !defined $nick ) {
                            &performStrictReply(
"couldn't get nuhinfo... adding user without a hostmask."
                            );
                            &userAdd($nick);
                            return;
                        }
                        my $mask = &makeHostMask( $cache{nuhInfo}{$nick}{NUH} );

                        if ( &userAdd( $nick, $mask ) ) {

                            # success.
                            &performStrictReply(
                                "Added $nick with flags $users{$nick}{FLAGS}");
                            my @hosts = keys %{ $users{$nick}{HOSTS} };
                            &performStrictReply("hosts: @hosts");
                        }
                    }
                );
                return;
            }

            &DEBUG("args => @args");
            if ( &userAdd(@args) ) {    # success.
                &performStrictReply(
                    "Added $args[0] with flags $users{$args[0]}{FLAGS}");
                my @hosts = keys %{ $users{ $args[0] }{HOSTS} };
                &performStrictReply("hosts: @hosts");

            }
            else {                      # failure.
                &performStrictReply("User $args[0] already exists");
            }

        }
        else {                          # deluser.

            if ( &userDel( $args[0] ) ) {    # success.
                &performStrictReply("Deleted $args[0] successfully.");

            }
            else {                           # failure.
                &performStrictReply("User $args[0] does not exist.");
            }

        }
        return;
    }

    if ( $message =~ /^sched$/ ) {
        my @list;
        my @run;

        my %time;
        foreach ( keys %sched ) {
            next unless ( exists $sched{$_}{TIME} );
            $time{ $sched{$_}{TIME} - time() }{$_} = 1;
            push( @list, $_ );

            next unless ( exists $sched{$_}{RUNNING} );
            push( @run, $_ );
        }

        my @time;
        foreach ( sort { $a <=> $b } keys %time ) {
            my $str = join( ', ', sort keys %{ $time{$_} } );
            &DEBUG("time => $_, str => $str");
            push( @time, "$str (" . &Time2String($_) . ")" );
        }

        &performStrictReply( &formListReply( 0, "Schedulers: ", @time ) );
        &performStrictReply(
            &formListReply( 0, "Scheds to run: ", sort @list ) );
        &performStrictReply(
            &formListReply(
                0, "Scheds running(should not happen?) ",
                sort @run
            )
        );

        return;
    }

    # quite a cool hack: reply in DCC CHAT.
    $msgType = 'chat' if ( exists $dcc{'CHAT'}{$who} );

    my $done = 0;
    $done++ if &parseCmdHook($message);
    $done++ unless ( &Modules() );

    if ($done) {
        &DEBUG("running non DCC CHAT command inside DCC CHAT!");
        return;
    }

    return 'REPLY';
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
