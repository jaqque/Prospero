#
#   Misc.pl: Miscellaneous stuff.
#    Author: dms
#   Version: 20000124
#      NOTE: Based on code by Kevin Lenzo & Patrick Cole  (c) 1997
#

use strict;

use vars qw(%file %mask %param %cmdstats %myModules);
use vars qw($msgType $who $bot_pid $nuh $shm $force_public_reply
  $no_timehires $bot_data_dir $addrchar);

sub help {
    my $topic = shift;
    my $file  = $bot_data_dir . '/infobot.help';
    my %help  = ();

    # crude hack for performStrictReply() to work as expected.
    $msgType = 'private' if ( $msgType eq 'public' );

    if ( !open( FILE, $file ) ) {
        &ERROR("Failed reading help file ($file): $!");
        return;
    }

    while ( defined( my $help = <FILE> ) ) {
        $help =~ s/^[\# ].*//;
        chomp $help;
        next unless $help;
        my ( $key, $val ) = split( /:/, $help, 2 );

        $val =~ s/^\s+//;
        $val =~ s/^D:/\002   Desc\002:/;
        $val =~ s/^E:/\002Example\002:/;
        $val =~ s/^N:/\002   NOTE\002:/;
        $val =~ s/^U:/\002  Usage\002:/;
        $val =~ s/##/$key/;
        $val =~ s/__/\037/g;
        $val =~ s/==/        /;

        $help{$key} = '' if ( !exists $help{$key} );
        $help{$key} .= $val . "\n";
    }
    close FILE;

    if ( !defined $topic or $topic eq '' ) {
        &msg( $who, $help{'main'} );

        my $i = 0;
        my @array;
        my $count = scalar( keys %help );
        my $reply;
        foreach ( sort keys %help ) {
            push( @array, $_ );
            $reply =
              scalar(@array) . ' topics: ' . join( "\002,\002 ", @array );
            $i++;

            if ( length $reply > 400 or $count == $i ) {
                &msg( $who, $reply );
                undef @array;
            }
        }

        return '';
    }

    $topic = &fixString( lc $topic );

    if ( exists $help{$topic} ) {
        foreach ( split /\n/, $help{$topic} ) {
            &performStrictReply($_);
        }
    }
    else {
        &performStrictReply(
            "no help on $topic.  Use 'help' without arguments.");
    }

    return '';
}

sub getPath {
    my ($pathnfile) = @_;

    ### TODO: gotta hate an if statement.
    if ( $pathnfile =~ /(.*)\/(.*?)$/ ) {
        return $1;
    }
    else {
        return '.';
    }
}

sub timeget {
    if ($no_timehires) {    # fallback.
        return time();
    }
    else {                  # the real thing.
        return [ gettimeofday() ];
    }
}

sub timedelta {
    my ($start_time) = shift;

    if ($no_timehires) {    # fallback.
        return time() - $start_time;
    }
    else {                  # the real thing.
        return tv_interval($start_time);
    }
}

###
### FORM Functions.
###

###
# Usage; &formListReply($rand, $prefix, @list);
sub formListReply {
    my ( $rand, $prefix, @list ) = @_;
    my $total   = scalar @list;
    my $maxshow = &getChanConfDefault( 'maxListReplyCount', 15, $chan );
    my $maxlen  = &getChanConfDefault( 'maxListReplyLength', 400, $chan );
    my $reply;

    # remove irc overhead
    $maxlen -= 30;

    # no results.
    return $prefix . 'returned no results.' unless ($total);

    # random.
    if ($rand) {
        my @rand;
        foreach ( &makeRandom($total) ) {
            push( @rand, $list[$_] );
            last if ( scalar @rand == $maxshow );
        }
        if ( $total > $maxshow ) {
            @list = sort @rand;
        }
        else {
            @list = @rand;
        }
    }
    elsif ( $total > $maxshow ) {
        &status('formListReply: truncating list.');

        @list = @list[ 0 .. $maxshow - 1 ];
    }

    # form the reply.
    # FIXME: should grow and exit when full, not discard any that are oversize
    while () {
        $reply = $prefix . "(\002" . scalar(@list) . "\002";
        $reply .= " of \002$total\002" if ( $total != scalar @list );
        $reply .= '): ' . join( " \002;;\002 ", @list ) . '.';

        last if ( length($reply) < $maxlen and scalar(@list) <= $maxshow );
        last if ( scalar(@list) == 1 );

        pop @list;
    }

    return $reply;
}

### Intelligence joining of arrays.
# Usage: &IJoin(@array);
sub IJoin {
    if ( !scalar @_ ) {
        return 'NULL';
    }
    elsif ( scalar @_ == 1 ) {
        return $_[0];
    }
    else {
        return join( ', ', @{_}[ 0 .. $#_ - 1 ] ) . " and $_[$#_]";
    }
}

#####
# Usage: &Time2String(seconds);
sub Time2String {
    my ($time) = @_;
    my $prefix = '';
    my ( @s, @t );

    return 'NULL' if ( !defined $time );
    return $time  if ( $time !~ /\d+/ );

    if ( $time < 0 ) {
        $time   = -$time;
        $prefix = '- ';
    }

    $t[0] = int($time) % 60;
    $t[1] = int( $time / 60 ) % 60;
    $t[2] = int( $time / 3600 ) % 24;
    $t[3] = int( $time / 86400 );

    push( @s, "$t[3]d" ) if ( $t[3] != 0 );
    push( @s, "$t[2]h" ) if ( $t[2] != 0 );
    push( @s, "$t[1]m" ) if ( $t[1] != 0 );
    push( @s, "$t[0]s" ) if ( $t[0] != 0 or !@s );

    my $retval = $prefix . join( ' ', @s );
    $retval =~ s/(\d+)/\002$1\002/g;
    return $retval;
}

###
### FIX Functions.
###

# Usage: &fixFileList(@files);
sub fixFileList {
    my @files = @_;
    my %files;

    # generate a hash list.
    foreach (@files) {
        next unless /^(.*\/)(.*?)$/;

        $files{$1}{$2} = 1;
    }
    @files = ();    # reuse the array.

    # sort the hash list appropriately.
    foreach ( sort keys %files ) {
        my $file = $_;
        my @keys = sort keys %{ $files{$file} };
        my $i    = scalar(@keys);

        if ( scalar @keys > 3 ) {
            pop @keys while ( scalar @keys > 3 );
            push( @keys, '...' );
        }

        if ( $i > 1 ) {
            $file .= "\002{\002" . join( "\002|\002", @keys ) . "\002}\002";
        }
        else {
            $file .= $keys[0];
        }

        push( @files, $file );
    }

    return @files;
}

# Usage: &fixString($str);
sub fixString {
    my ( $str, $level ) = @_;
    if ( !defined $str ) {
        &WARN('fixString: str == NULL.');
        return '';
    }

    for ($str) {
        s/^\s+//;     # remove start whitespaces.
        s/\s+$//;     # remove end whitespaces.
        s/\s+/ /g;    # remove excessive whitespaces.

        next unless ( defined $level );
        if (s/[\cA-\c_]//ig) {    # remove control characters.
            &DEBUG('stripped control chars');
        }
    }

    return $str;
}

# Usage: &fixPlural($str,$int);
sub fixPlural {
    my ( $str, $int ) = @_;

    if ( !defined $str ) {
        &WARN('fixPlural: str == NULL.');
        return;
    }

    if ( !defined $int or $int =~ /^\D+$/ ) {
        &WARN('fixPlural: int != defined or int');
        return $str;
    }

    if ( $str eq 'has' ) {
        $str = 'have' if ( $int > 1 );
    }
    elsif ( $str eq 'is' ) {
        $str = 'are' if ( $int > 1 );
    }
    elsif ( $str eq 'was' ) {
        $str = 'were' if ( $int > 1 );
    }
    elsif ( $str eq 'this' ) {
        $str = 'these' if ( $int > 1 );
    }
    elsif ( $str =~ /y$/ ) {
        if ( $int > 1 ) {
            if ( $str =~ /ey$/ ) {
                $str .= 's';    # eg: 'money' => 'moneys'.
            }
            else {
                $str =~ s/y$/ies/;
            }
        }
    }
    else {
        $str .= 's' if ( $int != 1 );
    }

    return $str;
}

##########
### get commands.
###

sub getRandomLineFromFile {
    my ($file) = @_;

    if ( !open( IN, $file ) ) {
        &WARN("gRLfF: could not open ($file): $!");
        return;
    }

    my @lines = <IN>;
    close IN;

    if ( !scalar @lines ) {
        &ERROR('GRLF: nothing loaded?');
        return;
    }

    # could we use the filehandler instead and put it through getRandom?
    while ( my $line = &getRandom(@lines) ) {
        chop $line;

        next if ( $line =~ /^\#/ );
        next if ( $line =~ /^\s*$/ );

        return $line;
    }
}

sub getLineFromFile {
    my ( $file, $lineno ) = @_;

    if ( !-f $file ) {
        &ERROR("getLineFromFile: file '$file' does not exist.");
        return 0;
    }

    if ( open( IN, $file ) ) {
        my @lines = <IN>;
        close IN;

        if ( $lineno > scalar @lines ) {
            &ERROR('getLineFromFile: lineno exceeds line count from file.');
            return 0;
        }

        my $line = $lines[ $lineno - 1 ];
        chop $line;
        return $line;
    }
    else {
        &ERROR("gLFF: Could not open file ($file): $!");
        return 0;
    }
}

# Usage: &getRandom(@array);
sub getRandom {
    my @array = @_;

    srand();
    return $array[ int( rand( scalar @array ) ) ];
}

# Usage: &getRandomInt('30-60'); &getRandomInt(5);
# Desc : Returns a randomn integer between 'X-Y' or 1 and the value passed
sub getRandomInt {
    my $str = shift;

    if ( !defined $str ) {
        &WARN('getRandomInt: str == NULL.');
        return undef;
    }

    if ( $str =~ /^(\d+(\.\d+)?)$/ ) {
        return int( rand $str ) + 1;
    }
    elsif ( $str =~ /^(\d+)-(\d+)$/ ) {
        return $1 if $1 == $2;
        my $min = $1 < $2 ? $1 : $2;    # Swap is backwords
        my $max = $2 > $1 ? $2 : $1;
        return int( rand( $max - $min + 1 ) ) + $min;
    }
    else {

        # &ERROR("getRandomInt: invalid arg '$str'.");
        return undef;
    }
}

##########
### Is commands.
###

sub iseq {
    my ( $left, $right ) = @_;
    return 0 unless defined $right;
    return 0 unless defined $left;
    return 1 if ( $left =~ /^\Q$right$/i );
}

sub isne {
    my $retval = &iseq(@_);
    return 1 unless ($retval);
    return 0;
}

# Usage: &IsHostMatch($nuh);
sub IsHostMatch {
    my ($thisnuh) = @_;
    my ( %this, %local );

    if ( $nuh =~ /^(\S+)!(\S+)@(\S+)/ ) {
        $local{'nick'} = lc $1;
        $local{'user'} = lc $2;
        $local{'host'} = &makeHostMask( lc $3 );
    }

    if ( !defined $thisnuh ) {
        &WARN('IHM: thisnuh == NULL.');
        return 0;
    }
    elsif ( $thisnuh =~ /^(\S+)!(\S+)@(\S+)/ ) {
        $this{'nick'} = lc $1;
        $this{'user'} = lc $2;
        $this{'host'} = &makeHostMask( lc $3 );
    }
    else {
        &WARN("IHM: thisnuh is invalid '$thisnuh'.");
        return 1 if ( $thisnuh eq '' );
        return 0;
    }

    # auth if 1) user and host match 2) user and nick match.
    # this may change in the future.

    if ( $this{'user'} =~ /^\Q$local{'user'}\E$/i ) {
        return 2 if ( $this{'host'} eq $local{'host'} );
        return 1 if ( $this{'nick'} eq $local{'nick'} );
    }
    return 0;
}

####
# Usage: &isStale($file, $age);
sub isStale {
    my ( $file, $age ) = @_;

    if ( !defined $age ) {
        &WARN('isStale: age == NULL.');
        return 1;
    }

    if ( !defined $file ) {
        &WARN('isStale: file == NULL.');
        return 1;
    }

    &DEBUG("!exist $file") if ( !-f $file );

    return 1 unless ( -f $file );
    if ( $file =~ /idx/ ) {
        my $age2 = time() - ( stat($file) )[9];
        &VERB( "stale: $age2. (" . &Time2String($age2) . ')', 2 );
    }
    $age *= 60 * 60 * 24 if ( $age >= 0 and $age < 30 );

    return 1 if ( time() - ( stat($file) )[9] > $age );
    return 0;
}

sub isFileUpdated {
    my ( $file, $time ) = @_;

    if ( !-f $file ) {
        return 1;
    }

    my $time_file = ( stat $file )[9];

    if ( $time <= $time_file ) {
        return 0;
    }
    else {
        return 1;
    }
}

##########
### make commands.
###

# Usage: &makeHostMask($host);
sub makeHostMask {
    my ($host) = @_;
    my $nu = '';

    if ( $host =~ s/^(\S+!\S+\@)// ) {
        &DEBUG("mHM: detected nick!user\@ for host arg; fixing");
        &DEBUG("nu => $nu");
        $nu = $1;
    }

    if ( $host =~ /^$mask{ip}$/ ) {
        return $nu . "$1.$2.$3.*";
    }

    my @array = split( /\./, $host );
    return $nu . $host if ( scalar @array <= 3 );
    return $nu . '*.' . join( '.', @{array}[ 1 .. $#array ] );
}

# Usage: &makeRandom(int);
sub makeRandom {
    my ($max) = @_;
    my @retval;
    my %done;

    if ( $max =~ /^\D+$/ ) {
        &ERROR("makeRandom: arg ($max) is not integer.");
        return 0;
    }

    if ( $max < 1 ) {
        &ERROR("makeRandom: arg ($max) is not positive.");
        return 0;
    }

    srand();
    while ( scalar keys %done < $max ) {
        my $rand = int( rand $max );
        next if ( exists $done{$rand} );

        push( @retval, $rand );
        $done{$rand} = 1;
    }

    return @retval;
}

sub checkMsgType {
    my ($reply) = @_;
    return unless ( &IsParam('minLengthBeforePrivate') );
    return if ($force_public_reply);

    if ( length $reply > $param{'minLengthBeforePrivate'} ) {
        &status(
"Reply: len reply > minLBP ($param{'minLengthBeforePrivate'}); msgType now private."
        );
        $msgType = 'private';
    }
}

###
### Valid.
###

# Usage: &validExec($string);
sub validExec {
    my ($str) = @_;

    if ( $str =~ /[\`\'\"\|]/ ) {    # invalid.
        return 0;
    }
    else {                           # valid.
        return 1;
    }
}

# Usage: &hasProfanity($string);
sub hasProfanity {
    my ($string) = @_;
    my $profanity = 1;

    for ( lc $string ) {
        /fuck/                and last;
        /dick|dildo/          and last;
        /shit/                and last;
        /pussy|[ck]unt/       and last;
        /wh[0o]re|bitch|slut/ and last;

        $profanity = 0;
    }

    return $profanity;
}

sub IsChanConfOrWarn {
    my ($param) = @_;

    if ( &IsChanConf($param) > 0 ) {
        return 1;
    }
    else {
        ### TODO: specific reason why it failed.
        &msg( $who,
            "unfortunately, \002$param\002 is disabled in my configuration" )
          unless ($addrchar);
        return 0;
    }
}

sub Forker {
    my ( $label, $code ) = @_;
    my $pid;

    &shmFlush();
    &VERB( 'double fork detected; not forking.', 2 ) if ( $$ != $bot_pid );

    if ( &IsParam('forking') and $$ == $bot_pid ) {
        return unless &addForked($label);

        $SIG{CHLD} = 'IGNORE';
        $pid = eval { fork() };
        return if $pid;    # parent does nothing

        select( undef, undef, undef, 0.2 );

        #	&status("fork starting for '$label', PID == $$.");
        &status(
            "--- fork starting for '$label', PID == $$, bot_pid == $bot_pid ---"
        );
        &shmWrite( $shm, "SET FORKPID $label $$" );

        sleep 1;
    }

    ### TODO: use AUTOLOAD
    ### very lame hack.
    if ( $label !~ /-/ and !&loadMyModule($label) ) {
        &DEBUG('Forker: failed?');
        &delForked($label);
    }

    if ( defined $code ) {
        $code->();    # weird, hey?
    }
    else {
        &WARN('Forker: code not defined!');
    }

    &delForked($label);
}

sub closePID {
    return 1 unless ( exists $file{PID} );
    return 1 unless ( -f $file{PID} );
    return 1 if ( unlink $file{PID} );
    return 0 if ( -f $file{PID} );
}

sub mkcrypt {
    my ($str) = @_;
    my $salt = join '',
      ( '.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z' )[ rand 64, rand 64 ];

    return crypt( $str, $salt );
}

sub closeStats {
    return unless ( &getChanConfList('ircTextCounters') );

    foreach ( keys %cmdstats ) {
        my $type = $_;
        my $i    = &sqlSelect(
            'stats',
            'counter',
            {
                nick => $type,
                type => 'cmdstats',
            }
        );
        my $z = 0;
        $z++ unless ($i);

        $i += $cmdstats{$type};

        &sqlSet(
            'stats',
            { 'nick' => $type },
            {
                type    => 'cmdstats',
                'time'  => time(),
                counter => $i,
            }
        );
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
