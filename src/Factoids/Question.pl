###
### Question.pl: Kevin Lenzo  (c) 1997
###

##  doQuestion --
##	if ($query == query) {
##		return $value;
##	} else {
##		return NULL;
##	}
##
##

# use strict;	# TODO

use vars qw($query $reply $finalQMark $nuh $result $talkok $who $nuh);
use vars qw(%bots %forked);

sub doQuestion {

    # my doesn't allow variables to be inherinted, local does.
    # following is used in math()...
    local ($query) = @_;
    local ($reply) = '';
    local $finalQMark = $query =~ s/\?+\s*$//;
    $query =~ s/^\s+|\s+$//g;

    if ( !defined $query or $query =~ /^\s*$/ ) {
        return '';
    }

    my $questionWord = '';

    if ( !$addressed ) {
        return '' unless ($finalQMark);
        return ''
          if (
            length $query <
            &::getChanConfDefault( 'minVolunteerLength', 2, $chan ) or
            $param{'addressing'} =~ m/require/i );
        return ''
          if (
            length $query >
            &::getChanConfDefault( 'maxVolunteerLength', 512, $chan ) or
            $param{'addressing'} =~ m/require/i );
    }
    else {
        ### TODO: this should be caught in Process.pl?
        return '' unless ($talkok);

        # there is no flag to disable/enable asking factoids...
        # so it was added... thanks zyxep! :)
        if ( &IsFlag('a') ne 'a' && &IsFlag('o') ne 'o' ) {
            &status("$who tried to ask us when not allowed.");
            return;
        }
    }

    # dangerous; common preambles should be stripped before here
    if ( $query =~ /^forget /i or $query =~ /^no, / ) {
        return if ( exists $bots{$nuh} );
    }

    if ( $query =~ s/^literal\s+//i ) {
        &status("literal ask of '$query'.");
        $literal = 1;
    }

    # convert to canonical reference form
    my $x;
    my @query;

    push( @query, $query );    # 1: push original.

    # valid factoid.
    if ( $query =~ s/[!.]$// ) {
        push( @query, $query );
    }

    $x = &normquery($query);
    push( @query, $x ) if ( $x ne $query );
    $query = $x;

    $x = &switchPerson($query);
    push( @query, $x ) if ( $x ne $query );
    $query = $x;

    $query =~ s/\s+at\s*(\?*)$/$1/;       # where is x at?
    $query =~ s/^explain\s*(\?*)/$1/i;    # explain x
    $query = " $query ";                  # side whitespaces.

    my $qregex = join '|', keys %{ $lang{'qWord'} };

    # purge prefix question string.
    if ( $query =~ s/^ ($qregex)//i ) {
        $questionWord = lc($1);
    }

    if ( $questionWord eq '' and $finalQMark and $addressed ) {
        $questionWord = 'where';
    }
    $query =~ s/^\s+|\s+$//g;             # bleh. hacked.
    push( @query, $query ) if ( $query ne $x );

    if ( &IsChanConf('factoidArguments') > 0 ) {
        $result = &factoidArgs( $query[0] );

        return $result if ( defined $result );
    }

    my @link;
    for ( my $i = 0 ; $i < scalar @query ; $i++ ) {
        $query  = $query[$i];
        $result = &getReply($query);
        next if ( !defined $result or $result eq '' );

        # 'see also' factoid redirection support.

        while ( $result =~ /^see( also)? (.*?)\.?$/ ) {
            my $link = $2;

            # #debian@OPN was having problems with libstdc++ factoid
            # redirection :) 20021116. -xk.
            # hrm... allow recursive loops... next if statement handles
            # that.
            if ( grep /^\Q$link\E$/i, @link ) {
                &status("recursive link found; bailing out.");
                last;
            }

            if ( scalar @link >= 5 ) {
                &status("recursive link limit (5) reached.");
                last;
            }

            push( @link, $link );
            my $newr = &getReply($link);

            # no such factoid. try commands
            if ( !defined $newr || $newr =~ /^0?$/ ) {

                # support command redirection.
                # recursive cmdHooks aswell :)
                my $done = 0;
                $done++ if &parseCmdHook($link);
                $message = $link;
                $done++ unless ( &Modules() );

                return;
            }
            last if ( !defined $newr or $newr eq '' );
            $result = $newr;
        }

        if (@link) {
            &status( "'$query' linked to: " . join( " => ", @link ) );
        }

        if ( $i != 0 ) {
            &VERB(
                "Question.pl: '$query[0]' did not exist; '$query[$i]' ($i) did",
                2
            );
        }

        return $result;
    }

    ### TODO: Use &Forker(); move function to Debian.pl
    if ( &IsChanConf('debianForFactoid') > 0 ) {
        &loadMyModule('Debian');
        $result = &Debian::DebianFind($query);    # ???
        ### TODO: debian module should tell, through shm, that it went
        ###	  ok or not.
###	return $result if (defined $result);
    }

    if ( $questionWord ne '' or $finalQMark ) {

        # if it has not been explicitly marked as a question
        if ( $addressed and $reply eq '' ) {
            &status( "notfound: <$who> " . join( ' :: ', @query ) )
              if ($finalQMark);

            return '' unless ( &IsParam('friendlyBots') );

            foreach ( split /\s+/, $param{'friendlyBots'} ) {
                &msg( $_, ":INFOBOT:QUERY <$who> $query" );
            }
        }
    }

    return $reply;
}

sub factoidArgs {
    my ($str) = @_;
    my $result;

    # to make it eleeter, split each arg and use "blah OR blah or BLAH"
    # which will make it less than linear => quicker!
    # TODO: cache this, update cache when altered. !!! !!! !!!
    #    my $t = &timeget();
    my ($first) = split( /\s+/, $str );

    # ignore split to commands [dumb commands vs. factoids] (editing commands?)
    return undef if $str =~ /\s+\=\~\s+s[\#\/\:]/;
    my @list =
      &searchTable( 'factoids', 'factoid_key', 'factoid_key', "^cmd: $first " );

    #    my $delta_time = &timedelta($t);
    #    &DEBUG("factArgs: delta_time = $delta_time s");
    #    &DEBUG("factArgs: list => ".scalar(@list) );

    # from a design perspective, it's better to have the regex in
    # the factoid key to reduce repetitive processing.

    # it does not matter if it's not alphabetically sorted.
    foreach ( sort { length($b) <=> length($a) } @list ) {
        next if (/#DEL#/);    # deleted.

        s/^cmd: //i;

        #	&DEBUG("factarg: '$str' =~ /^$_\$/");
        my $arg = $_;

        # eval (evil!) code. cleaned up courtesy of lear.
        my @vals;
        eval { @vals = ( $str =~ /^$arg$/i ); };

        if ($@) {
            &WARN("factargs: regex failed! '$str' =~ /^$_\$/");
            next;
        }

        next unless (@vals);

        if ( defined $result ) {
            &WARN("factargs: '$_' matches aswell.");
            next;
        }

        #	&DEBUG("vals => @vals");

        &status("Question: factoid Arguments for '$str'");

        # TODO: use getReply() - need to modify it :(
        my $i = 0;
        my $q = "cmd: $_";
        my $r = &getFactoid($q);
        if ( !defined $r ) {
            &DEBUG("question: !result... should this happen?");
            return;
        }

        # update stats. old mysql/sqlite don't do +1
        my ($count) =
          &sqlSelect( 'factoids', 'requested_count', { factoid_key => $q } );
        $count++;
        &sqlSet(
            'factoids',
            { 'factoid_key' => $q },
            {
                requested_by    => $nuh,
                requested_time  => time(),
                requested_count => $count
            }
        );

        # end of update stats.

        $result = $r;

        $result =~ s/^\((.*?)\): //;
        my $vars = $1;

        # start nasty hack to get partial &getReply() functionality.
        $result = &SARit($result);

        foreach ( split( ',', $vars ) ) {
            my $val = $vals[$i];

            #	    &DEBUG("val => $val");

            if ( !defined $val ) {
                &status(
                    "factArgs: vals[$i] == undef; not SARing '$_' for '$str'");
                next;
            }

            my $done = 0;
            my $old  = $result;
            while (1) {

                #		&DEBUG("Q: result => $result (1before)");
                $result = &substVars( $result, 1 );

                #		&DEBUG("Q: result => $result (1after)");

                last if ( $old eq $result );
                $old = $result;
                $done++;
            }

            # hack.
            $vals[$i] =~ s/^me$/$who/gi;

            #	    if (!$done) {
            &status("factArgs: SARing '$_' to '$vals[$i]'.");
            $result =~ s/\Q$_\E/$vals[$i]/g;

            #	    }
            $i++;
        }

        # rest of nasty hack to get partial &getReply() functionality.
        $result =~ s/^\s*<action>\s*(.*)/\cAACTION $1\cA/i;
        $result =~ s/^\s*<reply>\s*//i;

        # well... lets go through all of them. not advisable if we have like
        # 1000 commands, heh.
        #	return $result;
        $cmdstats{'Factoid Commands'}++;
    }

    return $result;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
