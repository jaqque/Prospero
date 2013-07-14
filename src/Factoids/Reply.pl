###
### Reply.pl: Kevin Lenzo   (c) 1997
###

##
# x is y === $lhs $mhs $rhs
#
#   lhs - factoid.
#   mhs - verb.
#   rhs - factoid message.
##

# use strict;	# TODO
use POSIX qw(strftime);

use vars qw($msgType $uh $lastWho $ident);
use vars qw(%lang %lastWho);

sub getReply {
    my ($message) = @_;
    my ( $lhs, $mhs, $rhs );
    my ( $reply, $count, $fauthor, $result, $factoid, $search, @searches );
    $orig{message} = $message;

    if ( !defined $message or $message =~ /^\s*$/ ) {
        &WARN("getR: message == NULL.");
        return '';
    }

    $message =~ tr/A-Z/a-z/;

    @searches =
      split( /\s+/, &getChanConfDefault( 'factoidSearch', '_default', $chan ) );
    &::DEBUG( "factoidSearch: $chan is: " . join( ':', @searches ) );

    # requesting the _default one, ignore factoidSearch
    if ( $message =~ /^_default\s+/ ) {
        @searches = ('_default');
        $message =~ s/^_default\s+//;
    }

    # check for factoids with each prefix
    foreach $search (@searches) {
        if ( $search eq '$chan' ) {
            $factoid = "$chan $message";
        }
        elsif ( $search eq '_default' ) {
            $factoid = $message;
        }
        else {
            $factoid = "$search $message";
        }
        ( $count, $fauthor, $result ) = &sqlSelect(
            'factoids',
            "requested_count,created_by,factoid_value",
            { factoid_key => $factoid }
        );
        last if ($result);
    }

    if ($result) {
        $lhs = $message;
        $mhs = 'is';
        $rhs = $result;

        return "\"$factoid\" $mhs \"$rhs\"" if ($literal);
    }
    else {
        return '';
    }

    # if there was a head...
    my (@poss) = split '\|\|', $result;
    $poss[0]      =~ s/^\s//;
    $poss[$#poss] =~ s/\s$//;

    if ( @poss > 1 ) {
        $result = &getRandom(@poss);
        $result =~ s/^\s*//;
    }

    $result = &SARit($result);

    $reply = $result;
    if ( $result ne '' ) {
        ### AT LAST, REPEAT PREVENTION CODE REMOVED IN FAVOUR OF GLOBAL
        ### FLOOD REPETION AND PROTECTION. -20000124

        # stats code.
        ### FIXME: old mysql/sqlite doesn't support
        ### "requested_count=requested_count+1".
        $count++;
        &sqlSet(
            'factoids',
            { 'factoid_key' => $factoid },
            {
                requested_by    => $nuh,
                requested_time  => time(),
                requested_count => $count
            }
        );

        # TODO: rename $real to something else!
        my $real = 0;

        #	my $author = &getFactInfo($lhs,'created_by') || '';
        #	$real++ if ($author =~ /^\Q$who\E\!/);
        #	$real++ if (&IsFlag('n'));
        $real = 0 if ( $msgType =~ /public/ );

        ### fix up the reply.
        # only remove '<reply>'
        if ( !$real and $reply =~ s/^\s*<reply>\s*//i ) {

            # 'are' fix.
            if ( $reply =~ s/^are /$lhs are /i ) {
                &VERB( "Reply.pl: el-cheapo 'are' fix executed.", 2 );
            }

        }
        elsif ( !$real and $reply =~ s/^\s*<action>\s*(.*)/\cAACTION $1\cA/i ) {

            # only remove '<action>' and make it an action.
        }
        else {    # not a short reply

            ### bot->bot reply.
            if ( exists $bots{$nuh} and $rhs !~ /^\s*$/ ) {
                return "$lhs $mhs $rhs";
            }

            ### bot->person reply.
            # result is random if separated by '||'.
            # rhs is full factoid with '||'.
            if ( $mhs eq 'is' ) {
                $reply = &getRandom( keys %{ $lang{'factoid'} } );
                $reply =~ s/##KEY/$lhs/;
                $reply =~ s/##VALUE/$result/;
            }
            else {
                $reply = "$lhs $mhs $result";
            }

            if ( $reply =~ s/^\Q$who\E is/you are/i ) {

                # fix the person.
            }
            else {
                if ( $reply =~ /^you are / or $reply =~ / you are / ) {
                    return if ($addressed);
                }
            }
        }
    }

    # remove excessive beginning and end whitespaces.
    $reply =~ s/^\s+|\s+$//g;

    if ( $reply =~ /^\s+$/ ) {
        &DEBUG("Reply: Null factoid ($message)");
        return '';
    }

    return $reply unless ( $reply =~ /\$/ );

    ###
    ### $ SUBSTITUTION.
    ###

    # don't evaluate if it has factoid arguments.
    #    if ($message =~ /^cmd:/i) {
    #	&status("Reply: not doing substVars (eval dollar vars)");
    #    } else {
    $reply = &substVars( $reply, 1 );

    #    }

    $reply;
}

sub smart_replace {
    my ($string) = @_;
    my ( $l, $r ) = ( 0, 0 );    # l = left,  r = right.
    my ( $s, $t ) = ( 0, 0 );    # s = start, t = marker.
    my $i   = 0;
    my $old = $string;
    my @rand;

    foreach ( split //, $string ) {

        if ( $_ eq "(" ) {
            if ( !$l and !$r ) {
                $s = $i;
                $t = $i;
            }

            $l++;
            $r--;
        }

        if ( $_ eq ")" ) {
            $r++;
            $l--;

            if ( !$l and !$r ) {
                my $substr = substr( $old, $s, $i - $s + 1 );
                push( @rand, substr( $old, $t + 1, $i - $t - 1 ) );

                my $rand = $rand[ rand @rand ];

                #		&status("SARing '$substr' to '$rand'.");
                $string =~ s/\Q$substr\E/$rand/;
                undef @rand;
            }
        }

        if ( $_ eq "|" and $l + $r == 0 and $l == 1 ) {
            push( @rand, substr( $old, $t + 1, $i - $t - 1 ) );
            $t = $i;
        }

        $i++;
    }

    if ( $old eq $string ) {
        &WARN("smart_replace: no subst made. (string => $string)");
    }

    return $string;
}

sub SARit {
    my ($txt) = @_;
    my $done = 0;

    # (blah1|blah2)?
    while ( $txt =~ /\((.*?)\)\?/ ) {
        my $str = $1;
        if ( rand() > 0.5 ) {    # fix.
            &status("Factoid transform: keeping '$str'.");
            $txt =~ s/\(\Q$str\E\)\?/$str/;
        }
        else {                   # remove
            &status("Factoid transform: removing '$str'.");
            $txt =~ s/\(\Q$str\E\)\?\s?//;
        }
        $done++;
        last if ( $done >= 10 );    # just in case.
    }
    $done = 0;

    # EG: (0-32768) => 6325
    ### TODO: (1-10,20-30,40) => 24
    while ( $txt =~ /\((\d+)-(\d+)\)/ ) {
        my ( $lower, $upper ) = ( $1, $2 );
        my $new = int( rand $upper - $lower ) + $lower;

        &status("SARing '$&' to '$new' (2).");
        $txt =~ s/$&/$new/;
        $done++;
        last if ( $done >= 10 );    # just in case.
    }
    $done = 0;

    # EG: (blah1|blah2|blah3|) => blah1
    while ( $txt =~ /.*\((.*\|.*?)\).*/ ) {
        $txt = &smart_replace($txt);

        $done++;
        last if ( $done >= 10 );    # just in case.
    }
    &status("Reply.pl: $done SARs done.") if ($done);

    # <URL></URL> type
    #
    while ( $txt =~ /<URL>(.*)<\/URL>/ ) {
        &status("we have to norm this <URL></URL> stuff, SARing");
        my $foobar = $1;
        if ( $foobar =~ m/(http:\/\/[^?]+)\?(.*)/ ) {
            my ( $pig1, $pig2 ) = ( $1, $2 );
            &status("SARing using URLencode");
            $pig2 =~ s/([^\w])/sprintf("%%%02x",ord($1))/gie;
            $foobar = $pig1 . "?" . $pig2;
        }
        $txt =~ s/<URL>(.*)<\/URL>/$foobar/;
    }
    return $txt;
}

sub substVars {
    my ( $reply, $flag ) = @_;

    # $date, $time, $day.
    # TODO: support localtime.
    my $date = strftime( "%Y.%m.%d", gmtime() );
    $reply =~ s/\$date/$date/gi;
    my $time = strftime( "%k:%M:%S", gmtime() );
    $reply =~ s/\$time/$time/gi;
    my $day = strftime( "%A", gmtime() );
    $reply =~ s/\$day/$day/gi;

    # support $ident when I have multiple nicks
    my $mynick = $conn->nick() if $conn;

    # dollar variables.
    if ($flag) {
        $reply =~ s/\$nick/$who/g;
        $reply =~ s/\$who/$who/g;    # backward compat.
    }

    if ( $reply =~ /\$(user(name)?|host)/ ) {
        my ( $username, $hostname ) = split /\@/, $uh;
        $reply =~ s/\$user(name)?/$username/g;
        $reply =~ s/\$host(name)?/$hostname/g;
    }
    $reply =~ s/\$chan(nel)?/$talkchannel/g;
    if ( $msgType =~ /public/ ) {
        $reply =~ s/\$lastspeaker/$lastWho{$talkchannel}/g;
    }
    else {
        $reply =~ s/\$lastspeaker/$lastWho/g;
    }

    if ( $reply =~ /\$rand/ ) {
        my $rand = rand();

        # $randnick.
        if ( $reply =~ /\$randnick/ ) {
            my @nicks    = keys %{ $channels{$chan}{''} };
            my $randnick = $nicks[ int( $rand * $#nicks ) ];
            $reply =~ s/\$randnick/$randnick/g;
        }

        # eg: $rand100.3
        if ( $reply =~ /\$rand(\d+)(\.(\d+))?/ ) {
            my $max  = $1;
            my $dot  = $3 || 0;
            my $orig = $&;

            #&DEBUG("dot => $dot, max => $max, rand=>$rand");
            $rand = sprintf( "%.*f", $dot, $rand * $max );

            &DEBUG("swapping $orig to $rand");
            $reply =~ s/\Q$orig\E/$rand/eg;
        }
        else {
            $reply =~ s/\$rand/$rand/g;
        }
    }

    $reply =~ s/\$ident/$mynick/g;

    if ( $reply =~ /\$startTime/ ) {
        my $time = scalar( gmtime $^T );
        $reply =~ s/\$startTime/$time/;
    }

    if ( $reply =~ /\$uptime/ ) {
        my $uptime = &Time2String( time() - $^T );
        $reply =~ s/\$uptime/$uptime/;
    }

    if ( $reply =~ /\$factoids/ ) {
        my $factoids = &countKeys('factoids');
        $reply =~ s/\$factoids/$factoids/;
    }

    if ( $reply =~ /\$Fupdate/ ) {
        my $x =
          "\002$count{'Update'}\002 "
          . &fixPlural( 'modification', $count{'Update'} );
        $reply =~ s/\$Fupdate/$x/;
    }

    if ( $reply =~ /\$Fquestion/ ) {
        my $x =
          "\002$count{'Question'}\002 "
          . &fixPlural( 'question', $count{'Question'} );
        $reply =~ s/\$Fquestion/$x/;
    }

    if ( $reply =~ /\$Fdunno/ ) {
        my $x =
          "\002$count{'Dunno'}\002 " . &fixPlural( 'dunno', $count{'Dunno'} );
        $reply =~ s/\$Fdunno/$x/;
    }

    $reply =~ s/\$memusage/$memusage/;

    return $reply;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
