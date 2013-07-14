#
#  DumpVars2.pl: Perl variables dumper ][.
#    Maintained: dms
#       Version: v0.1 (20020329)
#       Created: 20020329
#

# use strict;	# TODO

use Devel::Symdump;

sub symdumplog {
    my ($line) = @_;

    if ( fileno SYMDUMP ) {
        print SYMDUMP $line . "\n";
    }
    else {
        &status( "SD: " . $line );
    }
}

sub symdumpAll {
    my $o = Devel::Symdump->rnew();

    # scalars.
    foreach ( $o->scalars ) {

        #	&symdumpRecur($_);
        symdumplog("  scalar($_)");
    }
}

sub symdumpRecur {
    my $x = shift;

    if ( ref $x eq 'HASH' ) {
        foreach ( keys %$x ) {
            &symdumpRecur($_);
        }
    }
    else {
        symdumplog("unknown: $x");
    }
}

sub symdumpAllFile {
    &DEBUG('before open');
    if ( &IsParam('symdumpLogFile') ) {
        my $file = $param{'symdumpLogFile'};
        &status("opening fh to symdump ($file)");
        if ( !open( SYMDUMP, ">$file" ) ) {
            &ERROR('cannot open dumpvars.');
            return;
        }
    }
    &DEBUG('after open');

    symdumpAll();

    if ( fileno SYMDUMP ) {
        &status('closing fh to symdump');
        close SYMDUMP;
    }

    &status("SD: count == $countlines");
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
