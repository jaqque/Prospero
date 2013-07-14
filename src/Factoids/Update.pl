#
# Update.pl: Add or modify factoids in the db.
#    Author: Kevin Lenzo
#	     dms
#   Version: 19991209
#   Created: 1997
#

# use strict;	# TODO

sub update {
    my ( $lhs, $mhs, $rhs ) = @_;

    for ($lhs) {
        s/^i (heard|think) //i;
        s/^some(one|1|body) said //i;
        s/\s+/ /g;
    }

    # locked.
    return if ( &IsLocked($lhs) == 1 );

    # profanity.
    if ( &IsParam('profanityCheck') and &hasProfanity($rhs) ) {
        &performReply("please, watch your language.");
        return 1;
    }

    # teaching.
    if ( &IsFlag('t') ne 't' && &IsFlag('o') ne 'o' ) {
        &msg( $who, "permission denied." );
        &status("alert: $who wanted to teach me.");
        return 1;
    }

    # invalid verb.
    if ( $mhs !~ /^(is|are)$/i ) {
        &ERROR("UNKNOWN verb: $mhs.");
        return;
    }

    # check if the arguments are too long to be stored in our table.
    my $toolong = 0;
    $toolong++ if ( length $lhs > $param{'maxKeySize'} );
    $toolong++ if ( length $rhs > $param{'maxDataSize'} );
    if ($toolong) {
        &performAddressedReply("that's too long");
        return 1;
    }

    # also checking.
    my $also = ( $rhs =~ s/^-?also //i );
    my $also_or = ( $also and $rhs =~ s/\s+(or|\|\|)\s+// );

    if ( $also or $also_or ) {
        my $author = &getFactInfo( $from, 'created_by' );
        $author =~ /^(.*)!/;
        my $created_by = $1;

        # Can they even modify factoids?
        if (    &IsFlag('m') ne 'm'
            and &IsFlag('M') ne 'M'
            and &IsFlag('o') ne 'o' )
        {
            &performReply("You do not have permission to modify factoids");
            return 1;

            # If they have +M but they didnt create the factoid
        }
        elsif ( &IsFlag('M') eq 'M'
            and $who !~ /^\Q$created_by\E$/i
            and &IsFlag('m') ne 'm'
            and &IsFlag('o') ne 'o' )
        {
            &performReply("factoid '$lhs' is not yours to modify.");
            return 1;
        }
    }

    # factoid arguments handler.
    # must start with a non-variable
    if ( &IsChanConf('factoidArguments') > 0 and $lhs =~ /^[^\$]+.*\$/ ) {
        &status("Update: Factoid Arguments found.");
        &status("Update: orig lhs => '$lhs'.");
        &status("Update: orig rhs => '$rhs'.");

        my @list;
        my $count = 0;
        $lhs =~ s/^/cmd: /;
        while ( $lhs =~ s/\$(\S+)/(.*?)/ ) {
            push( @list, "\$$1" );
            $count++;
            last if ( $count >= 10 );
        }

        if ( $count >= 10 ) {
            &msg( $who, "error: could not SAR properly." );
            &DEBUG("error: lhs => '$lhs' rhs => '$rhs'.");
            return;
        }

        my $z = join( ',', @list );
        $rhs =~ s/^/($z): /;

        &status("Update: new lhs => '$lhs' rhs => '$rhs'.");
    }

    # the fun begins.
    my $exists = &getFactoid($lhs);

    if ( !$exists ) {

        # nice 'are' hack (or work-around).
        if ( $mhs =~ /^are$/i and $rhs !~ /<\S+>/ ) {
            &status("Update: 'are' hack detected.");
            $mhs = 'is';
            $rhs = "<REPLY> are " . $rhs;
        }

        &status("enter: <$who> \'$lhs\' =$mhs=> \'$rhs\'");
        $count{'Update'}++;

        &performAddressedReply('okay');

        &sqlInsert(
            'factoids',
            {
                created_by    => $nuh,
                created_time  => time(),    # modified time.
                factoid_key   => $lhs,
                factoid_value => $rhs,
            }
        );

        if ( !defined $rhs or $rhs eq '' ) {
            &ERROR("Update: rhs1 == NULL.");
        }

        return 1;
    }

    # factoid exists.
    if ( $exists eq $rhs ) {

        # this catches the following situation: (right or wrong?)
        #    "test is test"
        #    "test is also test"
        &performAddressedReply("i already had it that way");
        return 1;
    }

    if ($also) {    # 'is also'.
        my $redircount = 5;
        my $origlhs    = $lhs;
        while ( $exists =~ /^<REPLY> ?see (.*)/i ) {
            $redircount--;
            unless ($redircount) {
                &msg( $who, "$origlhs has too many levels of redirection." );
                return 1;
            }

            $lhs    = $1;
            $exists = &getFactoid($lhs);
            unless ($exists) {
                &msg( $who, "$1 is a dangling redirection." );
                return 1;
            }
        }
        if ( $exists =~ /^<REPLY> ?see (.*)/i ) {
            &TODO("Update.pl: append to linked factoid.");
        }

        if ($also_or) {    # 'is also ||'.
            $rhs = $exists . ' || ' . $rhs;
        }
        else {

            #	    if ($exists =~ s/\,\s*$/,  /) {
            if ( $exists =~ /\,\s*$/ ) {
                &DEBUG("current has trailing comma, just append as is");
                &DEBUG("Up: exists => $exists");
                &DEBUG("Up: rhs    => $rhs");

                # $rhs =~ s/^\s+//;
                # $rhs = $exists." ".$rhs;	# keep comma.
            }

            if ( $exists =~ /\.\s*$/ ) {
                &DEBUG(
                    "current has trailing period, just append as is with 2 WS");
                &DEBUG("Up: exists => $exists");
                &DEBUG("Up: rhs    => $rhs");

                # $rhs =~ s/^\s+//;
                # use ucfirst();?
                # $rhs = $exists."  ".$rhs;	# keep comma.
            }

            if ( $rhs =~ /^[A-Z]/ ) {
                if ( $rhs =~ /\w+\s*$/ ) {
                    &status("auto insert period to factoid.");
                    $rhs = $exists . ".  " . $rhs;
                }
                else {    # '?' or '.' assumed at end.
                    &status(
"orig factoid already had trailing symbol; not adding period."
                    );
                    $rhs = $exists . "  " . $rhs;
                }
            }
            elsif ( $exists =~ /[\,\.\-]\s*$/ ) {
                &VERB(
"U: current has trailing symbols; inserting whitespace + new.",
                    2
                );
                $rhs = $exists . " " . $rhs;
            }
            elsif ( $rhs =~ /^\./ ) {
                &VERB( "U: new text has ^.; appending directly", 2 );
                $rhs = $exists . $rhs;
            }
            else {
                $rhs = $exists . ', or ' . $rhs;
            }
        }

        # max length check again.
        if ( length $rhs > $param{'maxDataSize'} ) {
            if ( length $rhs > length $exists ) {
                &performAddressedReply("that's too long");
                return 1;
            }
            else {
                &status(
"Update: new length is still longer than maxDataSize but less than before, we'll let it go."
                );
            }
        }

        &performAddressedReply('okay');

        $count{'Update'}++;
        &status("update: <$who> \'$lhs\' =$mhs=> \'$rhs\'; was \'$exists\'");
        &sqlSet(
            'factoids',
            { 'factoid_key' => $lhs },
            {
                modified_by   => $nuh,
                modified_time => time(),
                factoid_value => $rhs,
            }
        );

        if ( !defined $rhs or $rhs eq '' ) {
            &ERROR("Update: rhs1 == NULL.");
        }
    }
    else {    # not 'also'

        if ( !$correction_plausible ) {    # "no, blah is ..."
            if ($addressed) {
                &performStrictReply(
                    "...but \002$lhs\002 is already something else...");
                &status("FAILED update: <$who> \'$lhs\' =$mhs=> \'$rhs\'");
            }
            return 1;
        }

        my $author = &getFactInfo( $lhs, 'created_by' ) || '';

        if (   IsFlag('m') ne 'm'
            && IsFlag('o') ne 'o'
            && $author !~ /^\Q$who\E\!/i )
        {
            &msg( $who, "you can't change that factoid." );
            return 1;
        }

        &performAddressedReply('okay');

        $count{'Update'}++;
        &status("update: <$who> \'$lhs\' =$mhs=> \'$rhs\'; was \'$exists\'");

        &sqlSet(
            'factoids',
            { 'factoid_key' => $lhs },
            {
                modified_by   => $nuh,
                modified_time => time(),
                factoid_value => $rhs,
            }
        );

        if ( !defined $rhs or $rhs eq '' ) {
            &ERROR("Update: rhs1 == NULL.");
        }
    }

    return 1;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
