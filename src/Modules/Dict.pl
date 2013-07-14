#
#  Dict.pl: Frontend to dict.org.
#   Author: dms
#  Version: v0.6c (20000924).
#  Created: 19990914.
#  Updates: Copyright (c) 2005 - Tim Riker <Tim@Rikers.org>
#
# see http://luetzschena-stahmeln.de/dictd/
# for a list of dict servers

package Dict;

use IO::Socket;
use strict;

#use vars qw(PF_INET);

# need a specific host||ip.
my $server = "dict.org";

sub Dict {
    my ($query) = @_;

    #    return unless &::loadPerlModule("IO::Socket");
    my $port  = 2628;
    my $proto = getprotobyname('tcp');
    my @results;
    my $retval;

    for ($query) {
        s/^[\s\t]+//;
        s/[\s\t]+$//;
        s/[\s\t]+/ /;
    }

    # connect.
    # TODO: make strict-safe constants... so we can defer IO::Socket load.
    my $socket = new IO::Socket;
    socket( $socket, PF_INET, SOCK_STREAM, $proto )
      or return "error: socket: $!";
    eval {
        local $SIG{ALRM} = sub { die 'alarm' };
        alarm 10;
        connect( $socket, sockaddr_in( $port, inet_aton($server) ) )
          or die "error: connect: $!";
        alarm 0;
    };

    if ($@) {

        # failure.
        $retval = "i could not get info from $server '$@'";
    }
    else {    # success.
        $socket->autoflush(1);    # required.

        my $num;
        if ( $query =~ s/^(\d+)\s+// ) {
            $num = $1;
        }
        my $dict = '*';
        if ( $query =~ s/\/(\S+)$// ) {
            $dict = $1;
        }

        # body.
        push( @results, &Define( $socket, $query, $dict ) );

        #push(@results, &Define($socket,$query,'foldoc'));
        #push(@results, &Define($socket,$query,'web1913'));
        # end.

        print $socket "QUIT\n";
        close $socket;

        my $count = 0;
        foreach (@results) {
            $count++;
            &::DEBUG("$count: $_");
        }
        my $total = scalar @results;

        if ( $total == 0 ) {
            $num = undef;
        }

        if ( defined $num and ( $num > $total or $num < 1 ) ) {
            &::msg( $::who, "error: choice in definition is out of range." );
            return;
        }

        # parse the results.
        if ( $total > 1 ) {
            if ( defined $num ) {
                $retval =
                  sprintf( "[%d/%d] %s", $num, $total, $results[ $num - 1 ] );
            }
            else {

                # suggested by larne and others.
                my $prefix = "Dictionary '$query' ";
                $retval = &::formListReply( 1, $prefix, @results );
            }
        }
        elsif ( $total == 1 ) {
            $retval = "Dictionary '$query' " . $results[0];
        }
        else {
            $retval = "could not find definition for \002$query\002";
            $retval .= " in $dict" if ( $dict ne '*' );
        }
    }

    &::performStrictReply($retval);
}

sub Define {
    my ( $socket, $query, $dict ) = @_;
    my @results;

    &::DEBUG("Dict: asking $dict.");
    print $socket "DEFINE $dict \"$query\"\n";

    my $def  = '';
    my $term = $query;

    while (<$socket>) {
        chop;    # remove \n
        chop;    # remove \r

        &::DEBUG("$term/$dict '$_'");
        if (/^552 /) {

            # no match.
            return;
        }
        elsif (/^250 /) {

            # end w/ optional stats
            last;
        }
        elsif (/^151 "([^"]*)" (\S+) .*/) {

            # 151 "Good Thing" jargon "Jargon File (4.3.0, 30 APR 2001)"
            $term = $1;
            $dict = $2;
            $def  = '';
            &::DEBUG("term=$term dict=$dict");
        }
        else {
            my $line = $_;

            # some dicts put part of the definition on the same line ie: jargon
            $line =~ s/^$term//i;
            $line =~ s/^\s+/ /;
            if ( $dict eq 'wn' ) {

                # special processing for sub defs in wordnet
                if ( $line eq '.' ) {

                    # end of def.
                    $def =~ s/\s+$//;
                    $def =~ s/\[[^\]]*\]//g;
                    push( @results, $def );
                }
                elsif ( $line =~ m/^\s+(\S+ )?(\d+)?: (.*)/ ) {

                    # start of sub def.
                    my $text = $3;
                    $def =~ s/\s+$//;

                    #&::DEBUG("def => '$def'.");
                    $def =~ s/\[[^\]]*\]//g;
                    push( @results, $def ) if ( $def ne '' );
                    $def = $text;
                }
                elsif (/^\s+(.*)/) {
                    $def .= $line;
                }
                else {
                    &::DEBUG("ignored '$line'");
                }
            }
            else {

                # would be nice to divide other dicts
                # but many are not always in a parsable format
                if ( $line eq '.' ) {

                    # end of def.
                    next if ( $def eq '' );
                    push( @results, $def );
                    $def = '';
                }
                elsif ( $line =~ m/^\s+(\S.*\S)\s*$/ ) {

                    #&::DEBUG("got '$1'");
                    $def .= ' ' if ( $def ne '' );
                    $def .= $1;
                }
                else {
                    &::DEBUG("ignored '$line'");
                }
            }
        }
    }

    &::DEBUG( "Dict: $dict: found " . scalar(@results) . " defs." );

    return if ( !scalar @results );

    return @results;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
