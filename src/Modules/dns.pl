#
#     dns.pl: host lookups
#     Author: Tim Riker <Tim@Rikers.org>
#     Source: extracted from UserExtra.pl
#  Licensing: Artistic License (as perl itself)
#    Version: v0.1
#
#  Copyright (c) 2005 Tim Riker
#

package dns;

use strict;

sub dns::dns {
    my $dns = shift;
    my ( $match, $x, $y, $result, $pid );

    if ( $dns =~ /(\d+\.\d+\.\d+\.\d+)/ ) {
        use Socket;

        &::status("DNS query by IP address: $dns");

        $y = pack( 'C4', split( /\./, $dns ) );
        $x = ( gethostbyaddr( $y, &AF_INET ) );

        if ( $x !~ /^\s*$/ ) {
            $result = "$dns is $x" unless ( $x =~ /^\s*$/ );
        }
        else {
            $result = "I can't find the address $dns in DNS";
        }

    }
    else {

        &::status("DNS query by name: $dns");
        $x = join( '.', unpack( 'C4', ( gethostbyname($dns) )[4] ) );

        if ( $x !~ /^\s*$/ ) {
            $result = "$dns is $x";
        }
        else {
            $result = "I can't find $dns in DNS";
        }
    }

    return ($result);
}

sub dns::query {
    &::performStrictReply( &dns(@_) );
    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
