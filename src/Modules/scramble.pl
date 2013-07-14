# Copyright (c) 2003 Chris Angell (chris62vw@hotmail.com). All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

# Turns this:
# Mary had a little lamb and her fleece was white as snow
# into this:
# Mray had a liltte lmab and her flecee was whtie as sonw

use strict;
use warnings;

package scramble;

sub scramble {
    my ($text) = @_;
    my $scrambled;

    return unless &::loadPerlModule("List::Util");
    srand();    # fork seems to not change rand. force it here
    for my $orig_word ( split /\s+/, $text ) {

        # skip words that are less than four characters in length
        $scrambled .= "$orig_word " and next if length($orig_word) < 4;

        # get first and last characters, and middle characters
        # optional characters are for punctuation, etc.
        my ( $first, $middle, $last ) =
          $orig_word =~ /^['"]?(.)(.+)'?(.)[,.!?;:'"]?$/;

        my ( $new_middle, $cnt );

        # shuffle until $new_middle is different from $middle
        do {

            # theoretically, this loop could loop forever, so
            # a counter is used. once $cnt > 10 then use a
            # simple regex to scramble and call it good

            if ( ++$cnt > 10 ) {

                # non-random shuffle, but good enough
                ( $new_middle = $middle ) =~ s/(.)(.)/$2$1/g;
            }

            # shuffle the middle letters
            $new_middle = join '', List::Util::shuffle( split //, $middle );
        } while ( ( $cnt < 10 ) && ( $middle eq $new_middle ) );

        # add the word to the list...
        $scrambled .= "$first$new_middle$last ";
    }

    # remove the single trailing space, and any other space that may have
    # been included in the original string
    $scrambled =~ s/\s+$//;

    &::performStrictReply( $scrambled || 'Unknown Error Condition' );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
