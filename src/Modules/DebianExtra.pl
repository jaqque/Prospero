#
#  DebianExtra.pl: Extra stuff for debian
#          Author: dms
#         Version: v0.1 (20000520)
#         Created: 20000520
#

use strict;

package DebianExtra;

sub Parse {
    my ($args) = @_;
    my ($msg)  = '';

    #&::DEBUG("DebianExtra: $args\n");
    if ( !defined $args or $args =~ /^$/ ) {
        &debianBugs();
    }

    if ( $args =~ /^\#?(\d+)$/ ) {

        # package number:
        $msg = &do_id($args);
    }
    elsif ( $args =~ /^(\S+\@\S+)$/ ) {

        # package email maintainer.
        $msg = &do_email($args);
    }
    elsif ( $args =~ /^(\S+)$/ ) {

        # package name.
        $msg = &do_pkg($args);
    }
    else {

        # invalid.
        $msg = "error: could not parse $args";
    }
    &::performStrictReply($msg);
}

sub debianBugs {
    my @results = &::getURL("http://master.debian.org/~wakkerma/bugs");
    my ( $date, $rcbugs, $remove );
    my ( $bugs_closed, $bugs_opened ) = ( 0, 0 );

    if ( scalar @results ) {
        foreach (@results) {
            s/<.*?>//g;
            $date   = $1 if (/status at (.*)\s*$/);
            $rcbugs = $1 if (/bugs: (\d+)/);
            $remove = $1 if (/REMOVE\S+ (\d+)\s*$/);
            if (/^(\d+) r\S+ b\S+ w\S+ c\S+ a\S+ (\d+)/) {
                $bugs_closed = $1;
                $bugs_opened = $2;
            }
        }
        my $xtxt =
          ( $bugs_closed >= $bugs_opened )
          ? "It's good to see "
          : "Oh no, the bug count is rising -- ";

        &::performStrictReply(
                "Debian bugs statistics, last updated on $date... "
              . "There are \002$rcbugs\002 release-critical bugs;  $xtxt"
              . "\002$bugs_closed\002 bugs closed, opening \002$bugs_opened\002 bugs.  "
              . "About \002$remove\002 packages will be removed." );
    }
    else {
        &::msg( $::who, "Couldn't retrieve data for debian bug stats." );
    }
}

sub do_id($) {
    my ($bug_num) = shift;

    if ( not $bug_num =~ /^\#?\d+$/ ) {
        return "Bug is not a number!";
    }
    $bug_num =~ s/^\#//;
    my @results =
      &::getURL("http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=$bug_num");
    my $report = join( "\n", @results );

    # strip down report to relevant header information.
    #    $report =~ s/\r//sig;
    $report =~ /<BODY[^>]*>(.+?)<HR>/si;
    $report = $1;
    my $bug = {};
    ( $bug->{num}, $bug->{title} ) =
      $report =~ m#\#(\d+)\<\/A\>\<BR\>(.+?)\<\/H1\>#is;
    &::DEBUG("Bugnum: $bug->{num}\n");
    $bug->{title} =~ s/&lt;/\</g;
    $bug->{title} =~ s/&gt;/\>/g;
    $bug->{title} =~ s/&quot;/\"/g;
    &::DEBUG("Title: $bug->{title}\n");
    $bug->{severity} = 'n';    #Default severity is normal
    my @bug_flags = split /(?<!\&.t)[;\.]\n/s, $report;

    foreach my $bug_flag (@bug_flags) {
        $bug_flag =~ s/\n//g;
        &::DEBUG("Bug_flag: $bug_flag\n");
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
    if ($::DEBUG) {
        use Data::Dumper;
        &::DEBUG( Dumper($bug) );
    }
    return $report;
}

sub old_do_id {
    my ($num) = @_;
    my $url = "http://bugs.debian.org/$num";

    # FIXME
    return "do_id not supported yet.";
}

sub do_email {
    my ($email) = @_;
    my $url = "http://bugs.debian.org/$email";

    # FIXME
    return "do_email not supported yet.";

    my @results = &::getURL($url);
    foreach (@results) {
        &::DEBUG("do_email: $_");
    }
}

sub do_pkg {
    my ($pkg) = @_;
    my $url = "http://bugs.debian.org/$pkg";

    # FIXME
    return "do_pkg not supported yet.";

    my @results = &::getURL($url);
    foreach (@results) {
        &::DEBUG("do_pkg: $_");
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
