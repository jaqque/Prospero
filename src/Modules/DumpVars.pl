#
#  DumpVars.pl: Perl variables dumper.
#   Maintained: dms
#      Version: v0.1 (20000114)
#      Created: 20000114
#         NOTE: Ripped from ActivePerl "asp sample" example.
#

# FIXME
#use strict;

#use vars qw();

my $countlines = 0;

sub dumpvarslog {
    my ($line) = @_;
    if ( &IsParam('dumpvarsLogFile') ) {
        print DUMPVARS $line . "\n";
    }
    else {
        &status( "DV: " . $line );
    }
}

sub DumpNames(\%$) {
    my ( $package, $packname ) = @_;
    my $symname = 0;
    my $line;

    if ( $packname eq 'main::' ) {
        &dumpvarslog('Packages');

        foreach $symname ( sort keys %$package ) {
            local *sym = $$package{$symname};
            next unless ( defined %sym );
            next unless ( $symname =~ /::/ );
            &dumpvarslog("   $symname");
            $countlines++;
        }
    }

    # Scalars.
    foreach $symname ( sort keys %$package ) {
        local *sym = $$package{$symname};
        next unless ( defined $sym );

        my $line;
        if ( length($sym) > 512 ) {
            &dumpvarslog("Scalar '$packname' $symname too long.");
        }
        else {
            &dumpvarslog("Scalar '$packname' \$ $symname => '$sym'");
        }
        $countlines++;
    }

    # Functions.
    foreach $symname ( sort keys %$package ) {
        local *sym = $$package{$symname};
        next unless ( defined &sym );

        &dumpvarslog("Function '$packname' $symname()");
        $countlines++;
    }

    # Lists.
    foreach $symname ( sort keys %$package ) {
        local *sym = $$package{$symname};
        next unless ( defined @sym );

        &dumpvarslog(
            "List '$packname' \@$symname (" . scalar( @{$symname} ) . ")" );
        $countlines++;

        next unless ( $packname eq 'main::' );
        foreach ( @{$symname} ) {
            if ( defined $_ ) {
                &dumpvarslog("   => '$_'.");
            }
            else {
                &dumpvarslog("   => <NULL>.");
            }
        }
    }

    # Hashes.
    foreach $symname ( sort keys %$package ) {
        local *sym = $$package{$symname};
        next unless ( defined %sym );
        next if ( $symname =~ /::/ );

        &dumpvarslog("Hash '$packname' \%$symname");
        $countlines++;

        next unless ( $packname eq 'main::' );
        foreach ( keys %{$symname} ) {
            my $val = ${$symname}{$_};
            if ( defined $val ) {
                &dumpvarslog("   $_ => '$val'.");
            }
            else {
                &dumpvarslog("   $_ => <NULL>.");
            }
        }
    }

    return unless ( $packname eq 'main::' );

    foreach $symname ( sort keys %$package ) {
        local *sym = $$package{$symname};
        next unless ( defined %sym );
        next unless ( $symname =~ /::/ );
        next if ( $symname eq 'main::' );

        DumpNames( \%sym, $symname );
    }
}

sub dumpallvars {
    if ( &IsParam('dumpvarsLogFile') ) {
        my $file = $param{'dumpvarsLogFile'};
        &status("opening fh to dumpvars ($file)");
        if ( !open( DUMPVARS, ">$file" ) ) {
            &ERROR("cannot open dumpvars.");
            return;
        }
    }

    DumpNames( %main::, 'main::' );

    if ( &IsParam('dumpvarsLogFile') ) {
        &status("closing fh to dumpvars");
        close DUMPVARS;
    }

    &status("DV: count == $countlines");
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
