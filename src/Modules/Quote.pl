#
#  Quote.pl: retrieve stock quotes from yahoo
#            heavily based on Slashdot.pl
#   Version: v0.1
#    Author: Michael Urman <mu@zen.dhis.org>
# Licensing: Artistic
# changes from Morten Brix Pedersen (mbrix) and Tim Riker <Tim@Rikers.org>
#

package Quote;

use strict;

sub commify {
    my $input = shift;
    $input = reverse $input;
    $input =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $input;
}

sub Quote {
    my $stock = shift;
    my @results =
      &::getURL( 'http://quote.yahoo.com/d/quotes.csv'
          . "?s=$stock&f=sl1d1t1c1ohgv&e=.csv" );

    if ( !scalar @results ) {
        &::msg( $::who, "i could not get a stock quote :(" );
    }

    my ($reply);
    foreach my $result (@results) {

        # get rid of the quotes
        $result =~ s/\"//g;

        my (
            $ticker, $recent, $date, $time, $change,
            $open,   $high,   $low,  $volume
        ) = split( ',', $result );

        # add some commas
        # "+ 0" removes trailing cr/lf/etc.
        my $newvol = commify( $volume + 0 );

        $reply .= ' ;; ' if $reply;
        $reply .=
            "$ticker: $recent ($high/$low), $date $time, "
          . "Opened $open, Volume $newvol, Change $change";
    }

    if ( $reply eq '' ) {
        $reply = "i couldn't get the quote for $stock. sorry. :(";
    }

    &::performStrictReply($reply);
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
