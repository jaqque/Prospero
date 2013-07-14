#
# Lame-o-Nickometer backend
#
# (c) 1998 Adam Spiers <adam.spiers@new.ox.ac.uk>
#
# You may do whatever you want with this code, but give me credit.
#
# $Id: nickometer.pl 1839 2008-08-01 19:09:26Z djmcgrath $
#

package nickometer;

use strict;

my $pi      = 3.14159265;
my $score   = 0;
my $verbose = 0;

sub query {
    my ($message) = @_;

    my $term = ( lc $message eq 'me' ) ? $::who : $message;

    if ( $term =~ /^$::mask{chan}$/ ) {
        &::status("Doing nickometer for chan $term.");

        if ( !&::validChan($term) ) {
            &::msg( $::who, "error: channel is invalid." );
            return;
        }

        # step 1.
        my %nickometer;
        foreach ( keys %{ $::channels{ lc $term }{''} } ) {
            my $str = $_;
            if ( !defined $str ) {
                &WARN("nickometer: nick in chan $term undefined?");
                next;
            }

            my $value = &nickometer($str);
            $nickometer{$value}{$str} = 1;
        }

        # step 2.
        ### TODO: compact with map?
        my @list;
        foreach ( sort { $b <=> $a } keys %nickometer ) {
            my $str = join( ', ', sort keys %{ $nickometer{$_} } );
            push( @list, "$str ($_%)" );
        }

        &::performStrictReply(
            &::formListReply( 0, "Nickometer list for $term ", @list ) );

        return;
    }

    my $percentage = &nickometer($term);

    if ( $percentage =~ /NaN/ ) {
        $percentage = 'off the scale';
    }
    else {
        $percentage = sprintf( "%0.4f", $percentage );
        $percentage =~ s/(\.\d+)0+$/$1/;
        $percentage .= '%';
    }

    if ( $::msgType eq 'public' ) {
        &::say("'$term' is $percentage lame, $::who");
    }
    else {
        &::msg( $::who,
            "the 'lame nick-o-meter' reading for $term is $percentage, $::who"
        );
    }

    return;
}

sub nickometer ($) {
    my ($text) = @_;
    $score = 0;

    #  return unless &loadPerlModule("Getopt::Std");
    return unless &::loadPerlModule("Math::Trig");

    if ( !defined $text ) {
        &::DEBUG("nickometer: arg == NULL. $text");
        return;
    }

    # Deal with special cases (precede with \ to prevent de-k3wlt0k)
    my %special_cost = (
        '69'                => 500,
        'dea?th'            => 500,
        'dark'              => 400,
        'n[i1]ght'          => 300,
        'n[i1]te'           => 500,
        'fuck'              => 500,
        'sh[i1]t'           => 500,
        'coo[l1]'           => 500,
        'kew[l1]'           => 500,
        'lame'              => 500,
        'dood'              => 500,
        'dude'              => 500,
        '[l1](oo?|u)[sz]er' => 500,
        '[l1]eet'           => 500,
        'e[l1]ite'          => 500,
        '[l1]ord'           => 500,
        'pron'              => 1000,
        'warez'             => 1000,
        'xx'                => 100,
        '\[rkx]0'           => 1000,
        '\0[rkx]'           => 1000,
    );

    foreach my $special ( keys %special_cost ) {
        my $special_pattern = $special;
        my $raw             = ( $special_pattern =~ s/^\\// );
        my $nick            = $text;
        unless ( defined $raw ) {
            $nick =~ tr/023457+8/ozeasttb/;
        }
        &punish( $special_cost{$special},
            "matched special case /$special_pattern/" )
          if ( defined $nick and $nick =~ /$special_pattern/i );
    }

    # Allow Perl referencing
    $text =~ s/^\\([A-Za-z])/$1/;

    # C-- ain't so bad either
    $text =~ s/^C--$/C/;

    # Punish consecutive non-alphas
    $text =~ s/([^A-Za-z0-9]{2,})
   /my $consecutive = length($1);
    &punish(&slow_pow(10, $consecutive),
	    "$consecutive total consecutive non-alphas")
      if $consecutive;
    $1
   /egx;

   # Remove balanced brackets (and punish a little bit) and punish for unmatched
    while ($text =~ s/^([^()]*)   (\() (.*) (\)) ([^()]*)   $/$1$3$5/x
        || $text =~ s/^([^{}]*)   (\{) (.*) (\}) ([^{}]*)   $/$1$3$5/x
        || $text =~ s/^([^\[\]]*) (\[) (.*) (\]) ([^\[\]]*) $/$1$3$5/x )
    {
        print "Removed $2$4 outside parentheses; nick now $_\n" if $verbose;
        &punish( 15, 'brackets' );
    }
    my $parentheses = $text =~ tr/(){}[]/(){}[]/;
    &punish(
        &slow_pow( 10, $parentheses ),
        "$parentheses unmatched "
          . ( $parentheses == 1 ? 'parenthesis' : 'parentheses' )
    ) if $parentheses;

    # Punish k3wlt0k
    my @k3wlt0k_weights = ( 5, 5, 2, 5, 2, 3, 1, 2, 2, 2 );
    for my $digit ( 0 .. 9 ) {
        my $occurrences = $text =~ s/$digit/$digit/g || 0;
        &punish(
            $k3wlt0k_weights[$digit] * $occurrences * 30,
            $occurrences . ' '
              . ( ( $occurrences == 1 ) ? 'occurrence' : 'occurrences' )
              . " of $digit"
        ) if $occurrences;
    }

    # An alpha caps is not lame in middle or at end, provided the first
    # alpha is caps.
    my $orig_case = $text;
    $text =~ s/^([^A-Za-z]*[A-Z].*[a-z].*?)[_-]?([A-Z])/$1\l$2/;

    # A caps first alpha is sometimes not lame
    $text =~ s/^([^A-Za-z]*)([A-Z])([a-z])/$1\l$2$3/;

    # Punish uppercase to lowercase shifts and vice-versa, modulo
    # exceptions above
    my $case_shifts = &case_shifts($orig_case);
    &punish(
        &slow_pow( 9, $case_shifts ),
        $case_shifts . ' case ' . ( ( $case_shifts == 1 ) ? 'shift' : 'shifts' )
    ) if ( $case_shifts > 1 && /[A-Z]/ );

    # Punish lame endings (TorgoX, WraithX et al. might kill me for this :-)
    &punish( 50, 'last alpha lame' ) if $orig_case =~ /[XZ][^a-zA-Z]*$/;

    # Punish letter to numeric shifts and vice-versa
    my $number_shifts = &number_shifts($_);
    &punish(
        &slow_pow( 9, $number_shifts ),
        $number_shifts
          . ' letter/number '
          . ( ( $number_shifts == 1 ) ? 'shift' : 'shifts' )
    ) if $number_shifts > 1;

    # Punish extraneous caps
    my $caps = $text =~ tr/A-Z/A-Z/;
    &punish( &slow_pow( 7, $caps ), "$caps extraneous caps" ) if $caps;

    # One and only one trailing underscore is OK.
    $text =~ s/\_$//;

    # Now punish anything that's left
    my $remains = $text;
    $remains =~ tr/a-zA-Z0-9//d;
    my $remains_length = length($remains);

    &punish(
        50 * $remains_length + &slow_pow( 9, $remains_length ),
        $remains_length
          . ' extraneous '
          . ( ( $remains_length == 1 ) ? 'symbol' : 'symbols' )
    ) if $remains;

    print "\nRaw lameness score is $score\n" if $verbose;

    # Use an appropriate function to map [0, +inf) to [0, 100)
    my $percentage = 100 * ( 1 + &Math::Trig::tanh( ( $score - 400 ) / 400 ) ) *
      ( 1 - 1 / ( 1 + $score / 5 ) ) / 2;

    my $digits = 2 * ( 2 - &round_up( log( 100 - $percentage ) / log(10) ) );

    return sprintf "%.${digits}f", $percentage;
}

sub case_shifts ($) {

    # This is a neat trick suggested by freeside.  Thanks freeside!

    my $shifts = shift;

    $shifts =~ tr/A-Za-z//cd;
    $shifts =~ tr/A-Z/U/s;
    $shifts =~ tr/a-z/l/s;

    return length($shifts) - 1;
}

sub number_shifts ($) {
    my $shifts = shift;

    $shifts =~ tr/A-Za-z0-9//cd;
    $shifts =~ tr/A-Za-z/l/s;
    $shifts =~ tr/0-9/n/s;

    return length($shifts) - 1;
}

sub slow_pow ($$) {
    my ( $x, $y ) = @_;

    return $x**&slow_exponent($y);
}

sub slow_exponent ($) {
    my $x = shift;

    return 1.3 * $x * ( 1 - &Math::Trig::atan( $x / 6 ) * 2 / $pi );
}

sub round_up ($) {
    my $float = shift;

    return int($float) + ( ( int($float) == $float ) ? 0 : 1 );
}

sub punish ($$) {
    my ( $damage, $reason ) = @_;

    return unless $damage;

    $score += $damage;
    print "$damage lameness points awarded: $reason\n" if $verbose;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
