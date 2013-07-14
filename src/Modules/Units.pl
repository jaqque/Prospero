#   Units.pl: convert units of measurement
#     Author: M-J. Dominus (mjd-perl-units-id-iut+buobvys+@plover.com)
#    License: GPL, Copyright (C) 1996,1999
#       NOTE: Integrated into infobot by xk.

package Units;

use strict;

sub convertUnits {
    my ( $from, $to ) = @_;

    if ( $from =~ /([+-]?[\d\.]+(?:e[+-]?[\d]+)?)\s+(temp[CFK])/ ) {
        $from = qq|${2}(${1})|;
    }

    my $units = new IO::File;
    open $units, '-|', 'units', $from, $to
      or &::DEBUG("Unable to run units: $!")
      and return;
    my $response = readline($units);
    if (   $response =~ /\s+\*\s+([+-]?[\d\.]+(?:e[+-]?[\d]+)?)/
        or $response =~ /\t([+-]?[\d\.]+(?:e[+-]?[\d]+)?)/ )
    {
        &::performStrictReply(
            sprintf( "$from is approximately \002%.6g\002 $to", $1 ) );
    }
    else {
        &::performStrictReply("$from cannot be converted to ${to}: $response");
    }
    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
