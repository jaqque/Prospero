#
#   core.pl: Important functions stuff...
#    Author: dms
#   Version: v0.4 (20000718)
#   Created: 20000322
#

use strict;

# scalar. MUST BE REDUCED IN SIZE!!!
### TODO: reorder.
use vars qw(
  $bot_misc_dir $bot_pid $bot_base_dir $bot_src_dir
  $bot_data_dir $bot_config_dir $bot_state_dir $bot_run_dir
  $answer $correction_plausible $talkchannel $bot_release
  $statcount $memusage $user $memusageOld $bot_version $dbh
  $shm $host $msg $noreply $conn $irc $learnok $nick $ident
  $force_public_reply $addrchar $userHandle $addressedother
  $floodwho $chan $msgtime $server $firsttime $wingaterun
  $flag_quit $msgType $no_syscall
  $utime_userfile	$wtime_userfile	$ucount_userfile
  $utime_chanfile	$wtime_chanfile	$ucount_chanfile
  $pubsize $pubcount $pubtime
  $msgsize $msgcount $msgtime
  $notsize $notcount $nottime
  $running
);

# array.
use vars qw(@ircServers @wingateBad @wingateNow @wingateCache
);

### hash. MUST BE REDUCED IN SIZE!!!
#
use vars qw(%count %netsplit %netsplitservers %flood %dcc %orig
  %nuh %talkWho %seen %floodwarn %param %dbh %ircPort
  %topic %moduleAge %last %time %mask %file
  %forked %chanconf %channels %cache
);

# Signals.
$SIG{'HUP'}      = 'restart';    #  1.
$SIG{'INT'}      = 'doExit';     #  2.
$SIG{'KILL'}     = 'doExit';     #  9. DOES NOT WORK. 'man perlipc' for details.
$SIG{'TERM'}     = 'doExit';     # 15.
$SIG{'__WARN__'} = 'doWarn';

# initialize variables.
$last{buflen}    = 0;
$last{say}       = '';
$last{msg}       = '';
$userHandle      = '_default';
$wingaterun      = time();
$firsttime       = 1;
$utime_userfile  = 0;
$wtime_userfile  = 0;
$ucount_userfile = 0;
$utime_chanfile  = 0;
$wtime_chanfile  = 0;
$ucount_chanfile = 0;
$running         = 0;

### more variables...

# static scalar variables.
$mask{ip}   = '(\d+)\.(\d+)\.(\d+)\.(\d+)';
$mask{host} = '[\d\w\_\-\/]+\.[\.\d\w\_\-\/]+';
$mask{chan} = '[\#\&]\S*|_default';
my $isnick1 = 'a-zA-Z\[\]\{\}\_\`\^\|\\\\';
my $isnick2 = '0-9\-';
$mask{nick} = "[$isnick1]{1}[$isnick1$isnick2]*";
$mask{nuh}  = '\S*!\S*\@\S*';
$msgtime    = time();
$msgsize    = 0;
$msgcount   = 0;
$pubtime    = 0;
$pubsize    = 0;
$pubcount   = 0;
$nottime    = 0;
$notsize    = 0;
$notcount   = 0;

###

open( VERSION, '<VERSION' );
$bot_release = <VERSION> || '(unknown version)';
chomp($bot_release);
close(VERSION);
$bot_version = "infobot $bot_release -- $^O";
$noreply     = 'NOREPLY';

##########
### misc commands.
###

sub whatInterface {
    if ( !&IsParam('Interface') or $param{'Interface'} =~ /IRC/ ) {
        return 'IRC';
    }
    else {
        return 'CLI';
    }
}

sub doExit {
    my ($sig) = @_;

    if ( defined $flag_quit ) {
        &WARN('doExit: quit already called.');
        return;
    }
    $flag_quit = 1;

    if ( !defined $bot_pid ) {    # independent.
        exit 0;
    }
    elsif ( $bot_pid == $$ ) {    # parent.
        &status("parent caught SIG$sig (pid $$).") if ( defined $sig );

        &status('--- Start of quit.');
        $ident ||= 'infobot';     # lame hack.

        &status("Memory Usage: $memusage KiB");

        &closePID();
        &closeStats();

        # shutdown IRC and related components.
        if ( &whatInterface() =~ /IRC/ ) {
            &closeDCC();
            &seenFlush();
            &quit( $param{'quitMsg'} );
        }
        &writeUserFile();
        &writeChanFile();
        &uptimeWriteFile() if ( &IsParam('Uptime') );
        &sqlCloseDB();
        &closeSHM($shm);

        if ( &IsParam('dumpvarsAtExit') ) {
            &loadMyModule('DumpVars');
            &dumpallvars();
        }
        &symdumpAll() if ( &IsParam('symdumpAtExit') );
        &closeLog();
        &closeSQLDebug() if ( &IsParam('SQLDebug') );

        &status('--- QUIT.');
    }
    else {    # child.
        &status("child caught SIG$sig (pid $$).");
    }

    exit 0;
}

sub doWarn {
    $SIG{__WARN__} = sub { warn $_[0]; };

    foreach (@_) {
        &WARN("PERL: $_");
    }

    $SIG{__WARN__} = 'doWarn';    # ???
}

# Usage: &IsParam($param);
# infobot.config specific.
sub IsParam {
    my $param = $_[0];

    return 0 unless ( defined $param );
    return 0 unless ( exists $param{$param} );
    return 0 unless ( $param{$param} );
    return 0 if $param{$param} =~ /^false$/i;
    return 1;
}

#####
#  Usage: &ChanConfList($param)
#  About: gets channels with 'param' enabled. (!!!)
# Return: array of channels
sub ChanConfList {
    my $param = $_[0];
    return unless ( defined $param );
    my %chan = &getChanConfList($param);

    if ( exists $chan{_default} ) {
        return keys %chanconf;
    }
    else {
        return keys %chan;
    }
}

#####
#  Usage: &getChanConfList($param)
#  About: gets channels with 'param' enabled, internal use only.
# Return: hash of channels
sub getChanConfList {
    my $param = $_[0];
    my %chan;

    return unless ( defined $param );

    foreach ( keys %chanconf ) {
        my $chan = $_;
        my @array = grep /^$param$/, keys %{ $chanconf{$chan} };

#&DEBUG("gCCL param => $param, chan => $chan, keys => " . join(':',keys %{ $chanconf{$chan} }) . ' array => ' . join(':', @array)) if ($param eq 'whatever');

        next unless ( scalar @array );

        if ( scalar @array > 1 ) {
            &WARN('multiple items found?');
        }

        if ( $chanconf{$chan}{$param} eq '0' ) {
            $chan{$chan} = -1;
        }
        else {
            $chan{$chan} = 1;
        }
    }

    return %chan;
}

#####
#  Usage: &IsChanConf($param);
#  About: Check for 'param' on the basis of channel config.
# Return: 1 for enabled, 0 for passive disable, -1 for active disable.
sub IsChanConf {
    my ($param) = shift;

    # knocked tons of bugs with this! :)
    my $debug = 0;    # 1 if ($param eq 'whatever');

    if ( !defined $param ) {
        &WARN('IsChanConf: param == NULL.');
        return 0;
    }

    # these should get moved to your .chan file instead of the .config
    # .config items overide any .chan entries
    if ( &IsParam($param) ) {
        &WARN("ICC: found '$param' option in main config file.");
        return 1;
    }

    $chan ||= '_default';

    my $old = $chan;
    if ( $chan =~ tr/A-Z/a-z/ ) {
        &WARN("IsChanConf: lowercased chan. ($old)");
    }

    ### TODO: VERBOSITY on how chanconf returned 1 or 0 or -1.
    my %chan    = &getChanConfList($param);
    my $nomatch = 0;
    if ( !defined $msgType ) {
        $nomatch++;
    }
    else {
        $nomatch++ if ( $msgType eq '' );
        $nomatch++ unless ( $msgType =~ /^(public|private)$/i );
    }

## Please see file perltidy.ERR
### debug purposes only.
    #    if ($debug) {
    #	&DEBUG("param => $param, msgType => $msgType.");
    #	foreach (keys %chan) {
    #	    &DEBUG("   $_ => $chan{$_}");
    #	}
    #    }

    if ($nomatch) {
        if ( $chan{$chan} ) {
            &DEBUG("ICC: other: $chan{$chan} (_default/$param)") if ($debug);
        }
        elsif ( $chan{_default} ) {
            &DEBUG("ICC: other: $chan{_default} (_default/$param)") if ($debug);
        }
        else {
            &DEBUG("ICC: other: 0 ($param)") if ($debug);
        }
        return $chan{$chan} || $chan{_default} || 0;
    }
    elsif ( $msgType =~ /^(public|private)$/i ) {
        if ( $chan{$chan} ) {
            &DEBUG("ICC: $msgType: $chan{$chan} ($chan/$param)") if ($debug);
        }
        elsif ( $chan{_default} ) {
            &DEBUG("ICC: $msgType: $chan{_default} (_default/$param)")
              if ($debug);
        }
        else {
            &DEBUG("ICC: $msgType: 0 ($param)") if ($debug);
        }
        return $chan{$chan} || $chan{_default} || 0;
    }

    &DEBUG("ICC: no-match: 0/$param (msgType = $msgType)");

    return 0;
}

#####
#  Usage: &getChanConf($param);
#  About: Retrieve value for 'param' value in current/default chan.
# Return: scalar for success, undef for failure.
sub getChanConf {
    my ( $param, $c ) = @_;

    if ( !defined $param ) {
        &WARN('gCC: param == NULL.');
        return 0;
    }

    # this looks evil...
    if ( 0 and !defined $chan ) {
        &DEBUG('gCC: ok !chan... doing _default instead.');
    }

    $c ||= $chan;
    $c ||= '_default';
    $c = '_default' if ( $c eq '*' );    # FIXME
    my @c = grep /^\Q$c\E$/i, keys %chanconf;

    if (@c) {
        if ( 0 and $c[0] ne $c ) {
            &WARN("c ne chan ($c[0] ne $chan)");
        }
        if ( !defined $chanconf{ $c[0] }{$param} and ( $c ne '_default' ) ) {
            return &getChanConf( $param, '_default' );
        }
        &DEBUG( "gCC: $param,$c \"" . $chanconf{ $c[0] }{$param} . '"' );
        return $chanconf{ $c[0] }{$param};
    }

    #&DEBUG('gCC: returning _default... ' . $chanconf{'_default'}{$param});
    return $chanconf{'_default'}{$param};
}

sub getChanConfDefault {
    my ( $what, $default, $chan ) = @_;
    $chan ||= '_default';

    if ( exists $param{$what} ) {
        if ( !exists $cache{config}{$what} ) {
            &status(
"config ($chan): backward-compatible option: found param{$what} ($param{$what}) instead of chan option"
            );
            $cache{config}{$what} = 1;
        }

        return $param{$what};
    }
    my $val = &getChanConf( $what, $chan );
    return $val if ( defined $val );

    $param{$what} = $default;
    &status("config ($chan): auto-setting param{$what} = $default");
    $cache{config}{$what} = 1;
    return $default;
}

#####
#  Usage: &findChanConf($param);
#  About: Retrieve value for 'param' value from any chan.
# Return: scalar for success, undef for failure.
sub findChanConf {
    my ($param) = @_;

    if ( !defined $param ) {
        &WARN('param == NULL.');
        return 0;
    }

    my $c;
    foreach $c ( keys %chanconf ) {
        foreach ( keys %{ $chanconf{$c} } ) {
            next unless (/^$param$/);

            return $chanconf{$c}{$_};
        }
    }

    return;
}

sub showProc {
    my ($prefix) = $_[0] || '';

    if ( $^O eq 'linux' ) {
        if ( !open( IN, "/proc/$$/status" ) ) {
            &ERROR("cannot open '/proc/$$/status'.");
            return;
        }

        while (<IN>) {
            $memusage = $1 if (/^VmSize:\s+(\d+) kB/);
        }
        close IN;

    }
    elsif ( $^O eq 'netbsd' ) {
        $memusage = int( ( stat "/proc/$$/mem" )[7] / 1024 );

    }
    elsif ( $^O =~ /^(free|open)bsd$/ ) {
        my @info = split /\s+/, `/bin/ps -l -p $$`;
        $memusage = $info[20];

    }
    else {
        $memusage = 'UNKNOWN';
        return;
    }

    if ( defined $memusageOld and &IsParam('DEBUG') ) {

        # it's always going to be increase.
        my $delta = $memusage - $memusageOld;
        my $str;
        if ( $delta == 0 ) {
            return;
        }
        elsif ( $delta > 500 ) {
            $str =
              "MEM:$prefix increased by $delta KiB. (total: $memusage KiB)";
        }
        elsif ( $delta > 0 ) {
            $str = "MEM:$prefix increased by $delta KiB";
        }
        else {    # delta < 0.
            $delta = -$delta;

            # never knew RSS could decrease, probably Size can't?
            $str = "MEM:$prefix decreased by $delta KiB.";
        }

        &status($str);
    }
    $memusageOld = $memusage;
}

######
###### SETUP
######

sub setup {
    &showProc(" (\&openLog before)");
    &openLog();    # write, append.
    &status('--- Started logging.');

    # read.
    &loadLang( $bot_data_dir . '/infobot.lang' );
    &loadIRCServers();
    &readUserFile();
    &readChanFile();
    &loadMyModulesNow();    # must be after chan file.

    $shm = &openSHM();
    &openSQLDebug() if ( &IsParam('SQLDebug') );
    &sqlOpenDB(
        $param{'DBName'},  $param{'DBType'},
        $param{'SQLUser'}, $param{'SQLPass'}
    );
    &checkTables();

    &status( 'Setup: ' . &countKeys('factoids') . ' factoids.' );
    &getChanConfDefault( 'sendPrivateLimitLines', 3,    $chan );
    &getChanConfDefault( 'sendPrivateLimitBytes', 1000, $chan );
    &getChanConfDefault( 'sendPublicLimitLines',  3,    $chan );
    &getChanConfDefault( 'sendPublicLimitBytes',  1000, $chan );
    &getChanConfDefault( 'sendNoticeLimitLines',  3,    $chan );
    &getChanConfDefault( 'sendNoticeLimitBytes',  1000, $chan );

    $param{tempDir} =~ s#\~/#$ENV{HOME}/#;

    &status("Initial memory usage: $memusage KiB");
    &status('-------------------------------------------------------');
}

sub setupConfig {
    $param{'VERBOSITY'} = 1;
    &loadConfig( $bot_config_dir . '/infobot.config' );

    foreach (qw(ircNick ircUser ircName DBType tempDir)) {
        next if &IsParam($_);
        &ERROR("Parameter $_ has not been defined.");
        exit 1;
    }

    if ( $param{tempDir} =~ s#\~/#$ENV{HOME}/# ) {
        &VERB( 'Fixing up tempDir.', 2 );
    }

    if ( $param{tempDir} =~ /~/ ) {
        &ERROR('parameter tempDir still contains tilde.');
        exit 1;
    }

    if ( !-d $param{tempDir} ) {
        &status("making $param{tempDir}...");
        mkdir $param{tempDir}, 0755;
    }

    # static scalar variables.
    $file{utm} = "$bot_state_dir/$param{'ircUser'}.uptime";
    $file{PID} = "$bot_run_dir/$param{'ircUser'}.pid";
}

sub startup {
    if ( &IsParam('DEBUG') ) {
        &status('enabling debug diagnostics.');

        # I thought disabling this reduced memory usage by 1000 KiB.
        use diagnostics;
    }

    $count{'Question'} = 0;
    $count{'Update'}   = 0;
    $count{'Dunno'}    = 0;
    $count{'Moron'}    = 0;
}

sub shutdown {
    my ($sig) = @_;

    # reverse order of &setup().
    &status('--- shutdown called.');

    # hack.
    $ident ||= 'infobot';

    if ( !&isFileUpdated( "$bot_state_dir/infobot.users", $wtime_userfile ) ) {
        &writeUserFile();
    }

    if ( !&isFileUpdated( "$bot_state_dir/infobot.chan", $wtime_chanfile ) ) {
        &writeChanFile();
    }

    &sqlCloseDB();

    # aswell. TODO: use this in &doExit?
    &closeSHM($shm);
    &closeLog();
}

sub restart {
    my ($sig) = @_;

    if ( $$ == $bot_pid ) {
        &status("--- $sig called.");

        ### crappy bug in Net::IRC?
        my $delta = time() - $msgtime;
        &DEBUG("restart: dtime = $delta");
        if ( !$conn->connected or time() - $msgtime > 900 ) {
            &status( "reconnecting because of uncaught disconnect \@ "
                  . scalar(gmtime) );
###	    $irc->start;
            &clearIRCVars();
            $conn->connect();
###	    return;
        }

        &ircCheck();    # heh, evil!

        &DCCBroadcast( '-HUP called.', 'm' );
        &shutdown($sig);
        &loadConfig( $bot_config_dir . '/infobot.config' );
        &reloadAllModules() if ( &IsParam('DEBUG') );
        &setup();

        &status("--- End of $sig.");
    }
    else {
        &status("$sig called; ignoring restart.");
    }
}

# File: Configuration.
sub loadConfig {
    my ($file) = @_;

    if ( !open( FILE, $file ) ) {
        &ERROR("Failed to read configuration file ($file): $!");
        &status(
'Please read the INSTALL file on how to install and setup this file.'
        );
        exit 0;
    }

    my $count = 0;
    while (<FILE>) {
        chomp;
        next if /^\s*\#/;
        next unless /\S/;
        my ( $set, $key, $val ) = split( /\s+/, $_, 3 );

        if ( $set ne 'set' ) {
            &status("loadConfig: invalid line '$_'.");
            next;
        }

        # perform variable interpolation
        $val =~ s/(\$(\w+))/$param{$2}/g;

        $param{$key} = $val;

        ++$count;
    }
    close FILE;

    $file =~ s/^.*\///;
    &status("Loaded config $file ($count items)");
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
