#
#  hex2ip.pl: Convert hex gateway idents to an IP (eg:ABCDEF12)
#     Author: Dan McGrath <djmcgrath@users.sourceforget.net>
#  Licensing: Artistic License (as perl itself)
#    Version: v0.1
#
#  Copyright (c) 2007 Dan McGrath
#

package hex2ip;

use strict;

sub hex2ip::convert {
    my $hexstr = shift;
    my $result;

    &::VERB("hex2ip: Converting Hex address $hexstr to IP");

    if ( $hexstr =~ /^([a-fA-F0-9]{2}){4}$/ ) {
        my @conv;
        $hexstr =~ /(..)(..)(..)(..)/;

        push @conv, hex($1);
        push @conv, hex($2);
        push @conv, hex($3);
        push @conv, hex($4);

        $result = uc "$hexstr = " . join( ".", @conv );
    }
    else {
        $result = "Invalid string: $hexstr";
    }

    return ($result);
}

sub hex2ip::query {
    &::performStrictReply( &convert(@_) );
    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
