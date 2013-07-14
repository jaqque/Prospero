#!/usr/bin/perl
#
# OnJoin.pl: emit a message when a user enters the channel
#    Author: Corey Edwards <tensai@zmonkey.org>
#   Version: v0.3.1
#   Created: 20051222
#   Updated: 20060112

use strict;

use vars qw(%channels %param);
use vars qw($dbh $who $chan);

sub onjoin {
    my ( $nick, $user, $host, $chan ) = @_;
    $nick = lc $nick;

    # look for a channel specific message
    my $message =
      &sqlSelect( 'onjoin', 'message', { nick => $nick, channel => $chan } )
      || 0;

    # look for a default message
    if ( !$message ) {
        $message =
          &sqlSelect( 'onjoin', 'message',
            { nick => $nick, channel => '_default' } )
          || 0;
    }

    # print the message, if there was one
    if ($message) {
        $message = substVars( $message, 1 );
        if ( $message =~ m/^<action>\s*(.*)/ ) {
            &status("OnJoin: $nick arrived, performing action");
            &action( $chan, $1 );
        }
        else {
            $message =~ s/^<reply>\s*//;
            &status("OnJoin: $nick arrived, printing message");
            &msg( $chan, $message );
        }
    }

    return;
}

# set and get messages
sub Cmdonjoin {
    $_ = shift;
    m/(\S*)(\s*(\S*)(\s*(.*)|)|)/;
    my $ch   = $1;
    my $nick = $3;
    my $msg  = $5;

    # get options
    my $strict = &getChanConf('onjoinStrict');
    my $ops    = &getChanConf('onjoinOpsOnly');

    # see if they specified a channel
    if ( $ch !~ m/^\#/ && $ch ne '_default' ) {
        $msg  = $nick . ( $msg ? " $msg" : '' );
        $nick = $ch;
        $ch   = $chan;
    }

    $nick = lc $nick;

    if ( $nick =~ m/^-(.*)/ ) {
        $nick = $1;
        if ($ops) {
            if ( !$channels{$chan}{o}{$who} ) {
                &performReply("sorry, you're not an operator");
            }
        }
        elsif ($strict) {

            # regardless of strict mode, ops can always change
            if ( !$channels{$chan}{o}{$who} and $nick ne $who ) {
                &performReply(
                    "I can't alter a message for another user (strict mode)");
            }
        }
        else {
            &sqlDelete( 'onjoin', { nick => $nick, channel => $ch } );
            &performReply('ok');
        }
        return;
    }

    # if msg not set, show what the message would be
    if ( !$msg ) {
        $nick = $who if ( !$nick );
        my %row = &sqlSelectRowHash(
            'onjoin',
            'message, modified_by, modified_time',
            { nick => $nick, channel => $ch }
        );
        if ( $row{'message'} ) {
            &performStrictReply( "onjoin for $nick set by $row{modified_by} on "
                  . localtime( $row{modified_time} )
                  . ": $row{message}" );
        }
        return;
    }

    # only allow changes by ops
    if ($ops) {
        if ( !$channels{$chan}{o}{$who} ) {
            &performReply("sorry, you're not an operator");
            return;
        }
    }

    # only allow people to change their own message (superceded by OpsOnly)
    elsif ($strict) {

        # regardless of strict mode, ops can always change
        if ( !$channels{$chan}{o}{$who} and $nick ne $who ) {
            &performReply(
                "I can't alter a message for another user (strict mode)");
            return;
        }
    }

    # remove old one (if exists) and add new message
    &sqlDelete( 'onjoin', { nick => $nick, channel => $ch } );
    my $insert = &sqlInsert(
        'onjoin',
        {
            nick          => $nick,
            channel       => $ch,
            message       => $msg,
            modified_by   => $who,
            modified_time => time()
        }
    );
    if ($insert) {
        &performReply('ok');
    }
    else {
        &performReply('whoops. database error');
    }
    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
