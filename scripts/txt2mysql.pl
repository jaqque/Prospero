#!/usr/bin/perl
# by the xk.
#

require "src/core.pl";
require "src/logger.pl";
require "src/modules.pl";
require "src/Files.pl";
require "src/Misc.pl";
require "src/Factoids/DBCommon.pl";

if ( !scalar @ARGV ) {
    print "Usage: txt2mysql.pl <input.txt>\n";
    exit 0;
}

# open the txtfile.
my $txtfile = shift;
open( IN, $txtfile ) or die "error: cannot open txtfile '$txtfile'.\n";

# read the bot config file.
&loadConfig("files/infobot.config");
&loadDBModules();
&openDB( $param{'DBName'}, $param{'SQLUser'}, $param{'SQLPass'} );

### now pipe all the data to the mysql server...
my $i = 1;
print "converting factoid db to mysql...\n";
while (<IN>) {
    chop;
    next if !length;
    if (/^(.*)\s+=>\s+(.*)$/) {

        # verify if it already exists?
        my ( $key, $val ) = ( $1, $2 );
        if ( $key =~ /^\s*$/ or $val =~ /^\s*$/ ) {
            print "warning: broken => '$_'.\n";
            next;
        }

        if (    &IsParam("freshmeat")
            and &dbGet( "freshmeat", "name", $key, "name" ) )
        {
            if ( &getFactoid($key) ) {
                &delFactoid($key);
            }
        }
        else {
            &setFactInfo( lc $key, "factoid_value", $val );
            $i++;
        }

        print "$i... " if ( $i % 100 == 0 );
    }
    else {
        print "warning: invalid => '$_'.\n";
    }
}
close IN;

print "Done.\n";
&closeDB();

# vim:ts=4:sw=4:expandtab:tw=80
