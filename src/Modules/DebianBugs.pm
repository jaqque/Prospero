# This module is a plugin for WWW::Scraper, and allows one to search
# google, and is released under the terms of the GPL version 2, or any
# later version. See the file README and COPYING for more
# information. Copyright 2002 by Don Armstrong <don@donarmstrong.com>.

# $Id:  $

package DebianBugs;

use warnings;
use strict;

use vars qw($VERSION $DEBUG);

use LWP::UserAgent;

$VERSION = q($Rev: $);
$DEBUG ||= 0;

sub get_url($) {
    my $url = shift;

    my $ua = LWP::UserAgent->new;
    $ua->agent("blootbug_debbugs/$VERSION");

    # Create a request
    my $req = HTTP::Request->new( GET => $url );

    # Pass request to the user agent and get a response back
    my $res = $ua->request($req);

    # Check the outcome of the response
    if ( $res->is_success ) {
        return $res->content;
    }
    else {
        return undef;
    }
}

sub bug_info($;$) {
    my $bug_num = shift;
    my $options = shift || {};

    if ( not $bug_num =~ /^\#?\d+$/ ) {
        warn "Bug is not a number!" and return undef
          if not $options->{return_warnings};
        return "Bug is not a number!";
    }
    $bug_num =~ s/^\#//;
    my $report =
      get_url("http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=$bug_num");

    # strip down report to relevant header information.
    $report =~ /<HEAD>(.+?)<HR>/s;
    $report = $1;
    my $bug = {};
    ( $bug->{num}, $bug->{title} ) =
      $report =~ m#\#(\d+)\<\/A\>\<BR\>(.+?)\<\/H1\>#is;
    if ($DEBUG) {
        print "Bugnum: $bug->{num}\nTitle: $bug->{title}\nReport: $report\n";
    }
    $bug->{title} =~ s/&lt;/\</g;
    $bug->{title} =~ s/&gt;/\>/g;
    $bug->{title} =~ s/&quot;/\"/g;
    $bug->{severity} = 'n';    #Default severity is normal
    my @bug_flags = split /(?<!\&.t)[;\.]\n/s, $report;
    foreach my $bug_flag (@bug_flags) {
        print "Bug_flag: $bug_flag\n" if $DEBUG;
        if ( $bug_flag =~ /Severity:/i ) {
            ( $bug->{severity} ) =
              $bug_flag =~ /(wishlist|minor|normal|important|serious|grave)/i;

            # Just leave the leter instead of the whole thing.
            $bug->{severity} =~ s/^(.).+$/$1/;
        }
        elsif ( $bug_flag =~ /Package:/ ) {
            ( $bug->{package} ) = $bug_flag =~ /\"\>\s*([^\<\>\"]+?)\s*\<\/a\>/;
        }
        elsif ( $bug_flag =~ /Reported by:/ ) {
            ( $bug->{reporter} ) = $bug_flag =~ /\"\>\s*(.+?)\s*\<\/a\>/;

            # strip &lt; and &gt;
            $bug->{reporter} =~ s/&lt;/\</g;
            $bug->{reporter} =~ s/&gt;/\>/g;
        }
        elsif ( $bug_flag =~ /Date:/ ) {
            ( $bug->{date} ) = $bug_flag =~ /Date:\s*(\w.+?)\s*$/;

            #ditch extra whitespace
            $bug->{date} =~ s/\s{2,}/\ /;
        }
        elsif ( $bug_flag =~ /Tags:/ ) {
            ( $bug->{tags} ) = $bug_flag =~ /strong\>\s*(.+?)\s*\<\/strong\>/;
        }
        elsif ( $bug_flag =~ /merged with / ) {
            $bug_flag =~ s/merged with\s*//;
            $bug_flag =~ s/\<[^\>]+\>//g;
            $bug_flag =~ s/\s//sg;
            $bug->{merged_with} = $bug_flag;

        }
        elsif ( $bug_flag =~ /\>Done:\</ ) {
            $bug->{done} = 1;
        }
        elsif ( $bug_flag =~ /\>Fixed\</ ) {
            $bug->{done} = 1;
        }
    }

    # report bug

    $report = '';
    $report .= 'DONE:' if defined $bug->{done} and $bug->{done};
    $report .= '#'
      . $bug->{num} . ':'
      . uc( $bug->{severity} ) . '['
      . $bug->{package} . '] '
      . $bug->{title};
    $report .= ' (' . $bug->{tags} . ')' if defined $bug->{tags};
    $report .= '; ' . $bug->{date};

    # Avoid reporting so many merged bugs.
    $report .= ' ['
      . join( ',', splice( @{ [ split( /,/, $bug->{merged_with} ) ] }, 0, 3 ) )
      . ']'
      if defined $bug->{merged_with};
    if ($DEBUG) {
        use Data::Dumper;
        print STDERR Dumper($bug);
    }
    return $report;
}

sub package_bugs($) {

}

1;


__END__

# vim:ts=4:sw=4:expandtab:tw=80
