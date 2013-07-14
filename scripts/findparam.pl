#!/usr/bin/perl -w

use strict;

my ( %param, %conf, %both );

foreach (`find -name "*.pl"`) {
    chop;
    my $file  = $_;
    my $debug = 0;

    open( IN, $file );
    while (<IN>) {
        chop;

        if (/IsParam\(['"](\S+?)['"]\)/) {
            print "File: $file: IsParam: $1\n" if $debug;
            $param{$1}++;
            next;
        }

        if (/IsChanConfOrWarn\(['"](\S+?)['"]\)/) {
            print "File: $file: IsChanConfOrWarn: $1\n" if $debug;
            $both{$1}++;
            next;
        }

        if (/getChanConfDefault\(['"](\S+?)['"]/) {
            print "File: $file: gCCD: $1\n" if $debug;
            $both{$1}++;
            next;
        }

        if (/getChanConf\(['"](\S+?)['"]/) {
            print "File: $file: gCC: $1\n" if $debug;
            $conf{$1}++;
            next;
        }

        if (/IsChanConf\(['"](\S+?)['"]\)/) {
            print "File: $file: ICC: $1\n" if $debug;
            $conf{$1}++;
            next;
        }

        # command hooks => IsChanConfOrWarn => both.
        # note: this does not support multiple lines.
        if (/\'Identifier\'[\s\t]=>[\s\t]+\'(\S+?)\'/) {
            print "File: $file: command hook: $1\n" if $debug;
            $both{$1}++;
            next;
        }
    }
    close IN;
}

print "Conf AND/OR Params:\n";
foreach ( sort keys %both ) {
    print "    $_\n";
}
print "\n";

print "Params:\n";
foreach ( sort keys %param ) {
    print "    $_\n";
}
print "\n";

print "Conf:\n";
foreach ( sort keys %conf ) {
    print "    $_\n";
}

# vim:ts=4:sw=4:expandtab:tw=80
