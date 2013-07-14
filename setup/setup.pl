#!/usr/bin/perl
# setup_tables: setup MYSQL/PGSQL side of things for infobot.
# written by the xk.
###

require "src/logger.pl";
require "src/core.pl";
require "src/modules.pl";
require "src/Misc.pl";
require "src/CLI/Support.pl";

$bot_src_dir = "src/";

# read param stuff from infobot.config.
&loadConfig("files/infobot.config");

&loadDBModules();
my $dbname = $param{'DBName'};
my $query;

if ( $dbname eq "" ) {
    print "error: appears that the config file was not loaded properly.\n";
    exit 1;
}

if ( $param{'DBType'} =~ /mysql/i ) {
    use DBI;

    print "Enter root information...\n";

    # username.
    print "Username: ";
    chop( my $adminuser = <STDIN> );

    # passwd.
    system "stty -echo";
    print "Password: ";
    chop( my $adminpass = <STDIN> );
    print "\n";
    system "stty echo";

    if ( $adminuser eq "" or $adminpass eq "" ) {
        &ERROR("error: adminuser || adminpass is NULL.");
        exit 1;
    }

    &sqlOpenDB( "mysql", "mysql", $adminuser, $adminpass );

    my $database_exists = 0;
    foreach $database ( &sqlRawReturn("SHOW DATABASES") ) {
        $database_exists++ if $database eq $param{DBName};
    }
    if ($database_exists) {
        &status("Database '$param{DBName}' already exists. Continuing...");
    }
    else {
        &status("Creating db ...");
        &sqlRaw( "create(database)", "CREATE DATABASE $param{DBName}" );
    }

    &status("--- Adding user information for user '$param{'SQLUser'}'");

    if (
        !&sqlSelect(
            "user", "user", { 'user' => &sqlQuote( $param{'SQLUser'} ) }
        )
      )
    {
        &status("--- Adding user '$param{'SQLUser'}' $dbname/user table...");

        $query =
            "INSERT INTO user VALUES "
          . "('localhost', '$param{'SQLUser'}', "
          . "password('$param{'SQLPass'}'), ";

        $query .= "'Y','Y','Y','Y','Y','Y','N','N','N','N','N','N','N','N')";

        &sqlRaw( "create(user)", $query );
    }
    else {
        &status("... user information already present.");
    }

    if ( !&sqlSelect( "db", "db", { 'db' => &sqlQuote( $param{'SQLUser'} ) } ) )
    {
        &status("--- Adding database information for database '$dbname'.");

        $query =
            "INSERT INTO db VALUES "
          . "('localhost', '$dbname', "
          . "'$param{'SQLUser'}', ";

        $query .= "'Y','Y','Y','Y','Y','Y','Y','N','N','N')";

        &sqlRaw( "create(db)", $query );
    }
    else {
        &status("... db info already present.");
    }

    # flush.
    &status("Flushing privileges...");
    $query = "FLUSH PRIVILEGES";
    &sqlRaw( "mysql(flush)", $query );
}

&status("Done.");

&sqlCloseDB();

# vim:ts=4:sw=4:expandtab:tw=80
