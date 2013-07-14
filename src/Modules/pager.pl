# Pager
#
# modified from pager.pm in flooterbuck changes are:
#
# Copyright (c) 2004 Tim Riker <Tim@Rikers.org>
#
# This package is free software;  you can redistribute it and/or
# modify it under the terms of the license found in the file
# named LICENSE that should have accompanied this file.
#
# THIS PACKAGE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

package pager;
use strict;

my $no_page;

BEGIN {
    eval qq{
		use Mail::Mailer qw(sendmail);
	};
    $no_page++ if ($@);
}

sub pager::page {
    my ($message) = @_;
    my ($retval);

    # TODO only allow registered users?

    if ($no_page) {
        &::status('page module requires Mail::Mailer.');
        return 'page module not active';
    }

    unless ( $message =~ /^(\S+)\s+(.*)$/ ) {
        return undef;
    }

    my $from = $::who;
    my $to   = $1;
    my $msg  = $2;

    # allow optional trailing : ie: page foo[:] hello
    $to =~ s/:$//;

    my $tofactoid = &::getFactoid( lc "${to}'s pager" );
    if ( $tofactoid =~ /(\S+@\S+)/ ) {
        my $toaddr = $1;
        $toaddr =~ s/^mailto://;

        # TODO require sender-locked factoid?

        my $fromfactoid = &::getFactoid( lc "${from}'s pager" );

        my $fromaddr;
        if ( $fromfactoid =~ /(\S+@\S+)/ ) {
            $fromaddr = $1;
            $fromaddr =~ s/^mailto://;
        }
        else {

            # TODO require sender to have valid self-locked pager factoid?
            $fromaddr = 'infobot@example.com';
        }

        my $channel = $::chan || 'infobot';

        # TODO disallow use from private message? $chan='_default'

        &::status(
            "pager: from $from <$fromaddr>, to $to <$toaddr>, msg \"$msg\"");
        my %headers = (
            To         => "$to <$toaddr>",
            From       => "$from <$fromaddr>",
            Subject    => "Message from $channel!",
            'X-Mailer' => 'infobot',
        );

        #		my $logmsg;
        #		for (keys %headers) {
        #			$logmsg .= "$_: $headers{$_}\n";
        #		}
        #		$logmsg .= "\n$msg\n";
        #		&::status("pager:\n$logmsg");

        my $failed;
        my $mailer = new Mail::Mailer 'sendmail';
        $failed++ unless $mailer->open( \%headers );
        $failed++ unless print $mailer "$msg\n";
        $failed++ unless $mailer->close;

        if ($failed) {
            $retval = 'Sorry, an error occurred while sending mail.';
        }
        else {
            $retval = "$from: I sent mail to $toaddr from $fromaddr.";
        }
    }
    else {
        $retval = "Sorry, I don't know ${to}'s email address.";
    }
    &::performStrictReply($retval);
}

'pager';

# vim:ts=4:sw=4:expandtab:tw=80
