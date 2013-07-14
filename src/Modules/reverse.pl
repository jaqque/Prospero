#   reverse.pl: reverse a string
#       Author: Tim Riker
#    Licensing: Artistic License
#      Version: v0.1 (20050812)
#
use strict;

package reverse;

sub reverse {
    my ($message) = @_;
    &::performStrictReply( join( '', reverse( split( '', $message ) ) ) );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
