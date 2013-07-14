#
#     Rss.pl: rss handler hacked from Plug.pl
#     Author: Tim Riker <Tim@Rikers.org>
#  Licensing: Artistic License (as perl itself)
#    Version: v0.1
#

package Rss;

use strict;

sub Rss::Titles {
    return join( ' ', @_ ) =~ m/<title>\s*(.*?)\s*<\/title>/gi;
}

sub Rss::Rss {
    my ($message) = @_;
    my @results   = &::getURL($message);
    my $retval    = "i could not get the rss feed.";

    my @list = &Rss::Titles(@results) if ( scalar @results );
    $retval = &::formListReply( 0, 'Titles: ', @list ) if ( scalar @list );

    &::performStrictReply($retval);
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
