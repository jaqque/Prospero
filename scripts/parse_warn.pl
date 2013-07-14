#!/usr/bin/perl -w

# leading and trailing context lines.
my $contextspread = 2;

use strict;

$| = 1;

if ( !scalar @ARGV ) {
    print "Usage: parse_warn.pl <files>\n";
    print "Example: parse_warn.pl log/*\n";
    exit 0;
}

my %done;
my $file;

foreach $file (@ARGV) {
    if ( !-f $file ) {
        print "warning: $file does not exist.\n";
        next;
    }
    my $str = ' at .* line ';

    print "Opening $file... ";
    if ( $file =~ /bz2$/ ) {    # bz2
        open( FILE, "bzcat $file | egrep '$str' |" );
    }
    elsif ( $file =~ /gz$/ ) {    # gz
        open( FILE, "zegrep '$str' $file |" );
    }
    else {                        # raw
        open( FILE, "egrep '$str' $file |" );
    }

    print "Parsing... ";
    while (<FILE>) {
        if (/ at (\S+) line (\d+)/) {
            my ( $file, $lineno ) = ( $1, $2 + 1 );
            $done{$file}{$lineno}++;
        }
    }
    close FILE;

    print "Done.\n";
}

foreach $file ( keys %done ) {
    my $count = scalar( keys %{ $done{$file} } );
    print "warn $file: $count unique warnings.\n";

    if ( !-f $file ) {
        print "=> error: does not exist.\n\n";
        next;
    }

    if ( open( IN, $file ) ) {
        my @lines = <IN>;
        close IN;

        my $total  = scalar @lines;
        my $spread = 0;
        my $done   = 0;
        for ( my $i = 0 ; $i <= $total ; $i++ ) {
            next
              unless ( exists $done{$file}{ $i + $contextspread } or $spread );

            if ( exists $done{$file}{ $i + $contextspread } ) {
                print "@@ $i @@\n" unless ($spread);

                # max lines between offending lines should be 2*context-1.
                # coincidence that it is!
                $spread = 2 * $contextspread;
            }
            else {
                $spread--;
            }

            if ( exists $done{$file}{$i} ) {
                print "*** ";
            }
            else {
                print "--- ";
            }

            if ( $i >= $total ) {
                print "EOF\n";
            }
            else {
                print $lines[$i];
            }
        }
        print "\n";
    }
    else {
        print "=> error: could not open file.\n";
    }
}

# vim:ts=4:sw=4:expandtab:tw=80
