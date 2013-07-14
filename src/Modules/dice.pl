#!/usr/bin/perl

# dice rolling
# hacked up by Tim Riker <Tim@Rikers.org> from Games::Dice

package dice;

use strict;
use warnings;

sub dice::roll_array ($) {
    my ($line) = shift;

    my (@throws) = ();
    return @throws unless $line =~ m{
                 ^      # beginning of line
                 (\d+)? # optional count in $1
                 [dD]   # 'd' for dice
                 (      # type of dice in $2:
                    \d+ # either one or more digits
                  |     # or
                    %   # a percent sign for d% = d100
                 )
              }x;    # whitespace allowed

    my ($num) = $1 || 1;
    my ($type) = $2;

    return @throws if $num > 100;
    $type = 100 if $type eq '%';
    return @throws if $type < 2;

    for ( 1 .. $num ) {
        push @throws, int( rand $type ) + 1;
    }

    return @throws;
}

sub dice::roll ($) {
    my ($line) = shift;

    $line =~ s/ //g;

    return '' unless $line =~ m{
                 ^              # beginning of line
                 (              # dice string in $1
                   (?:\d+)?     # optional count
                   [dD]         # 'd' for dice
                   (?:          # type of dice:
                      \d+       # either one or more digits
                    |           # or
                      %         # a percent sign for d% = d100
                   )
                 )
                 (?:            # grouping-only parens
                   ([-+xX*/bB]) # a + - * / b(est) in $2
                   (\d+)        # an offset in $3
                 )?             # both of those last are optional
              }x;    # whitespace allowed in re

    my ($dice_string) = $1;
    my ($sign)        = $2 || '';
    my ($offset)      = $3 || 0;

    $sign = lc $sign;

    my (@throws) = roll_array($dice_string);
    return '' unless @throws > 0;
    my ($retval) = "rolled " . join( ',', @throws );

    my (@result);
    if ( $sign eq 'b' ) {
        $offset = 0       if $offset < 0;
        $offset = @throws if $offset > @throws;

        @throws = sort { $b <=> $a } @throws;  # sort numerically, descending
        @result = @throws[ 0 .. $offset - 1 ]; # pick off the $offset first ones
        $retval .= " best $offset";
    }
    else {
        @result = @throws;
        $retval .= " $sign $offset" if $sign;
    }

    my ($sum) = 0;
    $sum += $_ foreach @result;
    $sum += $offset if $sign eq '+';
    $sum -= $offset if $sign eq '-';
    $sum *= $offset if ( $sign eq '*' || $sign eq 'x' );
    do { $sum /= $offset; $sum = int $sum; } if $sign eq '/';

    return "$retval = $sum";
}

sub dice::dice {
    my ($message) = @_;
    srand();    # fork seems to not change rand. force it here
    my $retval = roll($message);

    &::performStrictReply($retval);
}

#print "(q)uit or die combination, ex. 4d10/4\n";
#while (my $dice = <STDIN>) {
#    chomp $dice;
#    if (! $dice || $dice =~ m/^q(?:uit)*$/i) {
#	print "done\n";
#	exit;
#    } else {
#	print roll($dice) . "\n";
#    }
#}

1;

__END__

=pod

=head1 NAME

dice.pl - simulate die rolls

=head1 SYNOPSIS

  'dice 3d6+1';

=head1 DESCRIPTION

The number and type of dice to roll is given in a style which should be
familiar to players of popular role-playing games: I<a>dI<b>[+-*/b]I<c>.
I<a> is optional and defaults to 1; it gives the number of dice to roll.
I<b> indicates the number of sides to each die; the most common,
cube-shaped die is thus a d6. % can be used instead of 100 for I<b>;
hence, rolling 2d% and 2d100 is equivalent. C<roll> simulates I<a> rolls
of I<b>-sided dice and adds together the results. The optional end,
consisting of one of +-*/b and a number I<c>, can modify the sum of the
individual dice. +-*/ are similar in that they take the sum of the rolls
and add or subtract I<c>, or multiply or divide the sum by I<c>. (x can
also be used instead of *.) Hence, 1d6+2 gives a number in the range
3..8, and 2d4*10 gives a number in the range 20..80. (Using / truncates
the result to an int after dividing.) Using b in this slot is a little
different: it's short for "best" and indicates "roll a number of dice,
but add together only the best few". For example, 5d6b3 rolls five six-
sided dice and adds together the three best rolls. This is sometimes
used, for example, in roll-playing to give higher averages.

=head1 AUTHOR

Philip Newton, <pne@cpan.org>

Tim Riker <Tim@Rikers.org>

=head1 LICENCE

Copyright (C) 1999, 2002 Philip Newton - All rights reserved.

Copyright (C) 2005 Tim Riker - All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

=over 4

=item *

Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

=item *

Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

=cut

# vim:ts=4:sw=4:expandtab:tw=80
