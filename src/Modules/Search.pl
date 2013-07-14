#
# infobot copyright kevin lenzo 1997-1998
# rewritten by xk 1999
#

package Search;

use strict;

###
# Search(keys||vals, str);
sub Search {
    my ( $type, $str ) = @_;
    my $start_time = &::timeget();
    my @list;
    my $maxshow = &::getChanConfDefault( 'maxListReplyCount', 15, $::chan );

    $type =~ s/s$//;    # nice work-around.

    if ( $type eq 'value' ) {

        # search by value.
        @list =
          &::searchTable( 'factoids', 'factoid_key', 'factoid_value', $str );
    }
    else {

        # search by key.
        @list =
          &::searchTable( 'factoids', 'factoid_key', 'factoid_key', $str );
    }

    @list = grep( !/\#DEL\#$/, @list ) if ( scalar(@list) > $maxshow );
    my $delta_time = sprintf( "%.02f", &::timedelta($start_time) );
    &::status("search: took $delta_time sec for query.") if ( $delta_time > 0 );

    my $prefix = "Factoid search of '\002$str\002' by $type ";

    &::performStrictReply( &::formListReply( 1, $prefix, @list ) );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
