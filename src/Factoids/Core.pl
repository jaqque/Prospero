#
#   Misc.pl: Miscellaneous stuff.
#    Author: dms
#   Version: v0.1 (20010906)
#   Created: 20010906
#

# use strict;	# TODO

use vars qw(%param %cache %lang %cmdstats %bots);
use vars qw($message $who $addressed $chan $h $nuh $ident $msgType
  $correction_plausable);

# Usage: &validFactoid($lhs,$rhs);
sub validFactoid {
    my ( $lhs, $rhs ) = @_;
    my $valid = 0;

    for ( lc $lhs ) {

        # allow the following only if they have been made on purpose.
        if ( $rhs ne '' and $rhs !~ /^</ ) {
            / \Q$ident\E$/i and last;    # someone said i'm something.
            /^i('m)? /    and last;
            /^(it|that|there|what)('s)?(\s+|$)/ and last;
            /^you('re)?(\s+|$)/                 and last;

            /^(where|who|why|when|how)(\s+|$)/     and last;
            /^(this|that|these|those|they)(\s+|$)/ and last;
            /^(every(one|body)|we) /               and last;

            /^say / and last;
        }

        # uncaught commands.
        /^add topic /         and last;    # topic management.
        /( add$| add |^add )/ and last;    # borked teach statement.
        /^learn /             and last;    # teach. damn morons.
        /^tell (\S+) about /  and last;    # tell.
        /\=\~/                and last;    # substituition.

        /^\=/               and last;      # botnick = heh is.
        /wants you to know/ and last;

        # symbols.
        /(\"\*)/ and last;
        /, /     and last;
        ( /^'/ and /'$/ ) and last;
        ( /^"/ and /"$/ ) and last;

        # delimiters.
        /\=\>/ and last;                   # '=>'.
        /\;\;/ and last;                   # ';;'.
        /\|\|/ and last;                   # '||'.

        /^\Q$ident\E[\'\,\: ]/ and last;   # dupe addressed.
        /^[\-\, ]/             and last;
        /\\$/                  and last;   # forgot shift for '?'.
        /^all /                and last;
        /^also /               and last;
        / also$/               and last;
        / and$/                and last;
        /^because /            and last;
        /^but /                and last;
        /^gives /              and last;
        /^h(is|er) /           and last;
        /^if /                 and last;
        / is,/                 and last;
        / it$/                 and last;
        /^or /                 and last;
        / says$/               and last;
        /^should /             and last;
        /^so /                 and last;
        /^supposedly/          and last;
        /^to /                 and last;
        /^was /                and last;
        / which$/              and last;

        # nasty bug I introduced _somehow_, probably by fixMySQLBug().
        /\\\%/ and last;
        /\\\_/ and last;

        # weird/special stuff. also old infobot bugs.
        $rhs =~ /( \Q$ident\E's|\Q$ident\E's )/i and last;    # ownership.

        # duplication.
        $rhs =~ /^\Q$lhs\E /i and last;
        last if ( $rhs =~ /^is /i and / is$/ );

        $valid++;
    }

    return $valid;
}

sub FactoidStuff {

    # inter-infobot.
    if ( $msgType =~ /private/ and $message =~ s/^:INFOBOT:// ) {
        ### identification.
        &status("infobot <$nuh> identified") unless $bots{$nuh};
        $bots{$nuh} = $who;

        ### communication.

        # query.
        if ( $message =~ /^QUERY (<.*?>) (.*)/ ) {    # query.
            my ( $target, $item ) = ( $1, $2 );
            $item =~ s/[.\?]$//;

            &status(":INFOBOT:QUERY $who: $message");

            if ( $_ = &getFactoid($item) ) {
                &msg( $who, ":INFOBOT:REPLY $target $item =is=> $_" );
            }

            return 'INFOBOT QUERY';
        }
        elsif ( $message =~ /^REPLY <(.*?)> (.*)/ ) {    # reply.
            my ( $target, $item ) = ( $1, $2 );

            &status(":INFOBOT:REPLY $who: $message");

            my ( $lhs, $mhs, $rhs ) = $item =~ /^(.*?) =(.*?)=> (.*)/;

            if (   $param{'acceptUrl'} !~ /REQUIRE/
                or $rhs =~ /(http|ftp|mailto|telnet|file):/ )
            {
                &msg( $target, "$who knew: $lhs $mhs $rhs" );

                # 'are' hack :)
                $rhs = "<REPLY> are" if ( $mhs eq 'are' );
                &setFactInfo( $lhs, 'factoid_value', $rhs );
            }

            return 'INFOBOT REPLY';
        }
        else {
            &ERROR(":INFOBOT:UNKNOWN $who: $message");
            return 'INFOBOT UNKNOWN';
        }
    }

    # factoid forget.
    if ( $message =~ s/^forget\s+//i ) {
        return 'forget: no addr' unless ($addressed);

        my $faqtoid = $message;
        if ( $faqtoid eq '' ) {
            &help('forget');
            return;
        }

        $faqtoid =~ tr/A-Z/a-z/;
        my $result = &getFactoid($faqtoid);

        # if it doesn't exist, well... it doesn't!
        if ( !defined $result ) {
            &performReply("i didn't have anything called '$faqtoid' to forget");
            return;
        }

        # TODO: squeeze 3 getFactInfo calls into one?
        my $author = &getFactInfo( $faqtoid, 'created_by' );
        my $count = &getFactInfo( $faqtoid, 'requested_count' ) || 0;

        # don't delete if requested $limit times
        my $limit =
          &getChanConfDefault( 'factoidPreventForgetLimit', 100, $chan );

     # don't delete if older than $limitage seconds (modified by requests below)
        my $limitage = &getChanConfDefault( 'factoidPreventForgetLimitTime',
            7 * 24 * 60 * 60, $chan );
        my $t = &getFactInfo( $faqtoid, 'created_time' ) || 0;
        my $age = time() - $t;

        # lets scale limitage from 1 (nearly 0) to $limit (full time).
        $limitage = $limitage * ( $count + 1 ) / $limit if ( $count < $limit );

        # isauthor and isop.
        my $isau = ( defined $author and &IsHostMatch($author) == 2 ) ? 1 : 0;
        my $isop = ( &IsFlag('o') eq 'o' ) ? 1 : 0;

        if ( IsFlag('r') ne 'r' && !$isop ) {
            &msg( $who, "you don't have access to remove factoids" );
            return;
        }

        return 'locked factoid' if ( &IsLocked($faqtoid) == 1 );

        ###
        ### lets go do some checking.
        ###

        # factoidPreventForgetLimitTime:
        if ( !( $isop or $isau ) and $age / ( 60 * 60 * 24 ) > $limitage ) {
            &msg( $who,
                    "cannot remove factoid '$faqtoid', too old. ("
                  . $age / ( 60 * 60 * 24 )
                  . ">$limitage) use 'no,' instead" );
            return;
        }

        # factoidPreventForgetLimit:
        if ( !( $isop or $isau ) and $limit and $count > $limit ) {
            &msg( $who,
"will not delete '$faqtoid', count > limit ($count > $limit) use 'no, ' instead."
            );
            return;
        }

        # this may eat some memory.
        # prevent deletion if other factoids redirect to it.
        # TODO: use hash instead of array.
        my @list;
        if ( &getChanConf('factoidPreventForgetRedirect') ) {
            &status("Factoids/Core: forget: checking for redirect factoids");
            @list =
              &searchTable( 'factoids', 'factoid_key', 'factoid_value',
                "^<REPLY> see " );
        }

        my $match = 0;
        for (@list) {
            my $f     = $_;
            my $v     = &getFactInfo( $f, 'factoid_value' );
            my $fsafe = quotemeta($faqtoid);
            next unless ( $v =~ /^<REPLY> ?see( also)? $fsafe\.?$/i );

            &DEBUG("Factoids/Core: match! ($f || $faqtoid)");

            $match++;
        }

        # TODO: warn for op aswell, but allow force delete.
        if ( !$isop and $match ) {
            &msg( $who,
                "uhm, other (redirection) factoids depend on this one." );
            return;
        }

        # minimize abuse.
        if ( !$isop and &IsHostMatch($author) != 2 ) {
            $cache{forget}{$h}++;

            # warn.
            if ( $cache{forget}{$h} > 3 ) {
                &msg( $who, "Stop abusing forget!" );
            }

            # ignore.
            # TODO: make forget limit configurable.
            # TODO: make forget ignore time configurable.
            if ( $cache{forget}{$h} > 5 ) {
                &ignoreAdd(
                    &makeHostMask($nuh), '*',
                    3 * 24 * 60,
                    "abuse of forget"
                );
                &msg( $who, "forget: Ignoring you for abuse!" );
            }
        }

        # lets do it!

        if (   &IsParam('factoidDeleteDelay')
            or &IsChanConf('factoidDeleteDelay') > 0 )
        {
            if ( !( $isop or $isau ) and $faqtoid =~ / #DEL#$/ ) {
                &msg( $who, "cannot delete it ($faqtoid)." );
                return;
            }

            &status( "forgot (safe delete): '$faqtoid' - " . scalar(gmtime) );
            ### TODO: check if the 'backup' exists and overwrite it
            my $check = &getFactoid("$faqtoid #DEL#");

            if ( !defined $check or $check =~ /^\s*$/ ) {
                if ( $faqtoid !~ / #DEL#$/ ) {
                    my $new = $faqtoid . " #DEL#";

                    my $backup = &getFactoid($new);
                    if ($backup) {
                        &DEBUG("forget: not overwriting backup: $faqtoid");
                    }
                    else {
                        &status("forget: backing up '$faqtoid'");
                        &setFactInfo( $faqtoid, 'factoid_key',   $new );
                        &setFactInfo( $new,     'modified_by',   $who );
                        &setFactInfo( $new,     'modified_time', time() );
                    }

                }
                else {
                    &status("forget: not backing up $faqtoid.");
                }

            }
            else {
                &status("forget: not overwriting backup!");
            }
        }

        &status("forget: <$who> '$faqtoid' =is=> '$result'");
        &delFactoid($faqtoid);

        &performReply("i forgot $faqtoid");

        $count{'Update'}++;

        return;
    }

    # factoid unforget/undelete.
    if ( $message =~ s/^un(forget|delete)\s+//i ) {
        return 'unforget: no addr' unless ($addressed);

        my $i = 0;
        $i++ if ( &IsParam('factoidDeleteDelay') );
        $i++ if ( &IsChanConf('factoidDeleteDelay') > 0 );
        if ( !$i ) {
            &performReply(
                "safe delete has been disable so what is there to undelete?");
            return;
        }

        my $faqtoid = $message;
        if ( $faqtoid eq '' ) {
            &help('unforget');
            return;
        }

        $faqtoid =~ tr/A-Z/a-z/;
        my $result = &getFactoid( $faqtoid . " #DEL#" );
        my $check  = &getFactoid($faqtoid);

        if ( defined $check ) {
            &performReply(
                "cannot undeleted '$faqtoid' because it already exists!");
            return;
        }

        if ( !defined $result ) {
            &performReply("that factoid was not backedup :/");
            return;
        }

        &setFactInfo( $faqtoid . " #DEL#", 'factoid_key', $faqtoid );

        #	&setFactInfo($faqtoid, 'modified_by',   '');
        #	&setFactInfo($faqtoid, 'modified_time', 0);

        $check = &getFactoid($faqtoid);

        # TODO: check if $faqtoid." #DEL#" exists?
        if ( defined $check ) {
            &performReply("Successfully recovered '$faqtoid'.  Have fun now.");
            $count{'Undelete'}++;
        }
        else {
            &performReply("did not recover '$faqtoid'.  What happened?");
        }

        return;
    }

    # factoid locking.
    if ( $message =~ /^((un)?lock)(\s+(.*))?\s*?$/i ) {
        return 'lock: no addr 2' unless ($addressed);

        my $function = lc $1;
        my $faqtoid  = lc $4;

        if ( $faqtoid eq '' ) {
            &help($function);
            return;
        }

        if ( &getFactoid($faqtoid) eq '' ) {
            &msg( $who, "factoid \002$faqtoid\002 does not exist" );
            return;
        }

        if ( $function eq 'lock' ) {

            # strongly requested by #debian on 19991028. -xk
            if ( 1 and $faqtoid !~ /^\Q$who\E$/i and &IsFlag('o') ne 'o' ) {
                &msg( $who,
"sorry, locking cannot be used since it can be abused unneccesarily."
                );
                &status(
                    "Replace 1 with 0 in Process.pl#~324 for locking support.");
                return;
            }

            &CmdLock($faqtoid);
        }
        else {
            &CmdUnLock($faqtoid);
        }

        return;
    }

    # factoid rename.
    if ( $message =~ s/^rename(\s+|$)// ) {
        return 'rename: no addr' unless ($addressed);

        if ( $message eq '' ) {
            &help('rename');
            return;
        }

        if ( $message =~ /^'(.*)'\s+'(.*)'$/ ) {
            my ( $from, $to ) = ( lc $1, lc $2 );

            my $result = &getFactoid($from);
            if ( !defined $result ) {
                &performReply(
                    "i didn't have anything called '$from' to rename");
                return;
            }

            # author == nick!user@host
            # created_by == nick
            my $author = &getFactInfo( $from, 'created_by' );
            $author =~ /^(.*)!/;
            my $created_by = $1;

            # Can they even modify factoids?
            if (    &IsFlag('m') ne 'm'
                and &IsFlag('M') ne 'M'
                and &IsFlag('o') ne 'o' )
            {
                &performReply("You do not have permission to modify factoids");
                return;

                # If they have +M but they didnt create the factoid
            }
            elsif ( &IsFlag('M') eq 'M'
                and $who !~ /^\Q$created_by\E$/i
                and &IsFlag('m') ne 'm'
                and &IsFlag('o') ne 'o' )
            {
                &performReply("factoid '$from' is not yours to modify.");
                return;
            }

            # Else they have permission, so continue

            if ( $_ = &getFactoid($to) ) {
                &performReply("destination factoid already exists.");
                return;
            }

            &setFactInfo( $from, 'factoid_key', $to );

            &status("rename: <$who> '$from' is now '$to'");
            &performReply("i renamed '$from' to '$to'");
        }
        else {
            &msg( $who, "error: wrong format. ask me about 'help rename'." );
        }

        return;
    }

    # factoid substitution. (X =~ s/A/B/FLAG)
    if ( $message =~ m|^(.*?)\s+=~\s+s([/,#])(.+?)\2(.*?)\2([a-z]*);?\s*$| ) {
        my ( $faqtoid, $delim, $op, $np, $flags ) = ( lc $1, $2, $3, $4, $5 );
        return 'subst: no addr' unless ($addressed);

        # incorrect format.
        if ( $np =~ /$delim/ ) {
            &msg( $who,
"looks like you used the delimiter too many times. You may want to use a different delimiter, like ':' or '#'."
            );
            return;
        }

        # success.
        if ( my $result = &getFactoid($faqtoid) ) {
            return 'subst: locked' if ( &IsLocked($faqtoid) == 1 );
            my $was = $result;
            my $faqauth = &getFactInfo( $faqtoid, 'created_by' );

            if ( ( $flags eq 'g' && $result =~ s/\Q$op/$np/gi )
                || $result =~ s/\Q$op/$np/i )
            {
                my $author = $faqauth;
                $author =~ /^(.*)!/;
                my $created_by = $1;

                # Can they even modify factoids?
                if (    &IsFlag('m') ne 'm'
                    and &IsFlag('M') ne 'M'
                    and &IsFlag('o') ne 'o' )
                {
                    &performReply(
                        "You do not have permission to modify factoids");
                    return;

                    # If they have +M but they didnt create the factoid
                }
                elsif ( &IsFlag('M') eq 'M'
                    and $who !~ /^\Q$created_by\E$/i
                    and &IsFlag('m') ne 'm'
                    and &IsFlag('o') ne 'o' )
                {
                    &performReply("factoid '$faqtoid' is not yours to modify.");
                    return;
                }

                # excessive length.
                if ( length $result > $param{'maxDataSize'} ) {
                    &performReply("that's too long");
                    return;
                }

                # empty
                if ( length $result == 0 ) {
                    &performReply(
                        "factoid would be empty. Use forget instead.");
                    return;
                }

                # min length.
                if (    ( length $result ) * 2 < length $was
                    and &IsFlag('o') ne 'o'
                    and &IsHostMatch($faqauth) != 2 )
                {
                    &performReply("too drastic change of factoid.");
                }

                &setFactInfo( $faqtoid, 'factoid_value', $result );
                &status("update: '$faqtoid' =is=> '$result'; was '$was'");
                &performReply('OK');
            }
            else {
                &performReply("that doesn't contain '$op'");
            }
        }
        else {
            &performReply("i didn't have anything called '$faqtoid' to modify");
        }

        return;
    }

    # Fix up $message for question.
    my $question = $message;
    for ($question) {

        # fix the string.
        s/^where is //i;
        s/\s+\?$/?/;
        s/^whois //i;   # Must match ^, else factoids with "whois" anywhere break
        s/^who is //i;
        s/^what is (a|an)?//i;
        s/^how do i //i;
        s/^where can i (find|get|download)//i;
        s/^how about //i;
        s/ da / the /ig;

        # clear the string of useless words.
        s/^(stupid )?q(uestion)?:\s+//i;
        s/^(does )?(any|ne)(1|one|body) know //i;

        s/^[uh]+m*[,\.]* +//i;

        s/^well([, ]+)//i;
        s/^still([, ]+)//i;
        s/^(gee|boy|golly|gosh)([, ]+)//i;
        s/^(well|and|but|or|yes)([, ]+)//i;

        s/^o+[hk]+(a+y+)?([,. ]+)//i;
        s/^g(eez|osh|olly)([,. ]+)//i;
        s/^w(ow|hee|o+ho+)([,. ]+)//i;
        s/^heya?,?( folks)?([,. ]+)//i;
    }

    if ( $addressed and $message =~ s/^no([, ]+)(\Q$ident\E\,+)?\s*//i ) {
        $correction_plausible = 1;
        &status(
            "correction is plausible, initial negative and nick deleted ($&)")
          if ( $param{VERBOSITY} );
    }
    else {
        $correction_plausible = 0;
    }

    my $result = &doQuestion($question);
    if ( !defined $result or $result eq $noreply ) {
        return 'result from doQ undef.';
    }

    if ( defined $result and $result !~ /^0?$/ ) {    # question.
        &status("question: <$who> $message");
        $count{'Question'}++;
    }
    elsif ( &IsChanConf('Math') > 0 and $addressed ) {    # perl math.
        &loadMyModule('Math');
        my $newresult = &perlMath();

        if ( defined $newresult and $newresult ne '' ) {
            $cmdstats{'Maths'}++;
            $result = $newresult;
            &status("math: <$who> $message => $result");
        }
    }

    if ( $result !~ /^0?$/ ) {
        &performStrictReply($result);
        return;
    }

    # why would a friendly bot get passed here?
    if ( &IsParam('friendlyBots') ) {
        return
          if ( grep lc($_) eq lc($who),
            split( /\s+/, $param{'friendlyBots'} ) );
    }

    # do the statement.
    if ( !defined &doStatement($message) ) {
        return;
    }

    return unless ( $addressed and !$addrchar );

    if ( length $message > 64 ) {
        &status("unparseable-moron: $message");

        #	&performReply( &getRandom(keys %{ $lang{'moron'} }) );
        $count{'Moron'}++;

        &performReply( "You are moron \002#" . $count{'Moron'} . "\002" );
        return;
    }

    &status("unparseable: $message");
    &performReply( &getRandom( keys %{ $lang{'dunno'} } ) );
    $count{'Dunno'}++;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
