#
# insult.pl: insult engine
#
# 2004.10.21  Tim Riker <Tim@Rikers.org>
# colorado server is dead. pull in the words and do it ourself
#

package Insult;

use strict;

sub Insult {
    my ($insultwho) = @_;
    my @adjs;
    my @amts;
    my @nouns;
    &::DEBUG('Reading insult data');
    while (<DATA>) {
        chomp;
        push( @adjs,  split( ' ', $1 ) ) if /^adj\s*(.*)/;
        push( @amts,  split( ' ', $1 ) ) if /^amt\s*(.*)/;
        push( @nouns, split( ' ', $1 ) ) if /^noun\s*(.*)/;
    }
    grep( s/\|/ /g, @adjs );
    grep( s/\|/ /g, @amts );
    grep( s/\|/ /g, @nouns );
    srand();    # fork seems to not change rand. force it here
    my $adj = @adjs[ rand(@adjs) ];
    my $n;
    $n = 'n' if $adj =~ /^[aeiouih]/;
    my $amt   = @amts[ rand(@amts) ];
    my $adj2  = @adjs[ rand(@adjs) ];
    my $noun  = @nouns[ rand(@nouns) ];
    my $whois = "$insultwho is";
    $whois = 'You are' if ( $insultwho eq $::who or $insultwho eq 'me' );

    &::performStrictReply("$whois nothing but a$n $adj $amt of $adj2 $noun");
}

1;

# vim:ts=4:sw=4:expandtab:tw=80

__DATA__
#
# configuration file for colorado insult server
#
# Use the '|' character to include a space in the middle of a noun, adjective
# or amount (it'll get transmogrified into a space.  No, really!).
#
# Mon Mar 16 10:49:53 MST 1992 garnett added more colorful insults
# Fri Dec  6 10:48:43 MST 1991 garnett
#

##
# Adjectives
##
adj acidic antique contemptible culturally-unsound despicable evil fermented
adj festering foul fulminating humid impure inept inferior industrial
adj left-over low-quality malodorous off-color penguin-molesting
adj petrified pointy-nosed salty sausage-snorfling tastless tempestuous
adj tepid tofu-nibbling unintelligent unoriginal uninspiring weasel-smelling
adj wretched spam-sucking egg-sucking decayed halfbaked infected squishy
adj porous pickled coughed-up thick vapid hacked-up
adj unmuzzled bawdy vain lumpish churlish fobbing rank craven puking
adj jarring fly-bitten pox-marked fen-sucked spongy droning gleeking warped
adj currish milk-livered surly mammering ill-borne beef-witted tickle-brained
adj half-faced headless wayward rump-fed onion-eyed beslubbering villainous
adj lewd-minded cockered full-gorged rude-snouted crook-pated pribbling
adj dread-bolted fool-born puny fawning sheep-biting dankish goatish
adj weather-bitten knotty-pated malt-wormy saucyspleened motley-mind
adj it-fowling vassal-willed loggerheaded clapper-clawed frothy ruttish
adj clouted common-kissing pignutted folly-fallen plume-plucked flap-mouthed
adj swag-bellied dizzy-eyed gorbellied weedy reeky measled spur-galled mangled
adj impertinent bootless toad-spotted hasty-witted horn-beat yeasty
adj imp-bladdereddle-headed boil-brained tottering hedge-born hugger-muggered
adj elf-skinned

##
# Amounts
##
amt accumulation bucket coagulation enema-bucketful gob half-mouthful
amt heap mass mound petrification pile puddle stack thimbleful tongueful
amt ooze quart bag plate ass-full assload

##
# Objects
##
noun bat|toenails bug|spit cat|hair chicken|piss dog|vomit dung
noun fat-woman's|stomach-bile fish|heads guano gunk pond|scum rat|retch
noun red|dye|number-9 Sun|IPC|manuals waffle-house|grits yoo-hoo
noun dog|balls seagull|puke cat|bladders pus urine|samples
noun squirrel|guts snake|assholes snake|bait buzzard|gizzards
noun cat-hair-balls rat-farts pods armadillo|snouts entrails
noun snake|snot eel|ooze slurpee-backwash toxic|waste Stimpy-drool
noun poopy poop craptacular|carpet|droppings jizzum cold|sores anal|warts
