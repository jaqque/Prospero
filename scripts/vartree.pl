#!/usr/bin/perl -w
# hrm...

# use strict;

local @test;
local %test;

$test{'hash0r'}   = 2;
$test{'hegdfgsd'} = 'GSDFSDfsd';

push( @test, "heh." );
push( @test, \%test );

&vartree( \%main::, 'main::' );

sub tree {
    my ( $pad, $ref, $symname ) = @_;
    my $padded = " " x $pad;
    my @list;
    my $scalar = 0;
    my $size   = 0;

    @list = keys %{$symname} if ( $ref eq 'HASH' );
    @list = @{$symname}      if ( $ref eq 'ARRAY' );

    foreach (@list) {
        my $ref = ref $_;

        if ( $ref eq 'HASH' or $ref eq 'ARRAY' ) {
            print $padded. "recursing $ref($_).\n";
            &tree( $pad + 2, $ref, $_ );
        }
        elsif ( $ref eq '' ) {
            $scalar++;
            $size += length($_);
        }
    }
    print $padded. "scalars $scalar, size $size\n";
}

sub vartree {
    my ( $package, $packname ) = @_;
    my $symname;

    # scalar.
    foreach $symname ( sort keys %$package ) {
        local *sym = $$package{$symname};
        next unless ( defined $sym );
        print "scalar => $symname = '$sym'\n";
    }

    # array.
    foreach $symname ( sort keys %$package ) {
        local *sym = $$package{$symname};
        next unless ( defined @sym );
        print "\@$symname\n";
        &tree( 2, "ARRAY", $symname );
    }

    # hash.
    foreach $symname ( sort keys %$package ) {
        local *sym = $$package{$symname};
        next unless ( defined %sym );
        print "\%$symname\n";
        &tree( 2, "HASH", $symname );
    }

    foreach $symname ( sort keys %$package ) {
        local *sym = $$package{$symname};
        next unless ( defined %sym );
        next unless ( $symname =~ /::/ );
        next if ( $symname eq 'main::' );

        print "recurse: $symname.\n";
        &vartree( \%sym, $symname );
    }

    print "end.\n";
}

# vim:ts=4:sw=4:expandtab:tw=80
