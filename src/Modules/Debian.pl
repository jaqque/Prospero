#
#   Debian.pl: Frontend to debian contents and packages files
#      Author: dms
#     Version: v0.8 (20000918)
#     Created: 20000106
#


# XXX Add uploader field support

package Debian;

use strict;
no strict 'refs';    # FIXME: dstats aborts if set

my $announce    = 0;
my $defaultdist = 'sid';
my $refresh =
  &::getChanConfDefault( 'debianRefreshInterval', 7, $::chan ) * 60 * 60 * 24;
my $debug      = 0;
my $debian_dir = $::bot_state_dir . '/debian';
my $country  = 'nl';     # well .config it yourself then. ;-)
my $protocol = 'http';

# EDIT THIS (i386, amd64, powerpc, [etc.]):
my $arch = "i386";

# format: "alias=real".
my %dists = (
    'unstable'     => 'sid',
    'testing'      => 'lenny',
    'stable'       => 'etch',
    'experimental' => 'experimental',
    'oldstable'    => 'sarge',
    'incoming'     => 'incoming',
);

my %archived_dists = (
    woody  => 'woody',
    potato => 'potato',
    hamm   => 'hamm',
    buzz   => 'buzz',
    bo     => 'bo',
    rex    => 'rex',
    slink  => 'slink',
);

my %archiveurlcontents =
  ( "Contents-##DIST-$arch.gz" =>
        "$protocol://debian.crosslink.net/debian-archive"
      . "/dists/##DIST/Contents-$arch.gz", );

my %archiveurlpackages = (
	"Packages-##DIST-main-$arch.gz" =>
		"$protocol://debian.crosslink.net/debian-archive".
		"/dists/##DIST/main/binary-$arch/Packages.gz",
	"Packages-##DIST-contrib-$arch.gz" =>
		"$protocol://debian.crosslink.net/debian-archive".
		"/dists/##DIST/contrib/binary-$arch/Packages.gz",
	"Packages-##DIST-non-free-$arch.gz" =>
		"$protocol://debian.crosslink.net/debian-archive".
		"/dists/##DIST/non-free/binary-$arch/Packages.gz",
);

my %urlcontents = (
    "Contents-##DIST-$arch.gz" => "$protocol://ftp.$country.debian.org"
      . "/debian/dists/##DIST/Contents-$arch.gz",
    "Contents-##DIST-$arch-non-US.gz" => "$protocol://non-us.debian.org"
      . "/debian-non-US/dists/##DIST/non-US/Contents-$arch.gz",
);

my %urlpackages = (
    "Packages-##DIST-main-$arch.gz" => "$protocol://ftp.$country.debian.org"
      . "/debian/dists/##DIST/main/binary-$arch/Packages.gz",
    "Packages-##DIST-contrib-$arch.gz" => "$protocol://ftp.$country.debian.org"
      . "/debian/dists/##DIST/contrib/binary-$arch/Packages.gz",
    "Packages-##DIST-non-free-$arch.gz" => "$protocol://ftp.$country.debian.org"
      . "/debian/dists/##DIST/non-free/binary-$arch/Packages.gz",
);

#####################
### COMMON FUNCTION....
#######################

####
# Usage: &DebianDownload($dist, %hash);
sub DebianDownload {
    my ( $dist, %urls ) = @_;
    my $bad  = 0;
    my $good = 0;

    if ( !-d $debian_dir ) {
        &::status("Debian: creating debian dir.");
        mkdir( $debian_dir, 0755 );
    }

    # fe dists.
    # Download the files.
    my $file;
    foreach $file ( keys %urls ) {
        my $url = $urls{$file};
        $url  =~ s/##DIST/$dist/g;
        $file =~ s/##DIST/$dist/g;
        my $update = 0;

        if ( -f $file ) {
            my $last_refresh = ( stat $file )[9];
            $update++ if ( time() - $last_refresh > $refresh );
        }
        else {
            $update++;
        }

        next unless ($update);

        &::DEBUG("announce == $announce.") if ($debug);
        if ( $good + $bad == 0 and !$announce ) {
            &::status("Debian: Downloading files for '$dist'.");
            &::msg( $::who, "Updating debian files... please wait." );
            $announce++;
        }

        if ( exists $::debian{$url} ) {
            &::DEBUG( "2: " . ( time - $::debian{$url} ) . " <= $refresh" )
              if ($debug);
            next if ( time() - $::debian{$url} <= $refresh );
            &::DEBUG("stale for url $url; updating!") if ($debug);
        }

        if ( $url =~ /^ftp:\/\/(.*?)\/(\S+)\/(\S+)$/ ) {
            my ( $host, $path, $thisfile ) = ( $1, $2, $3 );

            if ( !&::ftpGet( $host, $path, $thisfile, $file ) ) {
                &::WARN("deb: down: $file == BAD.");
                $bad++;
                next;
            }

        }
        elsif ( $url =~ /^http:\/\/\S+\/\S+$/ ) {

            if ( !&::getURLAsFile( $url, $file ) ) {
                &::WARN("deb: down: http: $file == BAD.");
                $bad++;
                next;
            }

        }
        else {
            &::ERROR("Debian: invalid format of url => ($url).");
            $bad++;
            next;
        }

        if ( !-f $file ) {
            &::WARN("deb: down: http: !file");
            $bad++;
            next;
        }

        #	my $exit = system("/bin/gzip -t $file");
        #	if ($exit) {
        #	    &::WARN("deb: $file is corrupted ($exit) :/");
        #	    unlink $file;
        #	    next;
        #	}

        &::DEBUG("deb: download: good.") if ($debug);
        $good++;
    }

    # ok... lets just run this.
    &::miscCheck() if ( &::whatInterface() =~ /IRC/ );

    if ($good) {
        &generateIndex($dist);
        return 1;
    }
    else {
        return -1 unless ($bad);    # no download.
        &::DEBUG("DD: !good and bad($bad). :(");
        return 0;
    }
}

###########################
# DEBIAN CONTENTS SEARCH FUNCTIONS.
########

####
# Usage: &searchContents($query);
sub searchContents {
    my ( $dist, $query ) = &getDistroFromStr( $_[0] );
    &::status("Debian: Contents search for '$query' in '$dist'.");
    my $dccsend = 0;

    $dccsend++ if ( $query =~ s/^dcc\s+//i );

    $query =~ s/\\([\^\$])/$1/g;    # hrm?
    $query =~ s/^\s+|\s+$//g;

    if ( !&::validExec($query) ) {
        &::msg( $::who, 'search string looks fuzzy.' );
        return;
    }

    my %urls = fixDist( $dist, 'contents' );
    if ( $dist eq 'incoming' ) {    # nothing yet.
        &::DEBUG('sC: dist = "incoming". no contents yet.');
        return;
    }
    else {

        # download contents file.
        &::DEBUG('deb: download 1.') if ($debug);
        if ( !&DebianDownload( $dist, %urls ) ) {
            &::WARN('Debian: could not download files.');
        }
    }

    # start of search.
    my $start_time = &::timeget();

    my $found = 0;
    my $front = 0;
    my %contents;
    my $grepRE;
    ### TODO: search properly if /usr/bin/blah is done.
    if ( $query =~ s/\$$// ) {
        &::DEBUG("deb: search-regex found.") if ($debug);
        $grepRE = "$query\[ \t]";
    }
    elsif ( $query =~ s/^\^// ) {
        &::DEBUG("deb: front marker regex found.") if ($debug);
        $front  = 1;
        $grepRE = $query;
    }
    else {
        $grepRE = "$query*\[ \t]";
    }

    # fix up grepRE for "*".
    $grepRE =~ s/\*/.*/g;

    my @files;
    foreach ( keys %urls ) {
        next unless ( -f $_ );
        push( @files, $_ );
    }

    if ( !scalar @files ) {
        &::ERROR("sC: no files?");
        &::msg( $::who, "failed." );
        return;
    }

    my $files = join( ' ', @files );

    my $regex = $query;
    $regex =~ s/\./\\./g;
    $regex =~ s/\*/\\S*/g;
    $regex =~ s/\?/./g;

    open( IN, "zegrep -h '$grepRE' $files |" );

    # wonderful abuse of if, last, next, return, and, unless ;)
    while (<IN>) {
        last if ( $found > 100 );

        next unless (/^\.?\/?(.*?)[\t\s]+(\S+)\n$/);
        my ( $file, $package ) = ( "/" . $1, $2 );

        if ( $query =~ /[\/\*\\]/ ) {
            next unless ( eval { $file =~ /$regex/ } );
            return unless &checkEval($@);
        }
        else {
            my ($basename) = $file =~ /^.*\/(.*)$/;
            next unless ( eval { $basename =~ /$regex/ } );
            return unless &checkEval($@);
        }
        next if ( $query !~ /\.\d\.gz/ and $file =~ /\/man\// );
        next if ( $front and eval { $file !~ /^\/$query/ } );
        return unless &checkEval($@);

        $contents{$package}{$file} = 1;
        $found++;
    }
    close IN;

    my $pkg;

    ### send results with dcc.
    if ($dccsend) {
        if ( exists $::dcc{'SEND'}{$::who} ) {
            &::msg( $::who, "DCC already active!" );
            return;
        }

        if ( !scalar %contents ) {
            &::msg( $::who, "search returned no results." );
            return;
        }

        my $file = "$::param{tempDir}/$::who.txt";
        if ( !open OUT, ">$file" ) {
            &::ERROR("Debian: cannot write file for dcc send.");
            return;
        }

        foreach $pkg ( keys %contents ) {
            foreach ( keys %{ $contents{$pkg} } ) {

                # TODO: correct padding.
                print OUT "$_\t\t\t$pkg\n";
            }
        }
        close OUT;

        &::shmWrite( $::shm, "DCC SEND $::who $file" );

        return;
    }

    &::status("Debian: $found contents results found.");

    my @list;
    foreach $pkg ( keys %contents ) {
        my @tmplist = &::fixFileList( keys %{ $contents{$pkg} } );
        my @sublist = sort { length $a <=> length $b } @tmplist;

        pop @sublist while ( scalar @sublist > 3 );

        $pkg =~ s/\,/\037\,\037/g;    # underline ','.
        push( @list, "(" . join( ', ', @sublist ) . ") in $pkg" );
    }

    # sort the total list from shortest to longest...
    @list = sort { length $a <=> length $b } @list;

    # show how long it took.
    my $delta_time = &::timedelta($start_time);
    &::status( sprintf( "Debian: %.02f sec to complete query.", $delta_time ) )
      if ( $delta_time > 0 );

    my $prefix = "Debian Search of '$query' ";
    if ( scalar @list ) {    # @list.
        &::performStrictReply( &::formListReply( 0, $prefix, @list ) );
        return;
    }

    # !@list.
    &::DEBUG("deb: ok, !\@list, searching desc for '$query'.") if ($debug);
    @list = &searchDesc($query);

    if ( !scalar @list ) {
        my $prefix = "Debian Package/File/Desc Search of '$query' ";
        &::performStrictReply( &::formListReply( 0, $prefix, ) );

    }
    elsif ( scalar @list == 1 ) {    # list = 1.
        &::DEBUG("deb: list == 1; showing package info of '$list[0]'.");
        &infoPackages( "info", $list[0] );

    }
    else {                           # list > 1.
        my $prefix = "Debian Desc Search of '$query' ";
        &::performStrictReply( &::formListReply( 0, $prefix, @list ) );
    }
}

####
# Usage: &searchAuthor($query);
sub searchAuthor {
    my ( $dist, $query ) = &getDistroFromStr( $_[0] );
    &::DEBUG("deb: searchAuthor: dist => '$dist', query => '$query'.")
      if ($debug);
    $query =~ s/^\s+|\s+$//g;

    # start of search.
    my $start_time = &::timeget();
    &::status("Debian: starting author search.");

    my %urls = fixDist( $dist, 'packages' );
    my $files;
    my ( $bad, $good ) = ( 0, 0 );
    foreach ( keys %urls ) {
        if ( !-f $_ ) {
            $bad++;
            next;
        }

        $good++;
        $files .= " " . $_;
    }

    &::DEBUG("deb: good = $good, bad = $bad...") if ($debug);

    if ( $good == 0 and $bad != 0 ) {
        &::DEBUG("deb: download 2.");

        if ( !&DebianDownload( $dist, %urls ) ) {
            &::ERROR("Debian(sA): could not download files.");
            return;
        }
    }

    my ( %maint, %pkg, $package );
    open( IN, "zegrep -h '^Package|^Maintainer' $files |" );
    while (<IN>) {
        if (/^Package: (\S+)$/) {
            $package = $1;

        }
        elsif (/^Maintainer: (.*) \<(\S+)\>$/) {
            my ( $name, $email ) = ( $1, $2 );
            if ( $package eq "" ) {
                &::DEBUG("deb: sA: package == NULL.");
                next;
            }
            $maint{$name}{$email} = 1;
            $pkg{$name}{$package} = 1;
            $package              = "";

        }
        else {
            chop;
            &::WARN("debian: invalid line: '$_' (1).");
        }
    }
    close IN;

    my %hash;

    # TODO: can we use 'map' here?
    foreach ( grep /\Q$query\E/i, keys %maint ) {
        $hash{$_} = 1;
    }

    # TODO: should we only search email if '@' is used?
    if ( scalar keys %hash < 15 ) {
        my $name;

        foreach $name ( keys %maint ) {
            my $email;

            foreach $email ( keys %{ $maint{$name} } ) {
                next unless ( $email =~ /\Q$query\E/i );
                next if ( exists $hash{$name} );
                $hash{$name} = 1;
            }
        }
    }

    my @list = keys %hash;
    if ( scalar @list != 1 ) {
        my $prefix = "Debian Author Search of '$query' ";
        &::performStrictReply( &::formListReply( 0, $prefix, @list ) );
        return 1;
    }

    &::DEBUG("deb: showing all packages by '$list[0]'...") if ($debug);

    my @pkg = sort keys %{ $pkg{ $list[0] } };

    # show how long it took.
    my $delta_time = &::timedelta($start_time);
    &::status( sprintf( "Debian: %.02f sec to complete query.", $delta_time ) )
      if ( $delta_time > 0 );

    my $email = join( ', ', keys %{ $maint{ $list[0] } } );
    my $prefix = "Debian Packages by $list[0] \002<\002$email\002>\002 ";
    &::performStrictReply( &::formListReply( 0, $prefix, @pkg ) );
}

####
# Usage: &searchDesc($query);
sub searchDesc {
    my ( $dist, $query ) = &getDistroFromStr( $_[0] );
    &::DEBUG("deb: searchDesc: dist => '$dist', query => '$query'.")
      if ($debug);
    $query =~ s/^\s+|\s+$//g;

    # start of search.
    my $start_time = &::timeget();
    &::status("Debian: starting desc search.");

    my $files;
    my ( $bad, $good ) = ( 0, 0 );
    my %urls = fixDist( $dist, 'packages' );

    # XXX This should be abstracted elsewhere.
    foreach ( keys %urls ) {
        if ( !-f $_ ) {
            $bad++;
            next;
        }

        $good++;
        $files .= " $_";
    }

    &::DEBUG("deb(2): good = $good, bad = $bad...") if ($debug);

    if ( $good == 0 and $bad != 0 ) {
        &::DEBUG("deb: download 2c.") if ($debug);

        if ( !&DebianDownload( $dist, %urls ) ) {
            &::ERROR("deb: sD: could not download files.");
            return;
        }
    }

    my $regex = $query;
    $regex =~ s/\./\\./g;
    $regex =~ s/\*/\\S*/g;
    $regex =~ s/\?/./g;

    my ( %desc, $package );
    open( IN, "zegrep -h '^Package|^Description' $files |" );
    while (<IN>) {
        if (/^Package: (\S+)$/) {
            $package = $1;
        }
        elsif (/^Description: (.*)$/) {
            my $desc = $1;
            next unless ( eval { $desc =~ /$regex/i } );
            return unless &checkEval($@);

            if ( $package eq "" ) {
                &::WARN("sD: package == NULL?");
                next;
            }

            $desc{$package} = $desc;
            $package = "";

        }
        else {
            chop;
            &::WARN("debian: invalid line: '$_'. (2)");
        }
    }
    close IN;

    # show how long it took.
    my $delta_time = &::timedelta($start_time);
    &::status( sprintf( "Debian: %.02f sec to complete query.", $delta_time ) )
      if ( $delta_time > 0 );

    return keys %desc;
}

####
# Usage: &generateIncoming();
sub generateIncoming {
    my $pkgfile = $debian_dir . "/Packages-incoming";
    my $idxfile = $pkgfile . ".idx";
    my $stale   = 0;
    $stale++ if ( &::isStale( $pkgfile . ".gz", $refresh ) );
    $stale++ if ( &::isStale( $idxfile, $refresh ) );
    &::DEBUG("deb: gI: stale => '$stale'.") if ($debug);
    return 0 unless ($stale);

    ### STATIC URL.
    my %ftp = &::ftpList( "llug.sep.bnl.gov", "/pub/debian/Incoming/" );

    if ( !open PKG, ">$pkgfile" ) {
        &::ERROR("cannot write to pkg $pkgfile.");
        return 0;
    }
    if ( !open IDX, ">$idxfile" ) {
        &::ERROR("cannot write to idx $idxfile.");
        return 0;
    }

    print IDX "*$pkgfile.gz\n";
    my $file;
    foreach $file ( sort keys %ftp ) {
        next unless ( $file =~ /deb$/ );

        if ( $file =~ /^(\S+)\_(\S+)\_(\S+)\.deb$/ ) {
            print IDX "$1\n";
            print PKG "Package: $1\n";
            print PKG "Version: $2\n";
            print PKG "Architecture: ", ( defined $4 ) ? $4 : "all", "\n";
        }
        print PKG "Filename: $file\n";
        print PKG "Size: $ftp{$file}\n";
        print PKG "\n";
    }
    close IDX;
    close PKG;

    system("gzip -9fv $pkgfile");    # lame fix.

    &::status("Debian: generateIncoming() complete.");
}


##############################
# DEBIAN PACKAGE INFO FUNCTIONS.
#########

# Usage: &getPackageInfo($query,$file);
sub getPackageInfo {
    my ( $package, $file ) = @_;

    if ( !-f $file ) {
        &::status("gPI: file $file does not exist?");
        return 'NULL';
    }

    my $found = 0;
    my ( %pkg, $pkg );

    open( IN, "/bin/zcat $file 2>&1 |" );

    my $done = 0;
    while ( !eof IN ) {
        $_ = <IN>;

        next if (/^ \S+/);    # package long description.

        # package line.
        if (/^Package: (.*)\n$/) {
            $pkg = $1;
            if ( $pkg =~ /^\Q$package\E$/i ) {
                $found++;     # we can use pkg{'package'} instead.
                $pkg{'package'} = $pkg;
            }

            next;
        }

        if ($found) {
            chop;

            if (/^Version: (.*)$/) {
                $pkg{'version'} = $1;
            }
            elsif (/^Priority: (.*)$/) {
                $pkg{'priority'} = $1;
            }
            elsif (/^Section: (.*)$/) {
                $pkg{'section'} = $1;
            }
            elsif (/^Size: (.*)$/) {
                $pkg{'size'} = $1;
            }
            elsif (/^Installed-Size: (.*)$/i) {
                $pkg{'installed'} = $1;
            }
            elsif (/^Description: (.*)$/) {
                $pkg{'desc'} = $1;
            }
            elsif (/^Filename: (.*)$/) {
                $pkg{'find'} = $1;
            }
            elsif (/^Pre-Depends: (.*)$/) {
                $pkg{'depends'} = "pre-depends on $1";
            }
            elsif (/^Depends: (.*)$/) {
                if ( exists $pkg{'depends'} ) {
                    $pkg{'depends'} .= "; depends on $1";
                }
                else {
                    $pkg{'depends'} = "depends on $1";
                }
            }
            elsif (/^Maintainer: (.*)$/) {
                $pkg{'maint'} = $1;
            }
            elsif (/^Provides: (.*)$/) {
                $pkg{'provides'} = $1;
            }
            elsif (/^Suggests: (.*)$/) {
                $pkg{'suggests'} = $1;
            }
            elsif (/^Conflicts: (.*)$/) {
                $pkg{'conflicts'} = $1;
            }

###	    &::DEBUG("=> '$_'.");
        }

        # blank line.
        if (/^$/) {
            undef $pkg;
            last if ($found);
            next;
        }

        next if ( defined $pkg );
    }

    close IN;

    %pkg;
}

# Usage: &infoPackages($query,$package);
sub infoPackages {
    my ( $query, $dist, $package ) = ( $_[0], &getDistroFromStr( $_[1] ) );

    &::status("Debian: Searching for package '$package' in '$dist'.");

    # download packages file.
    # hrm...
    my %urls = &fixDist( $dist, 'packages' );
    if ( $dist ne "incoming" ) {
        &::DEBUG("deb: download 3.") if ($debug);

        if ( !&DebianDownload( $dist, %urls ) ) {    # no good download.
            &::WARN("Debian(iP): could not download ANY files.");
        }
    }

    # check if the package is valid.
    my $incoming = 0;
    my @files = &validPackage( $package, $dist );
    if ( !scalar @files ) {
        &::status("Debian: no valid package found; checking incoming.");
        @files = &validPackage( $package, "incoming" );

        if ( scalar @files ) {
            &::status("Debian: cool, it exists in incoming.");
            $incoming++;
        }
        else {
            &::msg( $::who, "Package '$package' does not exist." );
            return 0;
        }
    }

    if ( scalar @files > 1 ) {
        &::WARN("same package in more than one file; random.");
        &::DEBUG("THIS SHOULD BE FIXED SOMEHOW!!!");
        $files[0] = &::getRandom(@files);
    }

    if ( !-f $files[0] ) {
        &::WARN("files[0] ($files[0]) doesn't exist.");
        &::msg( $::who, "FIXME: $files[0] does not exist?" );
        return 'NULL';
    }

    ### TODO: if specific package is requested, note down that a version
    ###		exists in incoming.

    my $found = 0;
    my $file  = $files[0];
    my ($pkg);

    ### TODO: use fe, dump to a hash. if only one version of the package
    ###		exists. do as normal otherwise list all versions.
    if ( !-f $file ) {
        &::ERROR("D:iP: file '$file' DOES NOT EXIST!!! should never happen.");
        return 0;
    }
    my %pkg = &getPackageInfo( $package, $file );

    $query = "info" if ( $query eq "dinfo" );

    # 'fm'-like output.
    if ( $query eq "info" ) {
        if ( scalar keys %pkg <= 5 ) {
            &::DEBUG( "deb: running debianCheck() due to problems ("
                  . scalar( keys %pkg )
                  . ")." );
            &debianCheck();
            &::DEBUG("deb: end of debianCheck()");

            &::msg( $::who,
"Debian: Package appears to exist but I could not retrieve info about it..."
            );
            return;
        }

        $pkg{'info'} = "\002(\002" . $pkg{'desc'} . "\002)\002";
        $pkg{'info'} .= ", section " . $pkg{'section'};
        $pkg{'info'} .= ", is " . $pkg{'priority'};

        #	$pkg{'info'} .= ". Version: \002$pkg{'version'}\002";
        $pkg{'info'} .= ". Version: \002$pkg{'version'}\002 ($dist)";
        $pkg{'info'} .=
          ", Packaged size: \002" . int( $pkg{'size'} / 1024 ) . "\002 kB";
        $pkg{'info'} .= ", Installed size: \002$pkg{'installed'}\002 kB";

        if ($incoming) {
            &::status("iP: info requested and pkg is in incoming, too.");
            my %incpkg =
              &getPackageInfo( $query, $debian_dir . "/Packages-incoming" );

            if ( scalar keys %incpkg ) {
                $pkg{'info'} .= ". Is in incoming ($incpkg{'file'}).";
            }
            else {
                &::ERROR(
"iP: pkg $query is in incoming but we couldn't get any info?"
                );
            }
        }
    }

    if ( $dist eq "incoming" ) {
        $pkg{'info'} .= "Version: \002$pkg{'version'}\002";
        $pkg{'info'} .=
          ", Packaged size: \002" . int( $pkg{'size'} / 1024 ) . "\002 kB";
        $pkg{'info'} .= ", is in incoming!!!";
    }

    if ( !exists $pkg{$query} ) {
        if ( $query eq "suggests" ) {
            $pkg{$query} = "has no suggestions";
        }
        elsif ( $query eq "conflicts" ) {
            $pkg{$query} = "does not conflict with any other package";
        }
        elsif ( $query eq "depends" ) {
            $pkg{$query} = "does not depend on anything";
        }
        elsif ( $query eq "maint" ) {
            $pkg{$query} = "has no maintainer";
        }
        else {
            $pkg{$query} = "has nothing about $query";
        }
    }

    &::performStrictReply("$package: $pkg{$query}");
}

# Usage: &infoStats($dist);
sub infoStats {
    my ($dist) = @_;
    $dist = &getDistro($dist);
    return unless ( defined $dist );

    &::DEBUG("deb: infoS: dist => '$dist'.");

    # download packages file if needed.
    my %urls = &fixDist( $dist, 'packages' );
    &::DEBUG("deb: download 4.");
    if ( !&DebianDownload( $dist, %urls ) ) {
        &::WARN("Debian(iS): could not download ANY files.");
        &::msg( $::who, "Debian(iS): internal error." );
        return;
    }

    my %stats;
    my %total = ( count => 0, maint => 0, isize => 0, csize => 0 );
    my $file;
    foreach $file ( keys %urls ) {
        &::DEBUG("deb: file => '$file'.");
        if ( exists $stats{$file}{'count'} ) {
            &::DEBUG("deb: hrm... duplicate open with $file???");
            next;
        }

        open( IN, "zcat $file 2>&1 |" );

        if ( !-e "$file" ) {
            &::DEBUG("deb: iS: $file does not exist.");
            next;
        }

        while ( !eof IN ) {
            $_ = <IN>;

            next if (/^ \S+/);    # package long description.

            if (/^Package: (.*)\n$/) {    # counter.
                $stats{$file}{'count'}++;
                $total{'count'}++;
            }
            elsif (/^Maintainer: .* <(\S+)>$/) {
                $stats{$file}{'maint'}{$1}++;
                $total{'maint'}{$1}++;
            }
            elsif (/^Size: (.*)$/) {      # compressed size.
                $stats{$file}{'csize'} += $1;
                $total{'csize'}        += $1;
            }
            elsif (/^i.*size: (.*)$/i) {    # installed size.
                $stats{$file}{'isize'} += $1;
                $total{'isize'}        += $1;
            }

###	    &::DEBUG("=> '$_'.");
        }
        close IN;
    }

    ### TODO: don't count ppl with multiple email addresses.

    &::performStrictReply( "Debian Distro Stats on $dist... "
          . "\002$total{'count'}\002 packages, " . "\002"
          . scalar( keys %{ $total{'maint'} } )
          . "\002 maintainers, " . "\002"
          . int( $total{'isize'} / 1024 )
          . "\002 MB installed size, " . "\002"
          . int( $total{'csize'} / 1024 / 1024 )
          . "\002 MB compressed size." );

### TODO: do individual stats? if so, we need _another_ arg.
    #    foreach $file (keys %stats) {
    #	foreach (keys %{ $stats{$file} }) {
    #	    &::DEBUG("  '$file' '$_' '$stats{$file}{$_}'.");
    #	}
    #    }

    return;
}

###
# HELPER FUNCTIONS FOR INFOPACKAGES...
###

# Usage: &generateIndex();
sub generateIndex {
    my (@dists) = @_;
    &::DEBUG( "D: generateIndex($dists[0]) called! " . join( ':', caller(), ) );
    if ( !scalar @dists or $dists[0] eq '' ) {
        &::ERROR("gI: no dists to generate index.");
        return 1;
    }

    foreach (@dists) {
        my $dist = &getDistro($_);    # incase the alias is returned, possible?
        my $idx = $debian_dir . "/Packages-$dist.idx";
        my %urls = fixDist( $_, 'packages' );

        # TODO: check if any of the Packages file have been updated then
        #	regenerate it, even if it's not stale.
        # TODO: also, regenerate the index if the packages file is newer
        #	than the index.
        next unless ( &::isStale( $idx, $refresh ) );

        if (/^incoming$/i) {
            &::DEBUG("deb: gIndex: calling generateIncoming()!");
            &generateIncoming();
            next;
        }

        # 	if (/^sarge$/i) {
        # 	    &::DEBUG("deb: Copying old index of sarge to -old");
        # 	    system("cp $idx $idx-old");
        # 	}

        &::DEBUG("deb: gIndex: calling DebianDownload($dist, ...).")
          if ($debug);
        &DebianDownload( $dist, &fixDist( $dist, 'packages' ) );

        &::status("Debian: generating index for '$dist'.");
        if ( !open OUT, ">$idx" ) {
            &::ERROR("cannot write to $idx.");
            return 0;
        }

        my $packages;
        foreach $packages ( keys %urls ) {
            if ( !-e $packages ) {
                &::ERROR("gIndex: '$packages' does not exist?");
                next;
            }

            print OUT "*$packages\n";
            open( IN, "zcat $packages |" );

            while (<IN>) {
                next unless (/^Package: (.*)\n$/);
                print OUT $1 . "\n";
            }
            close IN;
        }
        close OUT;
    }

    return 1;
}

# Usage: &validPackage($package, $dist);
sub validPackage {
    my ( $package, $dist ) = @_;
    my @files;
    my $file;

    ### this majorly sucks, we need some standard in place.
    # why is this needed... need to investigate later.
    my $olddist = $dist;
    $dist = &getDistro($dist);

    &::DEBUG("deb: validPackage($package, $dist) called.") if ($debug);

    my $error = 0;
    while ( !open IN, $debian_dir . "/Packages-$dist.idx" ) {
        if ($error) {
            &::ERROR("Packages-$dist.idx does not exist (#1).");
            return;
        }

        &generateIndex($dist);

        $error++;
    }

    my $count = 0;
    while (<IN>) {
        if (/^\*(.*)\n$/) {
            $file = $1;
            next;
        }

        if (/^\Q$package\E\n$/) {
            push( @files, $file );
        }
        $count++;
    }
    close IN;

    &::VERB( "vP: scanned $count items in index.", 2 );

    return @files;
}

sub searchPackage {
    my ( $dist, $query ) = &getDistroFromStr( $_[0] );
    my $file  = $debian_dir . "/Packages-$dist.idx";
    my $warn  = ( $query =~ tr/A-Z/a-z/ ) ? 1 : 0;
    my $error = 0;
    my @files;

    &::status("Debian: Search package matching '$query' in '$dist'.");
    unlink $file if ( -z $file );

    while ( !open IN, $file ) {
        if ( $dist eq "incoming" ) {
            &::DEBUG("deb: sP: dist == incoming; calling gI().");
            &generateIncoming();
        }

        if ($error) {
            &::ERROR("could not generate index ($file)!");
            return;
        }

        $error++;
        &::DEBUG("deb: should we be doing this?");
        &generateIndex( ($dist) );
    }

    while (<IN>) {
        chop;

        if (/^\*(.*)$/) {
            $file = $1;

            if ( &::isStale( $file, $refresh ) ) {
                &::DEBUG("deb: STALE $file! regen.") if ($debug);
                &generateIndex( ($dist) );
###		@files = searchPackage("$query $dist");
                &::DEBUG("deb: EVIL HACK HACK HACK.") if ($debug);
                last;
            }

            next;
        }

        if (/\Q$query\E/) {
            push( @files, $_ );
        }
    }
    close IN;

    if ( scalar @files and $warn ) {
        &::msg( $::who,
            "searching for package name should be fully lowercase!" );
    }

    return @files;
}

sub getDistro {
    my $dist = $_[0];

    if ( !defined $dist or $dist eq "" ) {
        &::DEBUG("deb: gD: dist == NULL; dist = defaultdist.");
        $dist = $defaultdist;
    }

    if ( exists $dists{$dist} ) {
        &::VERB( "gD: returning dists{$dist} ($dists{$dist})", 2 );
        return $dists{$dist};

    }
    elsif ( exists $archived_dists{$dist} ) {
        &::VERB( "gD: returning archivedists{$dist} ($archived_dists{$dist})",
            2 );
        return $archived_dists{$dist};
    }
    else {
        if (    !grep( /^\Q$dist\E$/i, %dists )
            and !grep( /^\Q$dist\E$/i, %archived_dists ) )
        {
            &::msg( $::who, "invalid dist '$dist'." );
            return;
        }

        &::VERB( "gD: returning $dist (no change or conversion)", 2 );
        return $dist;
    }
}

sub getDistroFromStr {
    my ($str) = @_;
    my $dists = join '|', %dists, %archived_dists;
    my $dist = $defaultdist;

    if ( $str =~ s/\s+($dists)$//i ) {
        $dist = &getDistro( lc $1 );
        $str =~ s/\\+$//;
    }
    $str =~ s/\\([\$\^])/$1/g;

    return ( $dist, $str );
}

sub fixDist {
    my ( $dist, $type ) = @_;
    my %new;
    my ( $key, $val );
    my %dist_urls;

    if ( exists $archived_dists{$dist} ) {
        if ( $type eq 'contents' ) {
            %dist_urls = %archiveurlcontents;
        }
        else {
            %dist_urls = %archiveurlpackages;
        }
    }
    else {
        if ( $type eq 'contents' ) {
            %dist_urls = %urlcontents;
        }
        else {
            %dist_urls = %urlpackages;
        }
    }

    while ( ( $key, $val ) = each %dist_urls ) {
        $key =~ s/##DIST/$dist/;
        $val =~ s/##DIST/$dist/;
        ### TODO: what should we do if the sar wasn't done.
        $new{ $debian_dir . "/" . $key } = $val;
    }

    return %new;
}

sub DebianFind {

    # HACK! HACK! HACK!
    my ($str) = @_;
    my ( $dist, $query ) = &getDistroFromStr($str);
    my @results = sort &searchPackage($str);

    if ( !scalar @results ) {
        &::Forker( "Debian", sub { &searchContents($str); } );
    }
    elsif ( scalar @results == 1 ) {
        &::status(
"searchPackage returned one result; getting info of package instead!"
        );
        &::Forker( "Debian",
            sub { &infoPackages( "info", "$results[0] $dist" ); } );
    }
    else {
        my $prefix = "Debian Package Listing of '$query' ";
        &::performStrictReply( &::formListReply( 0, $prefix, @results ) );
    }
}

sub debianCheck {
    my $error = 0;

    &::status("debianCheck() called.");

    ### TODO: remove the following loop (check if dir exists before)
    while (1) {
        last if ( opendir( DEBIAN, $debian_dir ) );

        if ($error) {
            &::ERROR("dC: cannot opendir debian.");
            return;
        }

        mkdir $debian_dir, 0755;
        $error++;
    }

    my $retval = 0;
    my $file;
    while ( defined( $file = readdir DEBIAN ) ) {
        next unless ( $file =~ /(gz|bz2)$/ );

        # TODO: add bzip2 support (debian doesn't do .bz2 anyway)
        my $exit = system("/bin/gzip -t '$debian_dir/$file'");
        next unless ($exit);
        &::DEBUG( "deb: hmr... => "
              . ( time() - ( stat( $debian_dir / $file ) )[8] )
              . "'." );
        next unless ( time() - ( stat($file) )[8] > 3600 );

        #&::DEBUG("deb: dC: exit => '$exit'.");
        &::WARN("dC: '$debian_dir/$file' corrupted? deleting!");
        unlink $debian_dir . "/" . $file;
        $retval++;
    }

    return $retval;
}

sub checkEval {
    my ($str) = @_;

    if ($str) {
        &::WARN("cE: $str");
        return 0;
    }
    else {
        return 1;
    }
}

sub searchDescFE {

    #    &::DEBUG("deb: FE called for searchDesc");
    my ($query) = @_;
    my @list = &searchDesc($query);

    if ( !scalar @list ) {
        my $prefix = "Debian Desc Search of '$query' ";
        &::performStrictReply( &::formListReply( 0, $prefix, ) );
    }
    elsif ( scalar @list == 1 ) {    # list = 1.
        &::DEBUG("deb: list == 1; showing package info of '$list[0]'.");
        &infoPackages( "info", $list[0] );
    }
    else {                           # list > 1.
        my $prefix = "Debian Desc Search of '$query' ";
        &::performStrictReply( &::formListReply( 0, $prefix, @list ) );
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
