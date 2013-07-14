#
#  DBStubs.pl: DB independent (I hope, heh) factoid support
#      Author: dms
#     Version: v0.6d (20000223)
#     Created: 19991020
#

# use strict;	# TODO

#####
# Usage: &setFactInfo($faqtoid, $key, $val);
sub setFactInfo {
    &sqlSet( 'factoids', { factoid_key => $_[0] }, { $_[1] => $_[2] } );
}

#####
# Usage: &getFactInfo($faqtoid, [$what]);
sub getFactInfo {
    return &sqlSelect( 'factoids', $_[1], { factoid_key => $_[0] } );
}

#####
# Usage: &getFactoid($faqtoid);
sub getFactoid {
    return &getFactInfo( $_[0], 'factoid_value' );
}

#####
# Usage: &delFactoid($faqtoid);
sub delFactoid {
    my ($faqtoid) = @_;

    &sqlDelete( 'factoids', { factoid_key => $faqtoid } );
    &status("DELETED $faqtoid");

    return 1;
}

#####
# Usage: &IsLocked($faqtoid);
sub IsLocked {
    my ($faqtoid) = @_;
    my $thisnuh = &getFactInfo( $faqtoid, 'locked_by' );

    if ( defined $thisnuh and $thisnuh ne '' ) {
        if ( !&IsHostMatch($thisnuh) and &IsFlag('o') ne 'o' ) {
            &performReply("cannot alter locked factoids");
            return 1;
        }
    }

    return 0;
}

#####
# Usage: &AddModified($faqtoid,$nuh);
sub AddModified {
    my ( $faqtoid, $nuh ) = @_;
    my $modified_by = &getFactInfo( $faqtoid, 'modified_by' );
    my ( @modifiedlist, @modified, %modified );

    if ( defined $modified_by ) {
        push( @modifiedlist, split( /\,/, $modified_by ) );
    }
    push( @modifiedlist, $nuh );

    foreach ( reverse @modifiedlist ) {
        /^(\S+)!(\S+)@(\S+)$/;
        my $nick = lc $1;
        next if ( exists $modified{$nick} );

        $modified{$nick} = $_;
        push( @modified, $nick );
    }

    undef @modifiedlist;

    foreach ( reverse @modified ) {
        push( @modifiedlist, $modified{$_} );
    }
    shift(@modifiedlist) while ( scalar @modifiedlist > 3 );

    &setFactInfo( $faqtoid, 'modified_by', join( ",", @modifiedlist ) );
    &setFactInfo( $faqtoid, 'modified_time', time() );

    return 1;
}

#####
### Commands which use the fundamental functions... Helpers?
#####

#####
# Usage: &CmdLock($function,$faqtoid);
sub CmdLock {
    my ($faqtoid) = @_;

    my $thisnuh = &getFactInfo( $faqtoid, 'locked_by' );

    if ( defined $thisnuh and $thisnuh ne '' ) {
        my $locked_by = ( split( /\!/, $thisnuh ) )[0];
        &msg( $who,
            "factoid \002$faqtoid\002 has already been locked by $locked_by." );
        return 0;
    }

    $thisnuh ||= &getFactInfo( $faqtoid, 'created_by' );

    # fixes bug found on 19991103.
    # code needs to be reorganised though.
    if ( $thisnuh ne '' ) {
        if ( !&IsHostMatch($thisnuh) && IsFlag('o') ne 'o' ) {
            &msg( $who, "sorry, you are not allowed to lock '$faqtoid'." );
            return 0;
        }
    }

    &performReply("locking factoid \002$faqtoid\002");
    &setFactInfo( $faqtoid, 'locked_by',   $nuh );
    &setFactInfo( $faqtoid, 'locked_time', time() );

    return 1;
}

#####
# Usage: &CmdUnLock($faqtoid);
sub CmdUnLock {
    my ($faqtoid) = @_;

    my $thisnuh = &getFactInfo( $faqtoid, 'locked_by' );

    if ( !defined $thisnuh ) {
        &msg( $who, "factoid \002$faqtoid\002 is not locked." );
        return 0;
    }

    if ( $thisnuh ne '' and !&IsHostMatch($thisnuh) and &IsFlag('o') ne 'o' ) {
        &msg( $who,
            "sorry, you are not allowed to unlock factoid '$faqtoid'." );
        return 0;
    }

    &performReply("unlocking factoid \002$faqtoid\002");
    &setFactInfo( $faqtoid, 'locked_by',   '' );
    &setFactInfo( $faqtoid, 'locked_time', '0' )
      ;    # pgsql complains if NOT NULL set. So set 0 which is the default

    return 1;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
