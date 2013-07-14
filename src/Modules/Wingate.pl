#
#  Wingate.pl: Wingate checker.
#      Author: dms
#     Version: v0.3 (20000526).
#     Created: 20000116
#        NOTE: based on wingate.pl by fooz.
#

package Wingate;

use strict;
my $select = IO::Select->new;

sub Wingates {
    my $file = "$::infobot_base_dir/$::param{'ircUser'}.wingate";
    my @hosts;

    open( IN, $file );
    while (<IN>) {
        chop;
        next if (/\*$/);    # wingate. or forget about it?
        push( @hosts, $_ );
    }
    close IN;

    foreach (@_) {
        next if ( grep /^$_$/, @hosts );

        &::DEBUG("W: _ => '$_'.");
        &Wingate($_);
    }
}

sub Wingate {
    my ($host) = @_;

    my $sock = IO::Socket::INET->new(
        PeerAddr => $host,
        PeerPort => 'telnet(23)',
        Proto    => 'tcp'
###	Timeout		=> 10,		# enough :)
    );

    if ( !defined $sock ) {
        &::status("Wingate: connection refused to $host");
        return;
    }

    $sock->timeout(10);
    $select->add($sock);

    my $errors = 0;
    my ($luser);
    foreach $luser ( $select->can_read(1) ) {
        my $buf;
        my $len = 0;
        if ( !defined( $len = sysread( $luser, $buf, 512 ) ) ) {
            &::status("Wingate: connection lost to $luser/$host.");
            $select->remove($luser);
            close($luser);
            next;
        }

        if ( $len == 9 ) {
            $len = sysread( $luser, $buf, 512 );
        }

        my $wingate = 0;
        $wingate++ if ( $buf =~ /^WinGate\>/ );
        $wingate++
          if ( $buf =~ /^Too many connected users - try again later$/ );

        if ($wingate) {
            &::status("Wingate: RUNNING ON $host BY $::who.");

            if ( &::IsChanConf('wingateBan') > 0 ) {
                &::ban( "*!*\@$host", '' );
            }

            my $reason = &::getChanConf('wingateKick');
            if ($reason) {
                &::kick( $::who, '', $reason );
            }

            push( @::wingateBad, "$host\*" );
            &::wingateWriteFile();
        }
        else {
###	    &::DEBUG("no wingate.");
        }

        ### TODO: close telnet connection correctly!
        $select->remove($luser);
        close($luser);
    }

    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
