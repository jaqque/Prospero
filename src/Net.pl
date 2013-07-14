#
#   Net.pl: FTP//HTTP helper
#   Author: dms
#  Version: v0.1 (20000309)
#  Created: 20000309
#

use strict;

use vars qw(%ftp %param);

# Usage: &ftpGet($host,$dir,$file,[$lfile]);
sub ftpGet {
    my ( $host, $dir, $file, $lfile ) = @_;
    my $verbose_ftp = 1;

    return unless &loadPerlModule('Net::FTP');

    &status("FTP: opening connection to $host.") if ($verbose_ftp);
    my $ftp = Net::FTP->new(
        $host,
        'Timeout' => 1 * 60,
###	'BlockSize'	=> 1024,	# ???
    );

    return if ($@);

    # login.
    if ( $ftp->login() ) {
        &status('FTP: logged in successfully.') if ($verbose_ftp);
    }
    else {
        &status('FTP: login failed.');
        $ftp->quit();
        return 0;
    }

    # change directories.
    if ( $ftp->cwd($dir) ) {
        &status("FTP: changed dirs to $dir.") if ($verbose_ftp);
    }
    else {
        &status("FTP: cwd dir ($dir) does not exist.");
        $ftp->quit();
        return 0;
    }

    # get the size of the file.
    my ( $size, $lsize );
    if ( $size = $ftp->size($file) ) {
        &status("FTP: file size is $size") if ($verbose_ftp);
        my $thisfile = $file || $lfile;

        if ( -f $thisfile ) {
            $lsize = -s $thisfile;
            if ( $_ != $lsize ) {
                &status("FTP: local size is $lsize; downloading.")
                  if ($verbose_ftp);
            }
            else {
                &status('FTP: same size; skipping.');
                system("touch $thisfile");    # lame hack.
                $ftp->quit();
                return 1;
            }
        }
    }
    else {
        &status('FTP: file does not exist.');
        $ftp->quit();
        return 0;
    }

    my $start_time = &timeget();
    if ( defined $lfile ) {
        &status("FTP: getting $file as $lfile.") if ($verbose_ftp);
        $ftp->get( $file, $lfile );
    }
    else {
        &status("FTP: getting $file.") if ($verbose_ftp);
        $ftp->get($file);
    }

    if ( defined $lsize ) {
        &DEBUG("FTP: locsize => '$lsize'.");
        if ( $size != $lsize ) {
            &FIXME('FTP: downloaded file seems truncated.');
        }
    }

    my $delta_time = &timedelta($start_time);
    if ( $delta_time > 0 and $verbose_ftp ) {
        &status( sprintf( 'FTP: %.02f sec to complete.', $delta_time ) );
        my ( $rateunit, $rate ) = ( 'B', $size / $delta_time );
        if ( $rate > 1024 ) {
            $rate /= 1024;
            $rateunit = 'kB';
        }
        &status( sprintf( "FTP: %.01f ${rateunit}/sec.", $rate ) );
    }

    $ftp->quit();

    return 1;
}

# Usage: &ftpList($host,$dir);
sub ftpList {
    my ( $host, $dir ) = @_;
    my $verbose_ftp = 1;

    return unless &loadPerlModule('Net::FTP');

    &status("FTP: opening connection to $host.") if ($verbose_ftp);
    my $ftp = Net::FTP->new( $host, 'Timeout' => 60 );

    return if ($@);

    # login.
    if ( $ftp->login() ) {
        &status('FTP: logged in successfully.') if ($verbose_ftp);
    }
    else {
        &status('FTP: login failed.');
        $ftp->quit();
        return;
    }

    # change directories.
    if ( $ftp->cwd($dir) ) {
        &status("FTP: changed dirs to $dir.") if ($verbose_ftp);
    }
    else {
        &status("FTP: cwd dir ($dir) does not exist.");
        $ftp->quit();
        return;
    }

    &status('FTP: doing ls.') if ($verbose_ftp);
    foreach ( $ftp->dir() ) {

        # modes d uid gid size month day time file.
        if (
/^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+) (\S{3})\s+(\d+) \d+:\d+ (.*)$/
          )
        {

            # name = size.
            $ftp{$8} = $5;
        }
        else {
            &DEBUG("FTP: UNKNOWN  => '$_'.");
        }
    }
    &status( 'FTP: ls done. ' . scalar( keys %ftp ) . ' entries.' );
    $ftp->quit();

    return %ftp;
}

### LWP.
# Usage: &getURL($url, [$post]);
# TODO: rename this to getHTTP
sub getURL {
    my ( $url, $post ) = @_;
    my ( $ua, $res, $req );

    return unless &loadPerlModule('LWP::UserAgent');

    $ua = new LWP::UserAgent;
    $ua->proxy( 'http', $param{'httpProxy'} ) if &IsParam('httpProxy');

    if ( defined $post ) {
        $req = new HTTP::Request( 'POST', $url );
        $req->content_type('application/x-www-form-urlencoded');
        $req->content($post);
    }
    else {
        $req = new HTTP::Request( 'GET', $url );
    }

    &status("getURL: getting '$url'");
    my $time = time();
    $res = $ua->request($req);
    my $size = length( $res->content );
    if ( $size and time - $time ) {
        my $rate = int( $size / 1000 / ( time - $time ) );
        &status('getURL: Done (took '
              . &Time2String( time - $time )
              . ", $rate k/sec)" );
    }

    # return NULL upon error.
    return unless ( $res->is_success );

    return ( split '\n', $res->content );
}

sub getURLAsFile {
    my ( $url, $file ) = @_;
    my ( $ua, $res, $req );
    my $time = time();

    unless ( &loadPerlModule('LWP::UserAgent') ) {
        &::DEBUG('getURLAsFile: LWP::UserAgent not installed');
        return;
    }

    $ua = new LWP::UserAgent;
    $ua->proxy( 'http', $param{'httpProxy'} ) if &IsParam('httpProxy');
    $req = HTTP::Request->new( 'GET', $url );
    &status("getURLAsFile: getting '$url' as '$file'");
    $res = $ua->request( $req, $file );

    my $delta_time = time() - $time;
    if ($delta_time) {
        my $size = -s $file || 0;
        my $rate = int( $size / $delta_time / 1024 );
        &status("getURLAsFile: Done. ($rate kB/sec)");
    }

    return $res;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
