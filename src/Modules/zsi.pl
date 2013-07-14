package zsi;

# Search Zaurus Software Index (ZSI)
# Version 1.0
# Released 26 Aug 2002

# Developed by Darien Kruss <darien@kruss.com>
# http://zaurus.kruss.com/
# usually hangs out on #zaurus as 'darienm'

# This script relies on the following page returning results
# http://killefiz.de/zaurus/zsibot.php
# Returns the 5 latest/newest entries

# http://killefiz.de/zaurus/zsibot.php?query=XXXX
# Returns all matches where XXX is in the name, description, etc

# Returned matches are pipe-separated, one record per line
# name|URL|description

# These are the phrases we get called for:

# 'zsi'  or  'zsi <search>'

# We reply publicly or privately, depending how we were called

my $no_zsi;

use strict;

BEGIN {
    $no_zsi = 0;
    eval "use LWP::UserAgent";
    $no_zsi++ if ($@);
}

sub queryText {
    my ($query) = @_;

    if ($no_zsi) {
        &::status("zsi module requires LWP::UserAgent.");
        return '';
    }

    my $res_return = 5;

    my $ua = new LWP::UserAgent;
    $ua->proxy( 'http', $::param{'httpProxy'} ) if ( &::IsParam('httpProxy') );

    $ua->timeout(10);

    my $searchpath;
    if ($query) {
        $searchpath = "http://killefiz.de/zaurus/zsibot.php?query=$query";
    }
    else {
        $searchpath = "http://killefiz.de/zaurus/zsibot.php";
    }

    my $request = new HTTP::Request( 'GET', "$searchpath" );
    my $response = $ua->request($request);

    if ( !$response->is_success ) {
        return
"Something failed in connecting to the ZSI web server. Try again later.";
    }

    my $content = $response->content;

    if ( $content =~ /No entries found/im ) {
        return "No results were found searching ZSI for '$query'.";
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
"$res_display of $res_count shown. All at http://killefiz.de/zaurus/search.php?q=$query";
    }

    return $result;
}

sub query {
    my ($args) = @_;
    &::performStrictReply( &queryText($args) );
    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80

__END__
