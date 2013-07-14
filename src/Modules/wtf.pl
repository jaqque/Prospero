#
#     wtf.pl: interface to bsd wtf
#     Author: Tim Riker <Tim@Rikers.org>
#     Source: modified from jethro's patch
#  Licensing: Artistic License (as perl itself)
#    Version: v0.1
#
#  Copyright (c) 2005 Tim Riker
#

package wtf;

use strict;

sub wtf::wtf {
    my $query = shift;
    my $binary;
    my @binaries = ( '/usr/games/wtf', '/usr/local/bin/wtf' );
    foreach (@binaries) {
        if ( -x $_ ) {
            $binary = $_;
            last;
        }
    }
    if ( !$binary ) {
        return ("no binary found.");
    }
    if ( $query =~ /^$|[^\w]/ ) {
        return ("usage: wtf <foo>.");
    }
    if ( !&::validExec($query) ) {
        return ("argument appears to be fuzzy.");
    }

    my $reply = '';
    foreach (`$binary '$query' 2>&1`) {
        $reply .= $_;
    }
    $reply =~ s/\n/ /;
    chomp($reply);
    return ($reply);
}

sub wtf::query {
    &::performStrictReply( &wtf(@_) );
    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
