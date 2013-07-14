# turns english text into piglatin
# Copyright (c) 2005 Tim Riker <Tim@Rikers.org>

use strict;
use warnings;

package piglatin;

sub piglatin {
    my ($text) = @_;
    my $piglatin;
    my $suffix = 'ay';

    # FIXME: does not handle:
    #  non-trailing punctuation and hyphens
    #  y as vowel 'style' -> 'ylestay'
    #  contractions
    for my $word ( split /\s+/, $text ) {
        my ( $pigword, $postfix );

        #($word,$postfix) = $word =~ s/^([a-z]*)([,.!\?;:'"])?$//i;
        if ( $word =~ s/([,.!\?;:'"])$//i ) {
            $postfix = $1;
        }
        if ( $word =~ /^(qu)(.*)/ ) {
            $pigword = "$2$1$suffix";
        }
        elsif ( $word =~ /^(Qu)(.)(.*)/ ) {
            $pigword = uc($2) . $3 . lc($1) . $suffix;
        }
        elsif ( $word =~ /^([bcdfghjklmnpqrstvwxyz]+)(.*)/ ) {
            $pigword = "$2$1$suffix";
        }
        elsif ( $word =~
            /^([BCDFGHJKLMNPQRSTVWXYZ])([bcdfghjklmnpqrstvwxyz]*)([aeiouy])(.*)/
          )
        {
            $pigword = uc($3) . $4 . lc($1) . $2 . $suffix;
        }
        else {
            $pigword = $word . 'w' . $suffix;
        }
        $piglatin .= ' ' if $piglatin;
        $piglatin .= $pigword . $postfix;
    }
    &::performStrictReply( $piglatin || 'failed' );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
