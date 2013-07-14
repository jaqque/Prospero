#
#  botmail.pl: Botmail (ala in infobot)
#      Author: dms
#     Version: v0.1 (20021122).
#     Created: 20021122
#	 NOTE: Motivated by TimRiker.
#        TODO: full-fledged notes services (optional auth, etc)
#

package botmail;

use strict;

sub parse {
    my ($what) = @_;

    if ( !defined $what or $what =~ /^\s*$/ ) {
        &::help('botmail');
        return;
    }

    if ( $what =~ /^(to|for|add)\s+(.*)$/i ) {
        &add( split( /\s+/, $2, 2 ) );

    }
    elsif ( $what =~ /^stats?$/i ) {
        &stats();

    }
    elsif ( $what =~ /^check?$/i ) {
        &check( $1, 1 );

    }
    elsif ( $what =~ /^(read|next)$/i ) {

        # TODO: read specific items? nah, will make this too complex.
        &next($::who);

    }
}

sub stats {
    my $botmail = &::countKeys('botmail');
    &::msg( $::who,
            "I have \002$botmail\002 "
          . &::fixPlural( 'message', $botmail )
          . "." );
}

#####
# Usage: botmail::check($recipient, [$always])
sub check {
    my ( $recipient, $always ) = @_;
    $recipient ||= $::who;

    my %from =
      &::sqlSelectColHash( 'botmail', "srcwho,time",
        { dstwho => lc $recipient } );
    my $t = keys %from;
    my $from = join( ", ", keys %from );

    if ( $t == 0 ) {
        &::msg( $recipient, "You have no botmail." ) if ($always);
    }
    else {
        &::msg( $recipient,
            "You have $t messages awaiting, from: $from (botmail read)" );
    }
}

#####
# Usage: botmail::next($recipient)
sub next {
    my ($recipient) = @_;

    my %hash =
      &::sqlSelectRowHash( 'botmail', '*', { dstwho => lc $recipient } );

    if ( scalar( keys %hash ) <= 1 ) {
        &::msg( $recipient, "You have no botmail." );
    }
    else {
        my $date = scalar( gmtime $hash{'time'} );
        my $ago  = &::Time2String( time() - $hash{'time'} );
        &::msg( $recipient,
            "From $hash{srcwho} ($hash{srcuh}) on $date ($ago ago):" );
        &::msg( $recipient, $hash{'msg'} );
        &::sqlDelete( 'botmail',
            { 'dstwho' => $hash{dstwho}, 'srcwho' => $hash{srcwho} } );
    }
}

#####
# Usage: botmail::add($recipient, $msg)
sub add {
    my ( $recipient, $msg ) = @_;
    &::DEBUG("botmail::add(@_)");

    # allow optional trailing : ie: botmail for foo[:] hello
    $recipient =~ s/:$//;

# only support 1 botmail with unique dstwho/srcwho to have same
# functionality as botmail from infobot.
# Note: I removed the &::sqlQuote reference. Seems to be working and inserting fine without it here. -- troubled
    my %hash = &::sqlSelectRowHash(
        'botmail',
        '*',
        {
            srcwho => lc $::who,
            dstwho => lc $recipient
        }
    );

    if ( scalar( keys %hash ) > 1 ) {
        &::msg( $::who, "$recipient already has a message queued from you" );
        return;
    }

    &::sqlInsert(
        'botmail',
        {
            'dstwho' => lc $recipient,
            'srcwho' => lc $::who,
            'srcuh'  => $::nuh,
            'time'   => time(),
            'msg'    => $msg,
        }
    );

    &::msg( $::who, "OK, $::who, I'll let $recipient know." );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
