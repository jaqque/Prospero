# HTTPDtype.pl: retrieves http server headers
#       Author: Joey Smith <joey@php.net>
#    Licensing: Artistic License
#      Version: v0.1 (20031110)
#
use strict;

package HTTPDtype;

sub HTTPDtype {
    my ($HOST) = @_;
    my ($line) = '';
    my ( $code, $mess, %h );

    # TODO: remove leading http:// and trailing :port and /foo if found
    $HOST = 'joeysmith.com' unless length($HOST) > 0;
    return unless &::loadPerlModule("Net::HTTP::NB");
    return unless &::loadPerlModule("IO::Select");

    my $s = Net::HTTP::NB->new( Host => $HOST ) || return;
    $s->write_request( HEAD => "/" );

    my $sel = IO::Select->new($s);
    $line = 'Header timeout' unless $sel->can_read(10);
    ( $code, $mess, %h ) = $s->read_response_headers;

    $line =
      ( length( $h{Server} ) > 0 )
      ? $h{Server}
      : "Couldn't fetch headers from $HOST";

    &::performStrictReply( $line || 'Unknown Error Condition' );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
