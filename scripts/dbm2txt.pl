#!/usr/bin/perl -w

use strict;
use DB_File;
if ( !scalar @ARGV ) {
    print "Usage: dbm2txt <whatever dbm>\n";
    print "Example: dbm2txt.pl factoids\n";
    exit 0;
}

my $dbfile = shift;
my %db;
if (0) {
    require "src/Factoids/db_dbm.pl";
    openDB();
}

dbmopen( %db, $dbfile, 0644 ) or die "error: cannot open db. $dbfile\n";
my ( $key, $val );
while ( ( $key, $val ) = each %db ) {
    chomp $val;
    print "$key => $val\n";
}
dbmclose %db;

# vim:ts=4:sw=4:expandtab:tw=80
