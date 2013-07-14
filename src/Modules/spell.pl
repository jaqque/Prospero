#
#   spell.pl: interface to aspell/ispell/spell
#	 Author: Tim Riker <Tim@Rikers.org>
#	 Source: extracted from UserExtra
#  Licensing: Artistic License (as perl itself)
#	Version: v0.1
#
#  Copyright (c) 2005 Tim Riker
#

package spell;

use strict;

sub spell::spell {
    my $query = shift;
    if ( $query =~ m/[^[:alpha:]]/ ) {
        return ('only one word of alphabetic characters supported');
    }

    my $binary;
    my @binaries = ( '/usr/bin/aspell', '/usr/bin/ispell', '/usr/bin/spell' );

    foreach (@binaries) {
        if ( -x $_ ) {
            $binary = $_;
            last;
        }
    }

    if ( !$binary ) {
        return ('no binary found.');
    }

    if ( !&::validExec($query) ) {
        return ('argument appears to be fuzzy.');
    }

    my $reply = "I can't find alternate spellings for '$query'";

    foreach (`/bin/echo '$query' | $binary -a -S`) {
        chop;
        last if !length;    # end of query.

        if (/^\@/) {        # intro line.
            next;
        }
        elsif (/^\*/) {     # possibly correct.
            $reply = "'$query' may be spelled correctly";
            last;
        }
        elsif (/^\&/) {     # possible correction(s).
            s/^\& (\S+) \d+ \d+: //;
            my @array = split(/,? /);

            $reply = "possible spellings for $query: @array";
            last;
        }
        elsif (/^\+/) {
            &::DEBUG("spell: '+' found => '$_'.");
            last;
        }
        elsif (/^# (.*?) 0$/) {

            # none found.
            last;
        }
        else {
            &::DEBUG("spell: unknown: '$_'.");
        }
    }

    return ($reply);
}

sub spell::query {
    &::performStrictReply( &spell(@_) );
    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
