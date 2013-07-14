#
# User Command Extension Stubs
# WARN: this file does not reload on HUP.
#

#use strict; # TODO: sub { \&{ $hash{'CODEREF'} }($flatarg) };

use vars qw($who $msgType $conn $chan $message $ident $talkchannel
	$bot_version $bot_data_dir);
use vars qw(@vernick @vernicktodo);
use vars qw(%channels %cache %mask %userstats %myModules %cmdstats
	%cmdhooks %lang %ver);
# TODO: FIX THE FOLLOWING:
use vars qw($total $x $type $i $good %wingateToDo);

### COMMAND HOOK IMPLEMENTATION.
# addCmdHook('TEXT_HOOK',
#	(CODEREF	=> 'Blah',
#	Forker		=> 1,
#	Module		=> 'blah.pl'		# preload module.
#	Identifier	=> 'config_label',	# change to Config?
#	Help		=> 'help_label',
#	Cmdstats	=> 'text_label',)
#}
###

sub addCmdHook {
    my ( $ident, %hash ) = @_;

    if ( exists $cmdhooks{$ident} ) {
        &WARN("aCH: \$cmdhooks{$ident} already exists.");
        return;
    }

    &VERB( "aCH: added $ident", 2 );    # use $hash{'Identifier'}?
    ### hrm... prevent warnings?
    $cmdhooks{$ident} = \%hash;
}

# RUN IF ADDRESSED.
sub parseCmdHook {
    my ($line) = @_;
    $line =~ s/^\s+|\s+$//g;        # again.
    $line =~ /^(\S+)(\s+(.*))?$/;
    my $cmd     = $1;               # command name is whitespaceless.
    my $flatarg = $3;
    my @args = split( /\s+/, $flatarg || '' );
    my $done = 0;

    &shmFlush();

    if ( !defined %cmdhooks ) {
        &WARN('%cmdhooks does not exist.');
        return 0;
    }

    if ( !defined $cmd ) {
        &WARN('cstubs: cmd == NULL.');
        return 0;
    }

    foreach ( keys %cmdhooks ) {

        # rename to something else! like $id or $label?
        my $ident = $_;

        next unless ( $cmd =~ /^$ident$/i );

        if ($done) {
            &WARN("pCH: Multiple hook match: $ident");
            next;
        }

        &status("cmdhooks: $cmd matched '$ident' '$flatarg'");
        my %hash = %{ $cmdhooks{$ident} };

        if ( !scalar keys %hash ) {
            &WARN('CmdHook: hash is NULL?');
            return 1;
        }

        if ( $hash{NoArgs} and $flatarg ) {
            &DEBUG("cmd $ident does not take args ('$flatarg'); skipping.");
            next;
        }

        if ( !exists $hash{CODEREF} ) {
            &ERROR("CODEREF undefined for $cmd or $ident.");
            return 1;
        }

        ### DEBUG.
        foreach ( keys %hash ) {
            &VERB( " $cmd->$_ => '$hash{$_}'.", 2 );
        }

        ### HELP.
        if ( exists $hash{'Help'} and !scalar(@args) ) {
            &help( $hash{'Help'} );
            return 1;
        }

        ### IDENTIFIER.
        if ( exists $hash{'Identifier'} ) {
            return 1 unless ( &IsChanConfOrWarn( $hash{'Identifier'} ) );
        }

        ### USER FLAGS.
        if ( exists $hash{'UserFlag'} ) {
            return 1 unless ( &hasFlag( $hash{'UserFlag'} ) );
        }

        ### FORKER,IDENTIFIER,CODEREF.
        if ( ( $$ == $bot_pid ) && exists $hash{'Forker'} ) {
            if ( exists $hash{'ArrayArgs'} ) {
                &Forker( $hash{'Identifier'},
                    sub { \&{ $hash{'CODEREF'} }(@args) } );
            }
            else {
                &Forker( $hash{'Identifier'},
                    sub { \&{ $hash{'CODEREF'} }($flatarg) } );
            }

        }
        else {
            if ( exists $hash{'Module'} ) {
                &loadMyModule( $hash{'Module'} );
            }

            # check if CODEREF exists.
            if ( !defined &{ $hash{'CODEREF'} } ) {
                &WARN("coderef $hash{'CODEREF'} does not exist.");
                if ( defined $who ) {
                    &msg( $who, "coderef does not exist for $ident." );
                }

                return 1;
            }

            if ( exists $hash{'ArrayArgs'} ) {
                &{ $hash{'CODEREF'} }(@args);
            }
            else {
                &{ $hash{'CODEREF'} }($flatarg);
            }
        }

        ### CMDSTATS.
        if ( exists $hash{'Cmdstats'} ) {
            $cmdstats{ $hash{'Cmdstats'} }++;
        }

        &VERB( 'hooks: End of command.', 2 );

        $done = 1;
    }

    return 1 if ($done);
    return 0;
}

sub Modules {
    if ( !defined $message ) {
        &WARN('Modules: message is undefined. should never happen.');
        return;
    }

    my $debiancmd = 'conflicts?|depends?|desc|file|(?:d)?info|provides?';
    $debiancmd .= '|recommends?|suggests?|maint|maintainer';

    if ( $message =~ /^($debiancmd)(\s+(.*))?$/i ) {
        return unless ( &IsChanConfOrWarn('Debian') );
        my $package = lc $3;

        if ( defined $package ) {
            &Forker( 'Debian', sub { &Debian::infoPackages( $1, $package ); } );
        }
        else {
            &help($1);
        }

        return;
    }

    # google searching. Simon++
    my $w3search_regex = 'google';
    if ( $message =~
        /^(?:search\s+)?($w3search_regex)\s+(?:for\s+)?['"]?(.*?)["']?\s*\?*$/i
      )
    {
        return unless ( &IsChanConfOrWarn('W3Search') );

        &Forker( 'W3Search', sub { &W3Search::W3Search( $1, $2 ); } );

        $cmdstats{'W3Search'}++;
        return;
    }

    # text counters. (eg: hehstats)
    my $itc;
    $itc = &getChanConf('ircTextCounters');
    $itc = &findChanConf('ircTextCounters') unless ($itc);
    return if ( $itc && &do_text_counters($itc) == 1 );

    # end of text counters.

    # list{keys|values}. xk++. Idea taken from #linuxwarez@EFNET
    if ( $message =~ /^list(\S+)(\s+(.*))?$/i ) {
        return unless ( &IsChanConfOrWarn('Search') );

        my $thiscmd = lc $1;
        my $args = $3 || '';

        $thiscmd =~ s/^vals$/values/;
        return if ( $thiscmd ne 'keys' && $thiscmd ne 'values' );

        # Usage:
        if ( !defined $args or $args =~ /^\s*$/ ) {
            &help( 'list' . $thiscmd );
            return;
        }

        # suggested by asuffield and \broken.
        if ( $args =~ /^["']/ and $args =~ /["']$/ ) {
            &DEBUG('list*: removed quotes.');
            $args =~ s/^["']|["']$//g;
        }

        if ( length $args < 2 && &IsFlag('o') ne 'o' ) {
            &msg( $who, 'search string is too short.' );
            return;
        }

        &Forker( 'Search', sub { &Search::Search( $thiscmd, $args ); } );

        $cmdstats{'Factoid Search'}++;
        return;
    }

    # Topic management. xk++
    # may want to add a userflags for topic. -xk
    if ( $message =~ /^topic(\s+(.*))?$/i ) {
        return unless ( &IsChanConfOrWarn('Topic') );

        my $chan = $talkchannel;
        my @args = split / /, $2 || '';

        if ( !scalar @args ) {
            &msg( $who, "Try 'help topic'" );
            return;
        }

        $chan = lc( shift @args ) if ( $msgType eq 'private' );
        my $thiscmd = shift @args;

        # topic over public:
        if ( $msgType eq 'public' && $thiscmd =~ /^#/ ) {
            &msg( $who, 'error: channel argument is not required.' );
            &msg( $who, "\002Usage\002: topic <CMD>" );
            return;
        }

        # topic over private:
        if ( $msgType eq 'private' && $chan !~ /^#/ ) {
            &msg( $who, 'error: channel argument is required.' );
            &msg( $who, "\002Usage\002: topic #channel <CMD>" );
            return;
        }

        if ( &validChan($chan) == 0 ) {
            &msg( $who, "error: invalid channel \002$chan\002" );
            return;
        }

        # for semi-outsiders.
        if ( !&IsNickInChan( $who, $chan ) ) {
            &msg( $who, "Failed. You ($who) are not in $chan, hey?" );
            return;
        }

        # now lets do it.
        &loadMyModule('Topic');
        &Topic( $chan, $thiscmd, join( ' ', @args ) );
        $cmdstats{'Topic'}++;
        return;
    }

    # wingate.
    if ( $message =~ /^wingate$/i ) {
        return unless ( &IsChanConfOrWarn('Wingate') );

        my $reply =
            "Wingate statistics: scanned \002"
          . scalar( keys %wingateToDo )
          . "\002 hosts";
        my $queue = scalar( keys %wingateToDo );
        if ($queue) {
            $reply .= ".  I have \002$queue\002 hosts in the queue";
            $reply .=
              '.  Started the scan '
              . &Time2String( time() - $wingaterun ) . ' ago';
        }

        &performStrictReply("$reply.");

        return;
    }

    # do nothing and let the other routines have a go
    return 'CONTINUE';
}

# Uptime. xk++
sub uptime {
    my $count = 1;
    &msg( $who, "- Uptime for $ident -" );
    &msg( $who,
        'Now: ' . &Time2String( &uptimeNow() ) . " running $bot_version" );

    foreach ( &uptimeGetInfo() ) {
        /^(\d+)\.\d+ (.*)/;
        my $time = &Time2String($1);
        my $info = $2;

        &msg( $who, "$count: $time $2" );
        $count++;
    }
}

# seen.
sub seen {
    my ($person) = lc shift;
    $person =~ s/\?*$//;

    if ( !defined $person or $person =~ /^$/ ) {
        &help('seen');

        my $i = &countKeys('seen');
        &msg( $who,
                'there '
              . &fixPlural( 'is', $i )
              . " \002$i\002 " . 'seen '
              . &fixPlural( 'entry', $i )
              . ' that I know of.' );

        return;
    }

    my @seen;

    &seenFlush();    # very evil hack. oh well, better safe than sorry.

    # TODO: convert to &sqlSelectRowHash();
    my $select = 'nick,time,channel,host,message';
    if ( $person eq 'random' ) {
        @seen = &randKey( 'seen', $select );
    }
    else {
        @seen = &sqlSelect( 'seen', $select, { nick => $person } );
    }

    if ( scalar @seen < 2 ) {
        foreach (@seen) {
            &DEBUG("seen: _ => '$_'.");
        }
        &performReply("i haven't seen '$person'");
        return;
    }

    # valid seen.
    my $reply;
    ### TODO: multi channel support. may require &IsNick() to return
    ###	all channels or something.

    my @chans = &getNickInChans( $seen[0] );
    if ( scalar @chans ) {
        $reply = "$seen[0] is currently on";

        foreach (@chans) {
            $reply .= ' ' . $_;
            next unless ( exists $userstats{ lc $seen[0] }{'Join'} );
            $reply .= ' ('
              . &Time2String( time() - $userstats{ lc $seen[0] }{'Join'} )
              . ')';
        }

        if ( &IsChanConf('seenStats') > 0 ) {
            my $i;
            $i = $userstats{ lc $seen[0] }{'Count'};
            $reply .= ". Has said a total of \002$i\002 messages"
              if ( defined $i );
            $i = $userstats{ lc $seen[0] }{'Time'};
            $reply .= '. Is idling for ' . &Time2String( time() - $i )
              if ( defined $i );
        }
        $reply .= ", last said\002:\002 '$seen[4]'.";
    }
    else {
        my $howlong = &Time2String( time() - $seen[1] );
        $reply =
            "$seen[0] <$seen[3]> was last seen on IRC "
          . "in channel $seen[2], $howlong ago, "
          . "saying\002:\002 '$seen[4]'.";
    }

    &performStrictReply($reply);
    return;
}

# User Information Services. requested by Flugh.
sub userinfo {
    my ($arg) = join( ' ', @_ );

    if ( $arg =~ /^set(\s+(.*))?$/i ) {
        $arg = $2;
        if ( !defined $arg ) {
            &help('userinfo set');
            return;
        }

        &UserInfoSet( split /\s+/, $arg, 2 );
    }
    elsif ( $arg =~ /^unset(\s+(.*))?$/i ) {
        $arg = $2;
        if ( !defined $arg ) {
            &help('userinfo unset');
            return;
        }

        &UserInfoSet( $arg, '' );
    }
    else {
        &UserInfoGet($arg);
    }
}

# cookie (random). xk++
sub cookie {
    my ($arg) = @_;

    # lets find that secret cookie.
    my $target = ( $msgType ne 'public' ) ? $who : $talkchannel;
    my $cookiemsg = &getRandom( keys %{ $lang{'cookie'} } );
    my ( $key, $value );

    ### WILL CHEW TONS OF MEM.
    ### TODO: convert this to a Forker function!
    if ($arg) {
        my @list =
          &searchTable( 'factoids', 'factoid_key', 'factoid_value', $arg );
        $key = &getRandom(@list);
        $value = &getFactInfo( $key, 'factoid_value' );
    }
    else {
        ( $key, $value ) = &randKey( 'factoids', 'factoid_key,factoid_value' );
    }

    for ($cookiemsg) {
        s/##KEY/\002$key\002/;
        s/##VALUE/$value/;
        s/##WHO/$who/;
        s/\$who/$who/;    # cheap fix.
        s/(\S+)?\s*<\S+>/$1 /;
        s/\s+/ /g;
    }

    if ( $cookiemsg =~ s/^ACTION //i ) {
        &action( $target, $cookiemsg );
    }
    else {
        &msg( $target, $cookiemsg );
    }
}

sub convert {
    my $arg = join( ' ', @_ );
    my ( $from, $to ) = ( '', '' );

    ( $from, $to ) = ( $1, $2 ) if ( $arg =~ /^(.*?) to (.*)$/i );
    ( $from, $to ) = ( $2, $1 ) if ( $arg =~ /^(.*?) from (.*)$/i );

    if ( !$to or !$from ) {
        &msg( $who, 'Invalid format!' );
        &help('convert');
        return;
    }

    &Units::convertUnits( $from, $to );

    return;
}

sub lart {
    my ($target) = &fixString( $_[0] );
    my $extra    = 0;
    my $chan     = $talkchannel;
    my ($for);
    my $mynick = $conn->nick();

    if ( $msgType eq 'private' ) {
        if ( $target =~ /^($mask{chan})\s+(.*)$/ ) {
            $chan   = $1;
            $target = $2;
            $extra  = 1;
        }
        else {
            &msg( $who, 'error: invalid format or missing arguments.' );
            &help('lart');
            return;
        }
    }
    if ( $target =~ /^(.*)(\s+for\s+.*)$/ ) {
        $target = $1;
        $for    = $2;
    }

    my $line = &getRandomLineFromFile( $bot_data_dir . '/infobot.lart' );
    if ( defined $line ) {
        if ( $target =~ /^(me|you|itself|\Q$mynick\E)$/i ) {
            $line =~ s/WHO/$who/g;
        }
        else {
            $line =~ s/WHO/$target/g;
        }
        $line .= $for if ($for);
        $line .= ", courtesy of $who" if ($extra);

        &action( $chan, $line );
    }
    else {
        &status('lart: error reading file?');
    }
}

sub DebianNew {
    my $idx   = 'debian/Packages-sid.idx';
    my $error = 0;
    my %pkg;
    my @new;

    $error++ unless ( -e $idx );
    $error++ unless ( -e "$idx-old" );

    if ($error) {
        $error = 'no sid/sid-old index file found.';
        &ERROR("Debian: $error");
        &msg( $who, $error );
        return;
    }

    open( IDX1, $idx );
    open( IDX2, "$idx-old" );

    while (<IDX2>) {
        chop;
        next if (/^\*/);

        $pkg{$_} = 1;
    }
    close IDX2;

    open( IDX1, $idx );
    while (<IDX1>) {
        chop;
        next if (/^\*/);
        next if ( exists $pkg{$_} );

        push( @new, $_ );
    }
    close IDX1;

    &::performStrictReply(
        &::formListReply( 0, 'New debian packages:', @new ) );
}

sub do_verstats {
    my ($chan) = @_;

    if ( !defined $chan ) {
        &help('verstats');
        return;
    }

    if ( !&validChan($chan) ) {
        &msg( $who, "chan $chan is invalid." );
        return;
    }

    if ( scalar @vernick > scalar( keys %{ $channels{ lc $chan }{''} } ) / 4 ) {
        &msg( $who, 'verstats already in progress for someone else.' );
        return;
    }

    &msg( $who,  "Sending CTCP VERSION to $chan; results in 60s." );
    &msg( $chan, "WARNING: $who has forced me to CTCP VERSION the channel!" );

    # Workaround for bug in Net::Irc, provided by quin@freenode. Details at:
    # http://rt.cpan.org/Public/Bug/Display.html?id=11421
    # $conn->ctcp( 'VERSION', $chan );
    $conn->sl("PRIVMSG $chan :\001VERSION\001");

    $cache{verstats}{chan}    = $chan;
    $cache{verstats}{who}     = $who;
    $cache{verstats}{msgType} = $msgType;

    $conn->schedule(
        30,
        sub {
            my $c = lc $cache{verstats}{chan};
            @vernicktodo = ();

            foreach ( keys %{ $channels{$c}{''} } ) {
                next if ( grep /^\Q$_\E$/i, @vernick );
                push( @vernicktodo, $_ );
            }

            &verstats_flush();
        }
    );

    $conn->schedule(
        60,
        sub {
            my $vtotal = 0;
            my $c      = lc $cache{verstats}{chan};
            my $total  = keys %{ $channels{$c}{''} };
            $who     = $cache{verstats}{who};
            $msgType = $cache{verstats}{msgType};
            delete $cache{verstats};    # sufficient?

            foreach ( keys %ver ) {
                $vtotal += scalar keys %{ $ver{$_} };
            }

            my %sorted;
            my $unknown = $total - $vtotal;
            my $perc = sprintf( '%.1f', $unknown * 100 / $total );
            $perc =~ s/.0$//;
            $sorted{$perc}{'unknown/cloak'} = "$unknown ($perc%)" if ($unknown);

            foreach ( keys %ver ) {
                my $count = scalar keys %{ $ver{$_} };
                $perc = sprintf( '%.01f', $count * 100 / $total );
                $perc =~ s/.0$//;    # lame compression.

                $sorted{$perc}{$_} = "$count ($perc%)";
            }

            ### can be compressed to a map?
            my @list;
            foreach ( sort { $b <=> $a } keys %sorted ) {
                my $perc = $_;
                foreach ( sort keys %{ $sorted{$perc} } ) {
                    push( @list, "$_ - $sorted{$perc}{$_}" );
                }
            }

            # hack. this is one major downside to scheduling.
            &msg($c,
                &formListReply( 0, "IRC Client versions for $c ", @list ) );

            # clean up not-needed data structures.
            undef %ver;
            undef @vernick;
        }
    );

    return;
}

sub verstats_flush {
    for ( 1 .. 5 ) {
        last unless ( scalar @vernicktodo );

        my $n = shift(@vernicktodo);
        #$conn->ctcp( 'VERSION', $n );
        # See do_verstats $conn->sl for explantaion
        $conn->sl("PRIVMSG $n :\001VERSION\001");
    }

    return unless ( scalar @vernicktodo );

    $conn->schedule( 3, \&verstats_flush() );
}

sub do_text_counters {
    my ($itc) = @_;
    $itc =~ s/([^\w\s])/\\$1/g;
    my $z = join '|', split ' ', $itc;

    if ( $msgType eq 'privmsg' and $message =~ / ($mask{chan})$/ ) {
        &DEBUG("ircTC: privmsg detected; chan = $1");
        $chan = $1;
    }

    my ( $type, $arg );
    if ( $message =~ /^($z)stats(\s+(\S+))?$/i ) {
        $type = $1;
        $arg  = $3;
    }
    else {
        return 0;
    }

    my $c = $chan || 'PRIVATE';

    # Define various types of stats in one place.
    # Note: sqlSelectColHash has built in sqlQuote
    my $where_chan_type = { channel => $c, type => $type };
    my $where_chan_type_nick = { channel => $c, type => $type, nick => $arg };

    my $sum = ( &sqlSelect( 'stats', 'SUM(counter)', $where_chan_type ) )[0];

    if ( !defined $arg or $arg =~ /^\s*$/ ) {

        # get top 3 stats of $type in $chan
        my %hash =
          &sqlSelectColHash( 'stats', 'nick,counter', $where_chan_type,
            'ORDER BY counter DESC LIMIT 3', 1 );
        my $i;
        my @top;

        # unfortunately we have to sort it again!
        my $tp = 0;
        foreach $i ( sort { $b <=> $a } keys %hash ) {
            foreach ( keys %{ $hash{$i} } ) {
                my $p = sprintf( '%.01f', 100 * $i / $sum );
                $tp += $p;
                push( @top, "\002$_\002 -- $i ($p%)" );
            }
        }
        my $topstr = '';
        if ( scalar @top ) {
            $topstr = '.  Top ' . scalar(@top) . ': ' . join( ', ', @top );
        }

        if ( defined $sum ) {
            &performStrictReply(
                "total count of \037$type\037 on \002$c\002: $sum$topstr");
        }
        else {
            &performStrictReply("zero counter for \037$type\037.");
        }
    }
    else {
        my $x =
          ( &sqlSelect( 'stats', 'SUM(counter)', $where_chan_type_nick ) )[0];

        if ( !defined $x ) {    # If no stats were found
            &performStrictReply("$arg has not said $type yet.");
            return 1;
        }

        # Get list of all nicks for channel $c and $type
        my @array =
          &sqlSelectColArray( 'stats', 'nick', $where_chan_type,
            'ORDER BY counter DESC' );

        my $total = scalar(@array);
        my $rank;

        # Find position of nick $arg in the list
        for ( my $i = 0 ; $i < $total ; $i++ ) {
            next unless ( $array[$i] =~ /^\Q$arg\E$/ );
            $rank = $i + 1;
            last;
        }

        my $xtra;
        if ( $total and $rank ) {
            my $pct = sprintf( '%.01f', 100 * ($rank) / $total );
            $xtra =
              ", ranked $rank\002/\002$total (percentile: \002$pct\002 %)";
        }

        my $pct1 = sprintf( '%.01f', 100 * $x / $sum );
        &performStrictReply(
"\002$arg\002 has said \037$type\037 \002$x\002 times (\002$pct1\002 %)$xtra"
        );
    }

    return 1;
}

%cmdhooks=();
###
### START ADDING HOOKS.
###
&addCmdHook('(babel(fish)?|x|xlate|translate)', ('CODEREF' => 'babelfish::babelfish', 'Identifier' => 'babelfish', 'Cmdstats' => 'babelfish', 'Forker' => 1, 'Help' => 'babelfish', 'Module' => 'babelfish') );
&addCmdHook('(botmail|message)', ('CODEREF' => 'botmail::parse', 'Identifier' => 'botmail', 'Cmdstats' => 'botmail') );
&addCmdHook('bzflist17', ('CODEREF' => 'BZFlag::list17', 'Identifier' => 'BZFlag', 'Cmdstats' => 'BZFlag', 'Forker' => 1, 'Module' => 'BZFlag') );
&addCmdHook('bzflist', ('CODEREF' => 'BZFlag::list', 'Identifier' => 'BZFlag', 'Cmdstats' => 'BZFlag', 'Forker' => 1, 'Module' => 'BZFlag') );
&addCmdHook('bzfquery', ('CODEREF' => 'BZFlag::query', 'Identifier' => 'BZFlag', 'Cmdstats' => 'BZFlag', 'Forker' => 1, 'Module' => 'BZFlag') );
&addCmdHook('chan(stats|info)', ('CODEREF' => 'chaninfo', ) );
&addCmdHook('cmd(stats|info)', ('CODEREF' => 'cmdstats', ) );
&addCmdHook('convert', ('CODEREF' => 'convert', 'Forker' => 1, 'Identifier' => 'Units', 'Help' => 'convert') );
&addCmdHook('(cookie|random)', ('CODEREF' => 'cookie', 'Forker' => 1, 'Identifier' => 'Factoids') );
&addCmdHook('countdown', ('CODEREF' => 'countdown', 'Module' => 'countdown', 'Identifier' => 'countdown', 'Cmdstats' => 'countdown') );
&addCmdHook('countrystats', ('CODEREF' => 'countryStats') );
&addCmdHook('dauthor', ('CODEREF' => 'Debian::searchAuthor', 'Forker' => 1, 'Identifier' => 'Debian', 'Cmdstats' => 'Debian Author Search', 'Help' => 'dauthor' ) );
&addCmdHook('d?bugs', ('CODEREF' => 'DebianExtra::Parse', 'Forker' => 1, 'Identifier' => 'DebianExtra', 'Cmdstats' => 'Debian Bugs') );
&addCmdHook('d?contents', ('CODEREF' => 'Debian::searchContents', 'Forker' => 1, 'Identifier' => 'Debian', 'Cmdstats' => 'Debian Contents Search', 'Help' => 'contents' ) );
&addCmdHook('d?find', ('CODEREF' => 'Debian::DebianFind', 'Forker' => 1, 'Identifier' => 'Debian', 'Cmdstats' => 'Debian Search', 'Help' => 'find' ) );
&addCmdHook('dice', ('CODEREF' => 'dice::dice', 'Identifier' => 'dice', 'Cmdstats' => 'dice', 'Forker' => 1, 'Module' => 'dice') );
&addCmdHook('Dict', ('CODEREF' => 'Dict::Dict', 'Identifier' => 'Dict', 'Help' => 'dict', 'Forker' => 1, 'Cmdstats' => 'Dict') );
&addCmdHook('dincoming', ('CODEREF' => 'Debian::generateIncoming', 'Forker' => 1, 'Identifier' => 'Debian' ) );
&addCmdHook('dnew', ('CODEREF' => 'DebianNew', 'Identifier' => 'Debian' ) );
&addCmdHook('dns|d?nslookup', ('CODEREF' => 'dns::query', 'Identifier' => 'dns', 'Cmdstats' => 'dns', 'Forker' => 1, 'Help' => 'dns') );
&addCmdHook('(d|search)desc', ('CODEREF' => 'Debian::searchDescFE', 'Forker' => 1, 'Identifier' => 'Debian', 'Cmdstats' => 'Debian Desc Search', 'Help' => 'ddesc' ) );
&addCmdHook('dstats', ('CODEREF' => 'Debian::infoStats', 'Forker' => 1, 'Identifier' => 'Debian', 'Cmdstats' => 'Debian Statistics' ) );
&addCmdHook('(ex)?change', ('CODEREF' => 'Exchange::query', 'Identifier' => 'Exchange', 'Cmdstats' => 'Exchange', 'Forker' => 1) );
&addCmdHook('factinfo', ('CODEREF' => 'factinfo', 'Cmdstats' => 'Factoid Info', Module => 'Factoids', ) );
&addCmdHook('factstats?', ('CODEREF' => 'factstats', 'Cmdstats' => 'Factoid Stats', Help => 'factstats', Forker => 1, 'Identifier' => 'Factoids', ) );
&addCmdHook('help', ('CODEREF' => 'help', 'Cmdstats' => 'Help', ) );
&addCmdHook('hex2ip', ('CODEREF' => 'hex2ip::query', 'Forker' => 1, 'Identifier' => 'hex2ip', 'Cmdstats' => 'hex2ip', 'Help' => 'hex2ip') );
&addCmdHook('HTTPDtype', ('CODEREF' => 'HTTPDtype::HTTPDtype', 'Identifier' => 'HTTPDtype', 'Cmdstats' => 'HTTPDtype', 'Forker' => 1) );
&addCmdHook('[ia]?spell', ('CODEREF' => 'spell::query', 'Identifier' => 'spell', 'Cmdstats' => 'spell', 'Forker' => 1, 'Help' => 'spell') );
&addCmdHook('insult', ('CODEREF' => 'Insult::Insult', 'Forker' => 1, 'Identifier' => 'insult', 'Help' => 'insult' ) );
&addCmdHook('karma', ('CODEREF' => 'karma', ) );
&addCmdHook('kernel', ('CODEREF' => 'Kernel::Kernel', 'Forker' => 1, 'Identifier' => 'Kernel', 'Cmdstats' => 'Kernel', 'NoArgs' => 1) );
&addCmdHook('lart', ('CODEREF' => 'lart', 'Identifier' => 'lart', 'Help' => 'lart') );
&addCmdHook('lc', ('CODEREF' => 'case::lower', 'Identifier' => 'case', 'Cmdstats' => 'case', 'Forker' => 1, 'Module' => 'case') );
&addCmdHook('listauth', ('CODEREF' => 'CmdListAuth', 'Identifier' => 'Search', Module => 'Factoids', 'Help' => 'listauth') );
&addCmdHook('md5(sum)?', ('CODEREF' => 'md5::md5', 'Identifier' => 'md5', 'Cmdstats' => 'md5', 'Forker' => 1, 'Module' => 'md5') );
&addCmdHook('metar', ('CODEREF' => 'Weather::Metar', 'Identifier' => 'Weather', 'Help' => 'weather', 'Cmdstats' => 'Weather', 'Forker' => 1) );
&addCmdHook('News', ('CODEREF' => 'News::Parse', Module => 'News', 'Cmdstats' => 'News', 'Identifier' => 'News' ) );
&addCmdHook('(?:nick|lame)ometer(?: for)?', ('CODEREF' => 'nickometer::query', 'Identifier' => 'nickometer', 'Cmdstats' => 'nickometer', 'Forker' => 1) );
&addCmdHook('OnJoin', ('CODEREF' => 'Cmdonjoin', 'Identifier' => 'OnJoin', 'Module' => 'OnJoin') );
&addCmdHook('page', ('CODEREF' => 'pager::page', 'Identifier' => 'pager', 'Cmdstats' => 'pager', 'Forker' => 1, 'Help' => 'page') );
&addCmdHook('piglatin', ('CODEREF' => 'piglatin::piglatin', 'Identifier' => 'piglatin', 'Cmdstats' => 'piglatin', 'Forker' => 1) );
&addCmdHook('Plug', ('CODEREF' => 'Plug::Plug', 'Identifier' => 'Plug', 'Forker' => 1, 'Cmdstats' => 'Plug') );
&addCmdHook('quote', ('CODEREF' => 'Quote::Quote', 'Forker' => 1, 'Identifier' => 'Quote', 'Help' => 'quote', 'Cmdstats' => 'Quote') );
&addCmdHook('reverse', ('CODEREF' => 'reverse::reverse', 'Identifier' => 'reverse', 'Cmdstats' => 'reverse', 'Forker' => 1, 'Module' => 'reverse') );
&addCmdHook('RootWarn', ('CODEREF' => 'CmdrootWarn', 'Identifier' => 'RootWarn', 'Module' => 'RootWarn') );
&addCmdHook('Rss', ('CODEREF' => 'Rss::Rss', 'Identifier' => 'Rss', 'Cmdstats' => 'Rss', 'Forker' => 1, 'Help' => 'rss') );
&addCmdHook('RSSFeeds',('CODEREF' => 'RSSFeeds::RSS', 'Identifier' => 'RSSFeeds', 'Forker' => 1, 'Help' => 'rssfeeds', 'Cmdstats' => 'RSSFeeds', 'Module' => 'RSSFeeds') );
&addCmdHook('sched(stats|info)', ('CODEREF' => 'scheduleList', ) );
&addCmdHook('scramble', ('CODEREF' => 'scramble::scramble', 'Identifier' => 'scramble', 'Cmdstats' => 'scramble', 'Forker' => 1, 'Module' => 'scramble') );
&addCmdHook('seen', ('CODEREF' => 'seen', 'Identifier' => 'seen') );
&addCmdHook('slashdot', ('CODEREF' => 'Slashdot::Slashdot', 'Identifier' => 'slashdot', 'Forker' => 1, 'Cmdstats' => 'slashdot') );
&addCmdHook('tell|explain', ('CODEREF' => 'tell', Help => 'tell', Identifier => 'allowTelling', Cmdstats => 'Tell') );
&addCmdHook('uc', ('CODEREF' => 'case::upper', 'Identifier' => 'case', 'Cmdstats' => 'case', 'Forker' => 1, 'Module' => 'case') );
&addCmdHook('upsidedown', ('CODEREF' => 'upsidedown::upsidedown', 'Identifier' => 'upsidedown', 'Cmdstats' => 'upsidedown', 'Forker' => 1, 'Module' => 'upsidedown') );
&addCmdHook('Uptime', ('CODEREF' => 'uptime', 'Identifier' => 'Uptime', 'Cmdstats' => 'Uptime') );
&addCmdHook('u(ser)?info', ('CODEREF' => 'userinfo', 'Identifier' => 'UserInfo', 'Help' => 'userinfo', 'Module' => 'UserInfo') );
&addCmdHook('verstats', ('CODEREF' => 'do_verstats', 'Identifier' => 'verstats', 'Help' => 'verstats', 'Cmdstats' => 'verstats') );
&addCmdHook('Weather', ('CODEREF' => 'Weather::Weather', 'Identifier' => 'Weather', 'Help' => 'weather', 'Cmdstats' => 'Weather', 'Forker' => 1, 'Module' => 'Weather') );
&addCmdHook('wiki(pedia)?', ('CODEREF' => 'wikipedia::wikipedia', 'Identifier' => 'wikipedia', 'Cmdstats' => 'wikipedia', 'Forker' => 1, 'Help' => 'wikipedia', 'Module' => 'wikipedia') );
&addCmdHook('wtf', ('CODEREF' => 'wtf::query', 'Identifier' => 'wtf', 'Cmdstats' => 'wtf', 'Forker' => 1, 'Help' => 'wtf', 'Module' => 'wtf') );
&addCmdHook('zfi', ('CODEREF' => 'zfi::query', 'Identifier' => 'zfi', 'Cmdstats' => 'zfi', 'Forker' => 1, 'Module' => 'zfi') );
&addCmdHook('(zippy|yow)', ('CODEREF' => 'zippy::get', 'Identifier' => 'Zippy', 'Cmdstats' => 'Zippy', 'Forker' => 1, 'Module' => 'Zippy') );
&addCmdHook('zsi', ('CODEREF' => 'zsi::query', 'Identifier' => 'zsi', 'Cmdstats' => 'zsi', 'Forker' => 1, 'Module' => 'zsi') );
###
### END OF ADDING HOOKS.
###

&status( 'loaded ' . scalar( keys %cmdhooks ) . ' command hooks.' );

1;

# vim:ts=4:sw=4:expandtab:tw=80
