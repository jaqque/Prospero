#!/usr/bin/perl -w

use DBI;

my $dsn = "DBI:mysql:infobot:localhost";
my $dbh = DBI->connect( $dsn, "USERNAME", "PASSWORD" );

my @factkey;
my %factval;
my $query;
my $regex = '\\\\([\_\%])';

$query = "SELECT factoid_key,factoid_value from factoids";
my $sth = $dbh->prepare($query);
$sth->execute;
while ( my @row = $sth->fetchrow_array ) {
    if ( $row[0] =~ /$regex/ ) {
        push( @factkey, $row[0] );
    }
    else {
        $factval{ $row[0] } = $row[1] if ( $row[1] =~ /$regex/ );
    }
}
$sth->finish;

print "scalar factkey => '" . scalar(@factkey) . "'\n";
foreach (@factkey) {
    print "factkey => '$_'.\n";
    my $new = $_;
    $new =~ s/$regex/$1/g;

    next if ( $new eq $_ );

    $query =
      "SELECT factoid_key FROM factoids where factoid_key=" . $dbh->quote($new);
    my $sth = $dbh->prepare($query);
    $sth->execute;
    if ( scalar $sth->fetchrow_array ) {    # exist.
        print "please remove $new or $_.\n";
    }
    else {                                  # ! exist.
        $sth->finish;

        $query =
            "UPDATE factoids SET factoid_key="
          . $dbh->quote($new)
          . " WHERE factoid_key="
          . $dbh->quote($_);
        my $sth = $dbh->prepare($query);
        $sth->execute;
        $sth->finish;
    }
}

print "scalar factval => '" . scalar( keys %factval ) . "\n";
foreach ( keys %factval ) {
    print "factval => '$_'.\n";
    my $fact = $_;
    my $old  = $factval{$_};
    my $new  = $old;
    $new =~ s/$regex/$1/g;

    next if ( $new eq $old );

    $query =
        "UPDATE factoids SET factoid_value="
      . $dbh->quote($new)
      . " WHERE factoid_key="
      . $dbh->quote($fact);
    my $sth = $dbh->prepare($query);
    $sth->execute;
    $sth->finish;
}

$dbh->disconnect();

# vim:ts=4:sw=4:expandtab:tw=80
