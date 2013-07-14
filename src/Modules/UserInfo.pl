#
# UserInfo.pl: User Information Services
#      Author: dms
#     Version: v0.1 (20000509).
#     Created: 20000509
#	 NOTE: Idea from Flugh. Originally written in tcl for eggdrop by
#		unknown.
#

use strict;

my $orderOfInfo = 'RN,J,C,W,D';
my %infoDesc    = (
    'RN' => 'Real Name',
    'J'  => 'Occupation',
    'C'  => 'Contact',
    'W'  => 'URL',
    'D'  => 'Description',
);

sub UserInfo2Hash {
    my ($text) = @_;
    my %hash;

    foreach ( split /\|/, $text ) {
        if (/^\s*(\S+):\s*(.*)\s*$/) {
            $hash{$1} = $2;
        }
    }

    return %hash;
}

sub Hash2UserInfo {
    my (%hash) = @_;
    my @array;

    foreach ( sort keys %hash ) {
        push( @array, "$_: $hash{$_}" );
    }

    join( '|', @array );
}

###
###
###

sub UserInfoGet {
    my ($query) = @_;
    $query =~ s/^\s+|\s+$//g if ( defined $query );

    if ( !defined $query or $query =~ /^$/ ) {
        &help('userinfo');
        return;
    }

    if ( $query !~ /^$mask{nick}$/ ) {
        &msg( $who, "Invalid query of '$query'." );
        return;
    }

    my $result;
    if ( $result = &getFactoid( $query . ' info' ) ) {

        # good.
    }
    else {    # bad.
        &performReply("No User Information on \002$query\002");
        return;
    }

    if ( $result !~ /\|/ ) {
        &msg( $who, "Invalid User Information for '$query'." );
        return;
    }

    my %userInfo = &UserInfo2Hash($result);

    my @reply;
    foreach ( split ',', $orderOfInfo ) {
        next unless ( exists $userInfo{$_} );
        push( @reply, "$infoDesc{$_}: $userInfo{$_}" );
    }

    &performStrictReply(
        "User Information on $userInfo{'N'} -- " . join( ', ', @reply ) );
}

sub UserInfoSet {
    my ( $type, $what ) = @_;
    my %userInfo;
    my $info;

    if ( &IsLocked("$who info") ) {
        &DEBUG("UIS: IsLocked('$who info') == 1.");
        return;
    }

    my $new = 0;
    if ( my $result = &getFactoid("$who info") ) {
        %userInfo = &UserInfo2Hash($result);
    }
    else {
        &DEBUG("UIS: new = 1!");
        $userInfo{'N'} = $who;
        $new = 1;
    }

    ### TODO: hash for %infoS2L.
    if ( $type =~ /^(RN|real\s*name)$/i ) {
        $info = 'RN';
    }
    elsif ( $type =~ /^(J|job|occupation|school|life)$/i ) {
        $info = 'J';
    }
    elsif ( $type =~ /^(C|contact|email|phone)$/i ) {
        $info = 'C';
    }
    elsif ( $type =~ /^(W|www|url|web\s*page|home\s*page)$/i ) {
        $info = 'W';
    }
    elsif ( $type =~ /^(D|desc\S+)$/i ) {
        $info = 'D';
    }
    elsif ( $type =~ /^(O|opt\S+)$/i ) {
        $info = 'O';
    }
    else {
        &msg( $who, "Unknown type '$type'." );
        return;
    }

    if ( !defined $what ) {    # !defined.
        if ( exists $userInfo{$info} ) {
            &msg( $who,
                "Current \002$infoDesc{$info}\002 is: '$userInfo{$info}'." );
        }
        else {
            &msg( $who, "No current \002$infoDesc{$info}\002." );
        }

        my @remain;
        foreach ( split ',', $orderOfInfo ) {
            next if ( exists $userInfo{$_} );
            push( @remain, $infoDesc{$_} );
        }
        if ( scalar @remain ) {
            ### TODO: show short-cut (identifier) aswell.
            &msg( $who, "Remaining slots to fill: " . join( ' ', @remain ) );
        }
        else {
###	    &msg($who, "Personal Information completely filled. Good.");
        }

        return;
    }
    elsif ( $what =~ /^$/ ) {    # defined but NULL. UNSET
        if ( exists $userInfo{$info} ) {
            &msg( $who,
                "Unsetting \002$infoDesc{$info}\002 ($userInfo{$info})." );
            delete $userInfo{$info};
        }
        else {
            &msg( $who, "\002$infoDesc{$info}\002 is already empty!" );
            return;
        }
    }
    else {                       # defined.
        if ( exists $userInfo{$info} ) {
            &msg( $who, "\002$infoDesc{$info}\002 was '$userInfo{$info}'." );
            &msg( $who, "Now is: '$what'." );
        }
        else {
            &msg( $who, "\002$infoDesc{$info}\002 is now '$what'." );
        }
        $userInfo{$info} = $what;
    }

    &setFactInfo( $who . ' info', 'factoid_value', &Hash2UserInfo(%userInfo) );
    if ($new) {
        &DEBUG("UIS: locking '$who info'.");
        &DEBUG("UIS: nuh => '$nuh'.");
        &setFactInfo( "$who info", "locked_by",   $nuh );
        &setFactInfo( "$who info", "locked_time", time() );
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
