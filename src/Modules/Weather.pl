#!/usr/bin/perl

package Weather;

# kevin lenzo (C) 1999 -- get the weather forcast NOAA.
# feel free to use, copy, cut up, and modify, but if
# you do something cool with it, let me know.

# 16-SEP-99 lenzo@cs.cmu.edu switched to LWP::UA and
#           put in a timeout.

my $no_weather;
my $cache_time = 60 * 40;    # 40 minute cache time
my $default    = 'KAGC';

BEGIN {
    $no_weather = 0;
    eval "use LWP::UserAgent";
    $no_weather++ if ($@);
}

sub Weather {
    my ($args) = @_;
    &::performStrictReply( &queryText( $args, 'weather' ) );
    return;
}

sub Metar {
    my ($args) = @_;
    &::performStrictReply( &queryText( $args, 'metar' ) );
    return;
}

sub queryText {
    my ($station) = shift;
    my ($wxmode)  = shift;
    my $result;

    $station = uc($station);
    $station =~ s/for //i;

    if ($no_weather) {
        return 0;
    }
    else {

        if ( exists $cache{$station} ) {
            my ( $time, $response ) = split $;, $cache{$station};
            if ( ( time() - $time ) < $cache_time ) {
                return $response;
            }
        }

        my $ua = new LWP::UserAgent;
        $ua->proxy( 'http', $::param{'httpProxy'} )
          if ( &::IsParam('httpProxy') );

        $ua->timeout(10);
        my $request =
          new HTTP::Request( 'GET',
            "http://weather.noaa.gov/weather/current/$station.html" );
        my $response = $ua->request($request);

        if ( !$response->is_success ) {
            if ( $response->code == 404 ) {
                return "I can't find station code \"$station\""
                  . " (see http://www.nws.noaa.gov/oso/site.shtml"
                  . " or http://www.nws.noaa.gov/tg/siteloc.shtml"
                  . " for ICAO locations codes).";
            }
            else {
                return 'Something failed in connecting to the NOAA web'
                  . " server. Try again later.";
            }
        }

        $content = $response->content;
        $content =~ s|.*?<BODY[^>]*>||is;

    #$content =~ s|.*?current weather conditions.*?<BR>([^<]*?)\s*<.*?</TR>||is;
        $content =~ s|.*?current weather conditions[^<]*(<[^>]+>\s*)+||is;
        $content =~ s|([^<]*?)\s*<.*?</TR>||is;
        my $place = $1;
        chomp $place;

        $content =~ s|.*?<TR>(?:\s*<[^>]+>)*\s*([^<]+)\s<.*?</TR>||is;
        my $id = $1;
        chomp $id;

        $content =~ s|.*?conditions at.*?</TD>||is;

#$content =~ s|.*?<OPTION SELECTED>\s+([^<]+)\s<OPTION>.*?</TR>||s; # local time
        $content =~ s|.*?<BR>\s+([^<]+?)\s*</FORM>.*?</TR>||s;    # UTC
        my $time = $1;
        $time =~ s/-//g;
        $time =~ s/\s+/ /g;

        $content =~ s|\s(.*?)<TD COLSPAN=2>||s;
        my $features = $1;

        while ( $features =~
s|.*?<TD ALIGN[^>]*>(?:\s*<[^>]+>)*\s+([^<]+?)\s+<.*?<TD>(?:\s*<[^>]+>)*\s+([^<]+?)\s<.*?/TD>||s
          )
        {
            my ( $f, $v ) = ( $1, $2 );
            chomp $f;
            chomp $v;
            $feat{$f} = $v;
        }

        $content =~ s|.*?>(\d+\S+\s+\(\S+\)).*?</TD>||s;    # max temp;
        $max_temp = $1;
        $content =~ s|.*?>(\d+\S+\s+\(\S+\)).*?</TD>||s;
        $min_temp = $1;

        if ($time) {
            if ( $wxmode eq 'metar' && defined( $feat{'ob'} ) ) {
                return ( 'METAR ' . $place . ": " . $feat{'ob'} );
            }

            $result = "$place; $id; last updated: $time";
            foreach ( sort keys %feat ) {
                next if $_ eq 'ob';
                $result .= "; $_: $feat{$_}";
            }
            my $t = time();
            $cache{$station} = join $;, $t, $result;
        }
        else {
            $result =
"I can't find that station code (see http://weather.noaa.gov/weather/curcond.html for locations and codes)";
        }
        return $result;
    }
}

if (0) {
    if ( -t STDIN ) {
        my $result = Weather::NOAA::get($default);
        $result =~ s/; /\n/g;
        print "\n$result\n\n";
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80

__END__

=head1 NAME

NOAA.pl - Get the weather from a NOAA server

=head1 PREREQUISITES

	LWP::UserAgent

=head1 PARAMETERS

weather

=head1 PUBLIC INTERFACE

	weather [for] <station>

=head1 DESCRIPTION

Contacts C<weather.noaa.gov> and gets the weather report for a given
station.

=head1 AUTHORS

Kevin Lenzo
