#
# infobot copyright (C) kevin lenzo 1997-98
#

use strict;

use vars qw($message);

my %digits = (
    'first', '1', 'second', '2',  'third',   '3', 'fourth', '4',
    'fifth', '5', 'sixth',  '6',  'seventh', '7', 'eighth', '8',
    'ninth', '9', 'tenth',  '10', 'one',     '1', 'two',    '2',
    'three', '3', 'four',   '4',  'five',    '5', 'six',    '6',
    'seven', '7', 'eight',  '8',  'nine',    '9', 'ten',    '10'
);

sub perlMath {
    my ($locMsg) = $message;

    if ( $message =~ /^\s*$/ ) {
        return;
    }

    foreach ( keys %digits ) {
        $locMsg =~ s/$_/$digits{$_}/g;
    }

    while ( $locMsg =~ /(exp ([\w\d]+))/ ) {
        my ( $exp, $val ) = ( $1, exp $2 );
        $locMsg =~ s/$exp/+$val/g;
    }

    while ( $locMsg =~ /(hex2dec\s*([0-9A-Fa-f]+))/ ) {
        my ( $exp, $val ) = ( $1, hex $2 );
        $locMsg =~ s/$exp/+$val/g;
    }

    if ( $locMsg =~ /^\s*(dec2hex\s*(\d+))\s*\?*/ ) {
        my ( $exp, $val ) = ( $1, sprintf( "%x", "$2" ) );
        $locMsg =~ s/$exp/+$val/g;
    }

    my $e = exp(1);
    $locMsg =~ s/\be\b/$e/;

    while ( $locMsg =~ /(log\s*((\d+\.?\d*)|\d*\.?\d+))\s*/ ) {
        my ( $exp, $res ) = ( $1, $2 );
        my $val = ($res) ? log($res) : 'Infinity';
        $locMsg =~ s/$exp/+$val/g;
    }

    while ( $locMsg =~ /(bin2dec ([01]+))/ ) {
        my $exp = $1;
        my $val = join( '', unpack( 'B*', $2 ) );
        $locMsg =~ s/$exp/+$val/g;
    }

    while ( $locMsg =~ /(dec2bin (\d+))/ ) {
        my $exp = $1;
        my $val = join( '', unpack( 'B*', pack( 'N', $2 ) ) );
        $val    =~ s/^0+//;
        $locMsg =~ s/$exp/+$val/g;
    }

    for ($locMsg) {
        s/\bpi\b/3.14159265/g;
        s/ to the / ** /g;
        s/\btimes\b/\*/g;
        s/\bdiv(ided by)? /\/ /g;
        s/\bover /\/ /g;
        s/\bsquared/\*\*2 /g;
        s/\bcubed/\*\*3 /g;
        s/\bto\s+(\d+)(r?st|nd|rd|th)?( power)?/\*\*$1 /ig;
        s/\bpercent of/*0.01*/ig;
        s/\bpercent/*0.01/ig;
        s/\% of\b/*0.01*/g;
        s/\%/*0.01/g;
        s/\bsquare root of (\d+)/$1 ** 0.5 /ig;
        s/\bcubed? root of (\d+)/$1 **(1.0\/3.0) /ig;
        s/ of / * /;
        s/(bit(-| )?)?xor(\'?e?d( with))?/\^/g;
        s/(bit(-| )?)?or(\'?e?d( with))?/\|/g;
        s/bit(-| )?and(\'?e?d( with))?/\& /g;
        s/(plus|and)/+/ig;
    }

    # what the hell is this shit?
    if (   ( $locMsg =~ /^\s*[-\d*+\s()\/^\.\|\&\*\!]+\s*$/ )
        && ( $locMsg !~ /^\s*\(?\d+\.?\d*\)?\s*$/ )
        && ( $locMsg !~ /^\s*$/ )
        && ( $locMsg !~ /^\s*[( )]+\s*$/ )
        && ( $locMsg =~ /\d+/ ) )
    {
        $locMsg =~ s/([0-9]+\.[0-9]+(\.[0-9]+)+)/"$1"/g;
        $locMsg = eval($locMsg);

        if ( defined $locMsg and $locMsg =~ /^[-+\de\.]+$/ ) {
            $locMsg = sprintf( "%1.12f", $locMsg );
            $locMsg =~ s/\.?0+$//;

            if ( length $locMsg > 30 ) {
                $locMsg = "a number with quite a few digits...";
            }
        }
        else {
            if ( defined $locMsg ) {
                &FIXME("math: locMsg => '$locMsg'...");
            }
            else {
                &status("math: could not really compute.");
                $locMsg = '';
            }
        }
    }
    else {
        $locMsg = '';
    }

    if ( defined $locMsg and $locMsg ne $message ) {

        # success.
        return $locMsg;
    }
    else {

        # no match.
        return '';
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
