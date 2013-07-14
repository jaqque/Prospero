#
#  modules.pl: pseudo-Module handler
#      Author: dms
#     Version: v0.2 (20000629)
#     Created: 20000624
#

use strict;

use vars qw($AUTOLOAD $no_timehires $bot_version $bot_release);

###
### REQUIRED MODULES.
###

eval 'use IO::Socket';
if ($@) {
    &ERROR('no IO::Socket?');
    exit 1;
}
&showProc(' (IO::Socket)');

### THIS IS NOT LOADED ON RELOAD :(
my @myModulesLoadNow;
my @myModulesReloadNot;

BEGIN {
    @myModulesLoadNow = (
        'Topic',     'Uptime',  'News', 'RootWarn',
        'DumpVars2', 'botmail', 'OnJoin'
    );
    @myModulesReloadNot = ( 'IRC/Irc.pl', 'IRC/Schedulers.pl' );
}

sub loadCoreModules {
    my @mods = &getPerlFiles($bot_src_dir);

    &status('Loading CORE modules...');

    foreach ( sort @mods ) {
        my $mod = "$bot_src_dir/$_";

        eval "require \"$mod\"";
        if ($@) {
            &ERROR("lCM => $@");
            &shutdown();
            exit 1;
        }

        $moduleAge{$mod} = ( stat $mod )[9];
        &showProc(" ($_)") if ( &IsParam('DEBUG') );
    }
}

sub loadDBModules {
    my $f;

    # TODO: use function to load module.

    if ( $param{'DBType'} =~ /^(mysql|SQLite(2)?|pgsql)$/i ) {
        eval 'use DBI';
        if ($@) {
            &ERROR( 'No support for DBI::' . $param{'DBType'} . ', exiting!' );
            exit 1;
        }
        &status( 'Loading ' . $param{'DBType'} . ' support.' );
        $f = "$bot_src_dir/dbi.pl";
        require $f;
        $moduleAge{$f} = ( stat $f )[9];

        &showProc( ' (DBI::' . $param{'DBType'} . ')' );
    }
    else {
        &WARN('DB support DISABLED.');
        return;
    }
}

sub loadFactoidsModules {
    if ( !&IsParam('factoids') ) {
        &status('Factoid support DISABLED.');
        return;
    }

    &status('Loading Factoids modules...');

    foreach ( &getPerlFiles("$bot_src_dir/Factoids") ) {
        my $mod = "$bot_src_dir/Factoids/$_";

        eval "require \"$mod\"";
        if ($@) {
            &ERROR("lFM: $@");
            exit 1;
        }

        $moduleAge{$mod} = ( stat $mod )[9];
        &showProc(" ($_)") if ( &IsParam('DEBUG') );
    }
}

sub loadIRCModules {
    my ($interface) = &whatInterface();
    if ( $interface =~ /IRC/ ) {
        &status('Loading IRC modules...');

        eval 'use Net::IRC';
        if ($@) {
            &ERROR('libnet-irc-perl is not installed!');
            exit 1;
        }
        &showProc(' (Net::IRC)');
    }
    else {
        &status('IRC support DISABLED.');

        # disabling forking. Why?
        #$param{forking}	= 0;
        #$param{noSHM}	= 1;
    }

    foreach ( &getPerlFiles("$bot_src_dir/$interface") ) {
        my $mod = "$bot_src_dir/$interface/$_";

        # hrm... use another config option besides DEBUG to display
        # change in memory usage.
        &status("Loading Modules \"$mod\"") if ( !&IsParam('DEBUG') );
        eval "require \"$mod\"";
        if ($@) {
            &ERROR("require \"$mod\" => $@");
            &shutdown();
            exit 1;
        }

        $moduleAge{$mod} = ( stat $mod )[9];
        &showProc(" ($_)") if ( &IsParam('DEBUG') );
    }
}

sub loadMyModulesNow {
    my $loaded = 0;
    my $total  = 0;

    &status('Loading MyModules...');
    foreach (@myModulesLoadNow) {
        $total++;
        if ( !defined $_ ) {
            &WARN('mMLN: null element.');
            next;
        }

        if ( !&IsParam($_) and &IsChanConf($_) <= 0 and !&getChanConfList($_) )
        {
            &DEBUG("loadMyModuleNow: $_ (2) not loaded.");
            next;
        }

        &loadMyModule($_);
        $loaded++;
    }

    &status("Module: Runtime: Loaded/Total [$loaded/$total]");
}

### rename to moduleReloadAll?
sub reloadAllModules {
    my $retval = '';

    &VERB( 'Module: reloading all.', 2 );

    # Reload version and save
    open( VERSION, '<VERSION' );
    $bot_release = <VERSION> || '(unknown version)';
    chomp($bot_release);
    $bot_version = "infobot $bot_release -- $^O";
    close(VERSION);

    # obscure usage of map and regex :)
    foreach ( map { s/.*?\/?src/src/; $_ } keys %moduleAge ) {
        $retval .= &reloadModule($_);
    }

    &VERB( 'Module: reloading done.', 2 );
    return $retval;
}

### rename to modulesReload?
sub reloadModule {
    my ($mod) = @_;
    my $file = ( grep /\/$mod/, keys %INC )[0];
    my $retval = '';

    # don't reload if it's not our module.
    if ( $mod =~ /::/ or $mod !~ /pl$/ ) {
        &VERB( "Not reloading $mod.", 3 );
        return $retval;
    }

    if ( !defined $file ) {
        &WARN("rM: Cannot reload $mod since it was not loaded anyway.");
        return $retval;
    }

    if ( !-f $file ) {
        &ERROR("rM: file '$file' does not exist?");
        return $retval;
    }

    if ( grep /$mod/, @myModulesReloadNot ) {
        &DEBUG("rM: should not reload $mod");
        return $retval;
    }

    my $age = ( stat $file )[9];

    if ( !exists $moduleAge{$file} ) {
        &DEBUG("Looks like $file was not loaded; fixing.");
    }
    else {
        return $retval if ( $age == $moduleAge{$file} );

        if ( $age < $moduleAge{$file} ) {
            &WARN("rM: we're not gonna downgrade '$file'; use touch.");
            &DEBUG("age => $age, mA{$file} => $moduleAge{$file}");
            return $retval;
        }

        my $dc  = &Time2String( $age - $moduleAge{$file} );
        my $ago = &Time2String( time() - $moduleAge{$file} );

        &VERB( "Module:  delta change: $dc",  2 );
        &VERB( "Module:           ago: $ago", 2 );
    }

    &status("Module: Loading $mod...");

    delete $INC{$file};
    eval "require \"$file\"";    # require or use?
    if (@$) {
        &DEBUG("rM: failure: @$ ");
    }
    else {
        my $basename = $file;
        $basename =~ s/^.*\///;
        &status("Module: reloaded $basename");
        $retval = " $basename";
        $moduleAge{$file} = $age;
    }
    return $retval;
}

###
### OPTIONAL MODULES.
###

my %perlModulesLoaded  = ();
my %perlModulesMissing = ();

sub loadPerlModule {
    return 0 if ( exists $perlModulesMissing{ $_[0] } );
    &reloadModule( $_[0] );
    return 1 if ( exists $perlModulesLoaded{ $_[0] } );

    eval "use $_[0]";
    if ($@) {
        &WARN("Module: $_[0] is not installed!");
        $perlModulesMissing{ $_[0] } = 1;
        return 0;
    }
    else {
        $perlModulesLoaded{ $_[0] } = 1;
        &status("Loaded $_[0]");
        &showProc(" ($_[0])");
        return 1;
    }
}

sub loadMyModule {
    my ($modulename) = @_;
    if ( !defined $modulename ) {
        &WARN('loadMyModule: module is NULL.');
        return 0;
    }

    my $modulefile = "$bot_src_dir/Modules/$modulename.pl";

    # call reloadModule() which checks age of file and reload.
    if ( grep /\/$modulename$/, keys %INC ) {
        &reloadModule($modulename);
        return 1;    # depend on reloadModule?
    }

    if ( !-f $modulefile ) {
        &ERROR("lMM: module ($modulename) does not exist.");
        if ( $$ == $bot_pid ) {    # parent.
            &shutdown() if ( defined $shm and defined $dbh );
        }
        else {                     # child.
            &DEBUG('b4 delfork 1');
            &delForked($modulename);
        }

        exit 1;
    }

    eval "require \"$modulefile\"";
    if ($@) {
        &ERROR("cannot load my module: $modulename");
        if ( $bot_pid != $$ ) {    # child.
            &DEBUG('b4 delfork 2');
            &delForked($modulename);
            exit 1;
        }

        return 0;
    }
    else {
        $moduleAge{$modulefile} = ( stat $modulefile )[9];

        &status("Loaded $modulename");
        &showProc(" ($modulename)");
        return 1;
    }
}

$no_timehires = 0;
eval 'use Time::HiRes qw(gettimeofday tv_interval)';
if ($@) {
    &WARN('No Time::HiRes?');
    $no_timehires = 1;
}
&showProc(' (Time::HiRes)');

sub AUTOLOAD {
    if ( !defined $AUTOLOAD and defined $::AUTOLOAD ) {
        &DEBUG('AUTOLOAD: hrm.. ::AUTOLOAD defined!');
    }
    return unless ( defined $AUTOLOAD );
    return if ( $AUTOLOAD =~ /__/ );    # internal.

    my $str = join( ', ', @_ );
    my ( $package, $filename, $line ) = caller;
    &ERROR("UNKNOWN FUNCTION CALLED: $AUTOLOAD ($str) $filename line $line");

    $AUTOLOAD =~ s/^(\S+):://g;

    # hopefully this will work.
    &DEBUG("Trying to load module $AUTOLOAD...");
    &loadMyModule($AUTOLOAD);
}

sub getPerlFiles {
    my ($dir) = @_;

    if ( !opendir( DIR, $dir ) ) {
        &ERROR("Cannot open source directory ($dir): $!");
        exit 1;
    }

    my @mods;
    while ( defined( my $file = readdir DIR ) ) {
        next unless $file =~ /\.pl$/;
        next unless $file =~ /^[A-Z]/;
        push( @mods, $file );
    }
    closedir DIR;

    return reverse sort @mods;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
