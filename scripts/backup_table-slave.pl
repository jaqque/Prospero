#!/usr/bin/perl -w
#
# backup_table-slave.pl: Backup mysql tables
#     Author: dms
#    Version: v0.1b (20000223)
#    Created: 20000210
#


use strict;
use LWP;
use POSIX qw(strftime);

my $backup_interval = 1;    # every: 1,7,14,30.
my $backup_count    = 7;
my $backup_url       = "http://achilles.nyip.net/~apt/tables.tar.bz2";
my $backup_file      = "tables-##DATE.tar.bz2";
my $backup_destdir   = "/home/xk/public_html/";
my $backup_indexfile = "tables-index.txt";

my %index;

# Usage: &getURL($url);
sub getURL {
    my ($url) = @_;
    my ( $ua, $res, $req );

    $ua = new LWP::UserAgent;
    $ua->proxy( 'http', $ENV{'http_proxy'} ) if ( exists $ENV{'http_proxy'} );
    $ua->proxy( 'http', $ENV{'HTTP_PROXY'} ) if ( exists $ENV{'HTTP_PROXY'} );

    $req = new HTTP::Request( 'GET', $url );
    $res = $ua->request($req);

    # return NULL upon error.
    if ( $res->is_success ) {
        return $res->content;
    }
    else {
        print "error: failure.\n";
        exit 1;
    }
}

#...
if ( -f "$backup_destdir/$backup_indexfile" ) {
    if ( open( INDEX, "$backup_destdir/$backup_indexfile" ) ) {
        while (<INDEX>) {
            chop;

            # days since 1970, file.
            if (/^(\d+) (\S+)$/) {
                $index{$1} = $2;
            }
        }
        close INDEX;
    }
    else {
        print "WARNING: can't open $backup_indexfile.\n";
    }
}
my $now_days = (localtime)[7] + ( ( (localtime)[5] - 70 ) * 365 );
my $now_date = strftime( "%Y%m%d", localtime );

if ( scalar keys %index ) {
    my $last_days = ( sort { $b <=> $a } keys %index )[0];

    if ( $now_days - $last_days < $backup_interval ) {
        print "error: shouldn't run today.\n";
        goto recycle;
    }
}

$backup_file =~ s/##DATE/$now_date/;
print "backup_file => '$backup_file'.\n";
if ( -f $backup_file ) {
    print "error: $backup_file already exists.\n";
    exit 1;
}

my $file = &getURL($backup_url);
open( OUT, ">$backup_destdir/$backup_file" );
print OUT $file;
close OUT;

$index{$now_days} = $backup_file;
recycle:;
my @index = sort { $b <=> $a } keys %index;

open( OUT, ">$backup_destdir/$backup_indexfile" );
for ( my $i = 0 ; $i < scalar(@index) ; $i++ ) {
    my $day = $index[$i];
    print "fe: day => '$day'.\n";

    if ( $backup_count - 1 >= $i ) {
        print "DEBUG: $day $index{$day}\n";
        print OUT "$day $index{$day}\n";
    }
    else {
        print "Deleting $backup_destdir/$index{$day}\n";
        unlink "$backup_destdir/$index{$day}";
    }
}
close OUT;

print "Done.\n";

# vim:ts=4:sw=4:expandtab:tw=80
