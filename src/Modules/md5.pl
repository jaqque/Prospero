#       md5.pl: md5 a string
#       Author: Tim Riker
#    Licensing: Artistic License
#      Version: v0.1 (20041209)
#
use strict;

package md5;

sub md5 {
    my ($message) = @_;
    return unless &::loadPerlModule('Digest::MD5');

    &::performStrictReply( &Digest::MD5::md5_hex($message) );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
