###
### Statement.pl: Kevin Lenzo  (c) 1997
###

##
##  doStatement --
##
##	decide if $in is a statement, and if so,
##		- update the db
##		- return feedback statement
##
##	otherwise return
##		- null for confused.
##

# use strict;	# TODO

sub doStatement {
    my ($in) = @_;

    $in =~ s/\\(\S+)/\#$1\#/g;    # fix the backslash.
    $in =~ s/^no([, ]+)//i;       # 'no, '.

    # check if we need to be addressed and if we are
    return unless ($learnok);

    my ($urlType) = '';

    # prefix www with http:// and ftp with ftp://
    $in =~ s/ www\./ http:\/\/www\./ig;
    $in =~ s/ ftp\./ ftp:\/\/ftp\./ig;

    $urlType = 'about'   if ( $in =~ /\babout:/i );
    $urlType = 'afp'     if ( $in =~ /\bafp:/ );
    $urlType = 'file'    if ( $in =~ /\bfile:/ );
    $urlType = 'palace'  if ( $in =~ /\bpalace:/ );
    $urlType = 'phoneto' if ( $in =~ /\bphone(to)?:/ );
    if ( $in =~ /\b(news|http|ftp|gopher|telnet):\s*\/\/[\-\w]+(\.[\-\w]+)+/ ) {
        $urlType = $1;
    }

    # acceptUrl.
    if ( &IsParam('acceptUrl') ) {
        if ( $param{'acceptUrl'} eq 'REQUIRE' ) {    # require url type.
            return if ( $urlType eq '' );
        }
        elsif ( $param{'acceptUrl'} eq 'REJECT' ) {
            &status("REJECTED URL entry") if ( &IsParam('VERBOSITY') );
            return unless ( $urlType eq '' );
        }
        else {

            # OPTIONAL
        }
    }

    # learn statement. '$lhs is|are $rhs'
    if ( $in =~ /(^|\s)(is|are)(\s|$)/i ) {
        my ( $lhs, $mhs, $rhs ) = ( $`, $&, $' );

        # Quit if they are over the limits. Check done here since Core.pl calls
        # this mid sub and Question.pl needs its own check as well. NOTE: $in is
        # used in this place since lhs and rhs are really undefined for unwanted
        # teaching. Mainly, the "is" could be anywhere within a 510 byte or so
        # block of text, so the total size was choosen since the sole purpose of
        # this logic is to not hammer the db with pointless factoids that were
        # only meant to be general conversation.
        return ''
          if (
            length $in <
            &::getChanConfDefault( 'minVolunteerLength', 2, $chan ) or
            $param{'addressing'} =~ m/require/i ) and not $addressed;
        return ''
          if (
            length $in >
            &::getChanConfDefault( 'maxVolunteerLength', 512, $chan ) or
            $param{'addressing'} =~ m/require/i ) and not $addressed;

        # allows factoid arguments to be updated. -lear.
        $lhs =~ s/^(cmd: )?(.*)/$1||'' . lc $2/e;

        # discard article.
        $lhs =~ s/^(the|da|an?)\s+//i;

        # remove excessive initial and final whitespaces.
        $lhs =~ s/^\s+|\s+$//g;
        $mhs =~ s/^\s+|\s+$//g;
        $rhs =~ s/^\s+|\s+$//g;

        # break if either lhs or rhs is NULL.
        if ( $lhs eq '' or $rhs eq '' ) {
            return "NOT-A-STATEMENT";
        }

        # lets check if it failed.
        if ( &validFactoid( $lhs, $rhs ) == 0 ) {
            if ($addressed) {
                &status("IGNORE statement: <$who> $message");
                &performReply( &getRandom( keys %{ $lang{'confused'} } ) );
            }
            return;
        }

        # uncomment to prevent HUNGRY learning of rhs with whitespace
        #return if (!$addressed and $lhs =~ /\s+/);
        &::DEBUG("doStatement: $in:$lhs:$mhs:$rhs");

        &status("statement: <$who> $message");

        # change "#*#" back to '*' because of '\' sar to '#blah#'.
        $lhs =~ s/\#(\S+)\#/$1/g;
        $rhs =~ s/\#(\S+)\#/$1/g;

        $lhs =~ s/\?+\s*$//;    # strip off '?'.

        # verify the update statement whether there are any weird
        # characters.
        ### this can be simplified.
        foreach ( split //, $lhs . $rhs ) {
            my $ord = ord $_;
            if ( $ord > 170 and $ord < 220 ) {
                &status("statement: illegal character '$_' $ord.");
                &performAddressedReply(
                    "i'm not going to learn illegal characters");
                return;
            }
        }

        # success.
        return if ( &update( $lhs, $mhs, $rhs ) );
    }

    return 'CONTINUE';
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
