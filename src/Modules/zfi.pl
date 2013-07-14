package zfi;

# Search Zaurus Feeds Index (ZFI)
# Version 1.0
# Released 02 Oct 2002

# Based on ZSI package by Darien Kruss <darien@kruss.com>
# Modified by Jordan Wiens <jordan@d0pe.com> (numatrix on #zaurus) and
# Eric Lin <anselor@d0pe.com> (anselor on #zaurus) to search ZFI instead of ZSI

# This script relies on the following page returning results
# http://zaurii.com/zfi/zfibot.php
# Returns the 5 latest/newest entries

# http://zaurii.com/zfi/zfibot.php?query=XXXX
# Returns all matches where XXX is in the name, description, etc

# Returned matches are pipe-separated, one record per line
# name|URL|description

# These are the phrases we get called for:

# 'zfi'  or  'zfi <search>'

# We reply publicly or privately, depending how we were called

use strict;

my $no_zfi;

BEGIN {
    $no_zfi = 0;
    eval "use LWP::UserAgent";
    $no_zfi++ if ($@);
}

sub queryText {
    my ($query) = @_;

    if ($no_zfi) {
        &::status("zfi module requires LWP::UserAgent.");
        return '';
    }

    my $res_return = 5;

    my $ua = new LWP::UserAgent;
    $ua->proxy( 'http', $::param{'httpProxy'} ) if ( &::IsParam('httpProxy') );

    $ua->timeout(10);

    my $searchpath;
    if ($query) {
        $searchpath = "http://zaurii.com/zfi/zfibot.php?query=$query";
    }
    else {
        $searchpath = "http://zaurii.com/zfi/zfibot.php";
    }

    my $request = new HTTP::Request( 'GET', "$searchpath" );
    my $response = $ua->request($request);

    if ( !$response->is_success ) {
        return
"Something failed in connecting to the ZFI web server. Try again later.";
    }

    my $content = $response->content;

    if ( $content =~ /No entries found/im ) {
        return "No results were found searching ZFI for '$query'.";
    }

    my $res_count   = 0;    #local counter
    my $res_display = 0;    #results displayed

    my @lines = split( /\n/, $content );

    my $result = '';
    foreach my $line (@lines) {
        if ( length($line) > 10 ) {
            my ( $name, $href, $desc ) = split( /\|/, $line );

            if ( $res_count < $res_return ) {
                $result .= "$name ($desc) $href : ";
                $res_display++;
            }
            $res_count++;
        }
    }

    if ( ($query) && ( $res_count > $res_display ) ) {
        $result .=
"$res_display of $res_count shown. All at http://zaurii.com/zfi/index.phtml?p=r&r=$query";
    }

    return $result;
}

sub query {
    my ($args) = @_;
    &::performStrictReply( &queryText($args) );
    return;
}

1;
__END__

# vim:ts=4:sw=4:expandtab:tw=80
