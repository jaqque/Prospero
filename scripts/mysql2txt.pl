#!/usr/bin/perl
# mysql -> txt.
# written by the xk.
###

require "src/core.pl";
require "src/logger.pl";
require "src/modules.pl";
require "src/Misc.pl";
require "src/Files.pl";
$bot_src_dir = "./src/";

my $dbname = shift;
if ( !defined $dbname ) {
    print "Usage: $0 <db name>\n";
    print "Example: $0 factoids\n";
    exit 0;
}

# open the db.
&loadConfig("files/infobot.config");
&loadDBModules();

&openDB( $param{'DBName'}, $param{'SQLUser'}, $param{'SQLPass'} );

# retrieve a list of db's from the server.
my %db;
foreach ( $dbh->func('_ListTables') ) {
    $db{$_} = 1;
}

# factoid db.
if ( !exists $db{$dbname} ) {
    print "error: $dbname does not exist as a table.\n";
    exit 1;
}

my $query = "SELECT factoid_key,factoid_value from $param{'DBName'}.$dbname";
my $sth   = $dbh->prepare($query);
$sth->execute;
while ( my @row = $sth->fetchrow_array ) {
    print "$row[0] => $row[1]\n";
}
$sth->finish;

print "Done.\n";
&closeDB();

# vim:ts=4:sw=4:expandtab:tw=80
