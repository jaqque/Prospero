#
#   Norm.pl: Norm.
#    Author: Kevin Lenzo
#   Version: 1997
#

# TODO:
# use strict;

sub normquery {
    my ($in) = @_;

    $in = " $in ";

    for ($in) {

        # where blah is -> where is blah
        s/ (where|what|who)\s+(\S+)\s+(is|are) / $1 $3 $2 /i;

        # where blah is -> where is blah
        s/ (where|what|who)\s+(.*)\s+(is|are) / $1 $3 $2 /i;

        s/^\s*(.*?)\s*/$1/;

        s/be tellin\'?g?/tell/i;
        s/ \'?bout/ about/i;

        s/,? any(hoo?w?|ways?)/ /ig;
        s/,?\s*(pretty )*please\??\s*$/\?/i;

        # what country is ...
        if ( $in =~
s/wh(at|ich)\s+(add?res?s|country|place|net (suffix|domain))/wh$1 /ig
          )
        {
            if ( ( length($in) == 2 ) && ( $in !~ /^\./ ) ) {
                $in = '.' . $in;
            }
            $in .= '?';
        }

        # profanity filters.  just delete it
s/th(e|at|is) (((m(o|u)th(a|er) ?)?fuck(in\'?g?)?|hell|heck|(god-?)?damn?(ed)?) ?)+//ig;
        s/wtf/where/gi;
        s/this (.*) thingy?/ $1/gi;
        s/this thingy? (called )?//gi;
        s/ha(s|ve) (an?y?|some|ne) (idea|clue|guess|seen) /know /ig;
        s/does (any|ne|some) ?(1|one|body) know //ig;
        s/do you know //ig;
s/can (you|u|((any|ne|some) ?(1|one|body)))( please)? tell (me|us|him|her)//ig;
        s/where (\S+) can \S+ (a|an|the)?//ig;
        s/(can|do) (i|you|one|we|he|she) (find|get)( this)?/is/i
          ;    # where can i find
        s/(i|one|we|he|she) can (find|get)/is/gi; # where i can find
        s/(the )?(address|url) (for|to) //i;      # this should be more specific
        s/(where is )+/where is /ig;
        s/\s+/ /g;
        s/^\s+//;

        if ( $in =~ s/\s*[\/?!]*\?+\s*$// ) {
            $finalQMark = 1;
        }

        s/\s+/ /g;
        s/^\s*(.*?)\s*$/$1/;
        s/^\s+|\s+$//g;                           # why twice, see Question.pl
    }

    return $in;
}

# for be-verbs
sub switchPerson {
    my ($in) = @_;

    for ($in) {

        # # fix genitives
        s/(^|\W)\Q$who\Es\s+/$1${who}\'s /ig;
        s/(^|\W)\Q$who\Es$/$1${who}\'s/ig;
        s/(^|\W)\Q$who\E\'(\s|$)/$1${who}\'s$2/ig;

        s/(^|\s)i\'m(\W|$)/$1$who is$2/ig;
        s/(^|\s)i\'ve(\W|$)/$1$who has$2/ig;
        s/(^|\s)i have(\W|$)/$1$who has$2/ig;
        s/(^|\s)i haven\'?t(\W|$)/$1$who has not$2/ig;
        s/(^|\s)i(\W|$)/$1$who$2/ig;
        s/ am\b/ is/i;
        s/\bam /is/i;
        s/(^|\s)(me|myself)(\W|$)/$1$who$3/ig;
        s/(^|\s)my(\W|$)/$1${who}\'s$2/ig;    # turn 'my' into name's
        s/(^|\W)you\'?re(\W|$)/$1you are$2/ig;

        if ($addressed) {
            my $mynick = 'UNDEF';
            $mynick = $conn->nick() if ($conn);

            # is it safe to remove $in from here, too?
            $in =~ s/yourself/$mynick/i;
            $in =~ s/(^|\W)are you(\W|$)/$1is $mynick$2/ig;
            $in =~ s/(^|\W)you are(\W|$)/$1$mynick is$2/ig;
            $in =~ s/(^|\W)you(\W|$)/$1$mynick$2/ig;
            $in =~ s/(^|\W)your(\W|$)/$1$mynick\'s$2/ig;
        }
    }

    return $in;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
