#
# countdown.pl: Count down to a particular date.
#       Author: dms
#      Version: v0.1 (20000104)
#      Created: 20000104
#

use strict;

#use vars qw();

sub countdown {
    my ($query) = @_;
    my $file = "$bot_data_dir/$param{'ircUser'}.countdown";
    my ( %date, %desc );
    my $reply;

    if ( !open( IN, $file ) ) {
        &ERROR("cannot open $file.");
        return 0;
    }

    while (<IN>) {
        chop;
        s/[\s\t]+/ /g;

        if (/^(\d{8}) (\S+) (.*)$/) {
            $date{$2} = $1;
            $desc{$2} = $3;
        }
    }
    close IN;

    if ( defined $query ) {    # argument.
        if ( !exists $date{$query} ) {
            &msg( $who, "error: $query is not in my countdown list." );
            return 0;
        }

        $date{$query} =~ /^(\d{4})(\d{2})(\d{2})$/;
        my ( $year, $month, $day ) = ( $1, $2, $3 );
        my $sqldate = "$1-$2-$3";

        ### SQL SPECIFIC.
        my ( $to_days, $dayname, $monname );

        if ( $param{'DBType'} =~ /^(mysql|sqlite(2)?)$/i ) {
            $to_days =
              ( &sqlRawReturn("SELECT TO_DAYS(NOW()) - TO_DAYS('$sqldate')") )
              [0];
            $dayname = ( &sqlRawReturn("SELECT DAYNAME('$sqldate')") )[0];
            $monname = ( &sqlRawReturn("SELECT MONTHNAME('$sqldate')") )[0];

        }
        elsif ( $param{'DBType'} =~ /^pgsql$/i ) {
            $to_days = (
                &sqlRawReturn(
                    "SELECT date_trunc('day',
				'now'::timestamp - '$sqldate')"
                )
            )[0];
            $dayname = qw(Sun Mon Tue Wed Thu Fri Sat) [
                (
                    &sqlRawReturn(
                        "SELECT extract(dow from timestamp '$sqldate')")
                )[0]
            ];
            $monname = qw(BAD Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec) [
                (
                    &sqlRawReturn(
                        "SELECT extract(month from timestamp '$sqldate')")
                )[0]
            ];

        }
        else {
            &ERROR( "countdown: invalid DBType " . $param{'DBType'} . "." );
            return 1;
        }

        if ( $to_days =~ /^\D+$/ ) {
            my $str = "to_days is not integer.";
            &msg( $who, $str );
            &ERROR($str);

            return 1;
        }

        my @gmtime = gmtime( time() );
        my $daysec =
          ( $gmtime[2] * 60 * 60 ) + ( $gmtime[1] * 60 ) + ( $gmtime[0] );
        my $time = ( $to_days * 24 * 60 * 60 );

        if ( $to_days >= 0 ) {    # already passed.
            $time += $daysec;
            $reply = "T plus " . &Time2String($time) . " ago";
        }
        else {                    # time to go.
            $time  = -$time - $daysec;
            $reply = "T minus " . &Time2String($time);
        }
        $reply .=
          ", \002(\002$desc{$query}\002)\002 at $dayname, $monname $day $year";

        &performStrictReply( $reply . "." );
        return 1;
    }
    else {                        # no argument.
        my $prefix = "countdown list ";

        &performStrictReply( &formListReply( 0, $prefix, sort keys %date ) );

        return 1;
    }
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
