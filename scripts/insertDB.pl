#!/usr/bin/perl -w

$| = 1;

use strict;

require "src/core.pl";
require "src/logger.pl";
require "src/modules.pl";
require "src/Factoids/DBCommon.pl";

&loadConfig( $bot_config_dir . "/infobot.config" );
&loadDBModules();

unless (@_) {
    print "hrm.. usage\n";
    exit 0;
}

foreach (@_) {
    next unless ( -f $_ );

    open( IN, $_ ) or die "error: cannot open $_\n";
    print "Opened $_ for input...\n";

    print "inserting... ";
    while (<IN>) {
        next unless (/^(.*?) => (.*)$/);

        ### TODO: check if it already exists. if so, don't add.
        &setFactInfo( $1, "factoid_value", $2 );
        print ":: $1 ";
    }

    close IN;
}

# vim:ts=4:sw=4:expandtab:tw=80
