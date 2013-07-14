#!/usr/bin/perl
# by the xk.
###

require "src/core.pl";
require "src/logger.pl";
require "src/modules.pl";

require "src/Misc.pl";
require "src/Files.pl";
&loadDBModules();
require "src/dbi.pl";

package main;

# todo: main()

if ( !scalar @ARGV ) {
    print "Usage: dbm2mysql <whatever dbm>\n";
    print "Example: dbm2mysql.pl apt\n";
    print "NOTE: suffix '-is' and '-extra' are used.\n";
    exit 0;
}

my $dbfile = shift;
my $key;
my %db;

# open dbm.
if ( !dbmopen( %db, $dbfile, 0666 ) ) {
    &ERROR("Failed open to dbm file ($dbfile).");
    exit 1;
}
&status("::: opening dbm file: $dbfile");

# open all the data...
&loadConfig("files/infobot.config");
$dbname = $param{'DBName'};
my $dbh_mysql = sqlOpenDB(
    $param{'DBName'},  $param{'DBType'},
    $param{'SQLUser'}, $param{'SQLPass'}
);
print "DEBUG: scalar db == '" . scalar( keys %db ) . "'.\n";

my $factoid;
my $ndef = 1;
my $i    = 1;
foreach $factoid ( keys %db ) {
    &sqlReplace(
        "factoids",
        {
            factoid_key   => $_,
            factoid_value => $db{$_},
        }
    );

    $i++;
    print "i=$i... "       if ( $i % 100 == 0 );
    print "ndef=$ndef... " if ( $ndef % 1000 == 0 );
}

print "Done.\n";
&closeDB();
dbmclose(%db);

# vim:ts=4:sw=4:expandtab:tw=80
