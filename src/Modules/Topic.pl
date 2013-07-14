#
# Topic.pl: Advanced topic management (maxtopiclen>=512)
#   Author: dms
#  Version: v0.8 (19990919).
#  Created: 19990720
#

use strict;
use vars qw(%topiccmp %topic %channels %cache %orig);
use vars qw($who $chan $conn $uh $ident);

###############################
##### INTERNAL FUNCTIONS
###############################

###
# Usage: &topicDecipher(chan);
sub topicDecipher {
    my ($chan) = @_;
    my @results;

    return if ( !exists $topic{$chan} );
    return if ( !exists $topic{$chan}{'Current'} );

    foreach ( split /\|\|/, $topic{$chan}{'Current'} ) {
        s/^\s+//;
        s/\s+$//;

        # very nice fix to solve the null subtopic problem.
        # if nick contains a space, treat topic as ownerless.
        if (/^\(.*?\)$/) {
            next unless ( $1 =~ /\s/ );
        }

        my $subtopic = $_;
        my $owner    = 'Unknown';

        if (/(.*)\s+\((.*?)\)$/) {
            $subtopic = $1;
            $owner    = $2;
        }

        if ( grep /^\Q$subtopic\E\|\|\Q$owner\E$/, @results ) {
            &status(
"Topic: we have found a dupe ($subtopic) in the topic, not adding."
            );
            next;
        }

        push( @results, "$subtopic||$owner" );
    }

    return @results;
}

###
# Usage: &topicCipher(@topics);
sub topicCipher {
    return if ( !@_ );

    my @topic;
    foreach (@_) {
        my ( $subtopic, $setby ) = split /\|\|/;

        if ( $param{'topicAuthor'} eq '1' and ( !$setby =~ /^(unknown|)$/i ) ) {
            push( @topic, "$subtopic ($setby)" );
        }
        else {
            push( @topic, "$subtopic" );
        }
    }

    return join( ' || ', @topic );
}

###
# Usage: &topicNew($chan, $topic, $updateMsg);
sub topicNew {
    my ( $chan, $topic, $updateMsg ) = @_;
    my $maxlen = 470;

    if ( $channels{$chan}{t} and !$channels{$chan}{o}{$ident} ) {
        &msg( $who,
            "error: cannot change topic without ops. (channel is +t) :(" );
        return 0;
    }

    if ( defined $topiccmp{$chan} and $topiccmp{$chan} eq $topic ) {
        &msg( $who,
            "warning: action had no effect on topic; no change required." );
        return 0;
    }

    # bail out if the new topic is too long.
    my $newlen = length( $chan . $topic );
    if ( $newlen > $maxlen ) {
        &msg( $who, "new topic will be too long. ($newlen > $maxlen)" );
        return 0;
    }

    $topic{$chan}{'Current'} = $topic;

    if ( $cache{topicNotUpdate}{$chan} ) {
        &msg( $who, "done. 'flush' to finalize changes." );
        delete $cache{topicNotUpdate}{$chan};
        return 1;
    }

    if ( defined $updateMsg && $updateMsg ne '' ) {
        &msg( $who, $updateMsg );
    }

    $topic{$chan}{'Last'} = $topic;
    $topic{$chan}{'Who'}  = $orig{who} . "!" . $uh;
    $topic{$chan}{'Time'} = time();

    if ($topic) {
        $conn->topic( $chan, $topic );
        &topicAddHistory( $chan, $topic );
    }
    else {
        $conn->topic( $chan, ' ' );
    }

    return 1;
}

###
# Usage: &topicAddHistory($chan,$topic);
sub topicAddHistory {
    my ( $chan, $topic ) = @_;
    my $dupe = 0;

    return 1 if ( $topic eq '' );    # required fix.

    foreach ( @{ $topic{$chan}{'History'} } ) {
        next if ( $_ ne '' and $_ ne $topic );

        # checking length is required.

        # slightly weird to put a return statement in a loop.
        return 1;
    }

    # WTF IS THIS FOR?

    my @topics = @{ $topic{$chan}{'History'} };
    unshift( @topics, $topic );
    pop(@topics) while ( scalar @topics > 6 );
    $topic{$chan}{'History'} = \@topics;

    return $dupe;
}

###############################
##### HELPER FUNCTIONS
###############################

# cmd: add.
sub do_add {
    my ( $chan, $args ) = @_;

    if ( $args eq '' ) {
        &help('topic add');
        return;
    }

    # heh, joeyh. 19990819. -xk
    if ( $who =~ /\|\|/ ) {
        &msg( $who, 'error: you have an invalid nick, loser!' );
        return;
    }

    return if ( $channels{$chan}{t} and !&hasFlag('T') );

    my @prev = &topicDecipher($chan);
    my $new;

    # If bot new to chan and topic is blank, it still got a (owner). This is fix
    if ( $param{'topicAuthor'} eq '1' ) {
        $new = "$args ($orig{who})";
    }
    else {
        $new = "$args";
    }
    $topic{$chan}{'What'} = "Added '$args'.";

    if ( scalar @prev ) {
        my $str = sprintf( "%s||%s", $args, $who );
        $new = &topicCipher( @prev, $str );
    }

    &topicNew( $chan, $new, '' );
}

# cmd: delete.
sub do_delete {
    my ( $chan, $args ) = @_;
    my @subtopics  = &topicDecipher($chan);
    my $topiccount = scalar @subtopics;

    if ( $topiccount == 0 ) {
        &msg( $who, 'No topic set.' );
        return;
    }

    if ( $args eq '' ) {
        &help('topic del');
        return;
    }

    for ($args) {
        $_ = sprintf( ",%s,", $args );
        s/\s+//g;
        s/(first|1st)/1/i;
        s/last/$topiccount/i;
        s/,-(\d+)/,1-$1/;
        s/(\d+)-,/,$1-$topiccount/;
    }

    if ( $args !~ /[\,\-\d]/ ) {
        &msg( $who, "error: Invalid argument ($args)." );
        return;
    }

    my @delete;
    foreach ( split ',', $args ) {
        next if ( $_ eq '' );

        # change to hash list instead of array?
        if (/^(\d+)-(\d+)$/) {
            my ( $from, $to ) = ( $1, $2 );
            ( $from, $to ) = ( $2, $1 ) if ( $from > $to );

            push( @delete, $1 .. $2 );
        }
        elsif (/^(\d+)$/) {
            push( @delete, $1 );
        }
        else {
            &msg( $who, "error: Invalid sub-argument ($_)." );
            return;
        }

        $topic{$chan}{'What'} = 'Deleted ' . join( "/", @delete );
    }

    foreach (@delete) {
        if ( $_ > $topiccount || $_ < 1 ) {
            &msg( $who, "error: argument out of range. (max: $topiccount)" );
            return;
        }

        # skip if already deleted.
        # only checked if x-y range is given.
        next unless ( defined( $subtopics[ $_ - 1 ] ) );

        my ( $subtopic, $whoby ) = split( '\|\|', $subtopics[ $_ - 1 ] );

        $whoby = 'unknown' if ( $whoby eq '' );

        &msg( $who, "Deleting topic: $subtopic ($whoby)" );
        undef $subtopics[ $_ - 1 ];
    }

    my @newtopics;
    foreach (@subtopics) {
        next unless ( defined $_ );
        push( @newtopics, $_ );
    }

    &topicNew( $chan, &topicCipher(@newtopics), '' );
}

# cmd: list
sub do_list {
    my ( $chan, $args ) = @_;
    my @topics = &topicDecipher($chan);

    if ( !scalar @topics ) {
        &msg( $who, "No topics for \002$chan\002." );
        return;
    }

    &msg( $who, "Topics for \002$chan\002:" );
    &msg( $who, "No  \002[\002  Set by  \002]\002 Topic" );

    my $i = 1;
    foreach (@topics) {
        my ( $subtopic, $setby ) = split /\|\|/;

        my $str = sprintf( " %d. [%-10s] %s", $i, $setby, $subtopic );

        # is there a better way of doing this?
        $str =~ s/ (\[)/ \002$1/g;
        $str =~ s/ (\])/ \002$1/g;

        &msg( $who, $str );
        $i++;
    }

    &msg( $who, "End of Topics." );
}

# cmd: modify.
sub do_modify {
    my ( $chan, $args ) = @_;

    if ( $args eq '' ) {
        &help('topic mod');
        return;
    }

    # a warning message instead of halting. we kind of trust the user now.
    if ( $args =~ /\|\|/ ) {
        &msg( $who,
            "warning: adding double pipes manually == evil. be warned." );
    }

    $topic{$chan}{'What'} = "SAR $args";

    # SAR patch. mu++
    if ( $args =~ m|^\s*s([/,#])(.+?)\1(.*?)\1([a-z]*);?\s*$| ) {
        my ( $delim, $op, $np, $flags ) = ( $1, $2, $3, $4 );

        if ( $flags !~ /^(g)?$/ ) {
            &msg( $who, "error: Invalid flags to regex." );
            return;
        }

        my $topic = $topic{$chan}{'Current'};

        ### TODO: use m### to make code safe!
        if (   ( $flags eq 'g' and $topic =~ s/\Q$op\E/$np/g )
            || ( $flags eq '' and $topic =~ s/\Q$op\E/$np/ ) )
        {

            $_ = "Modifying topic with sar s/$op/$np/.";
            &topicNew( $chan, $topic, $_ );
        }
        else {
            &msg( $who, "warning: regex not found in topic." );
        }

        return;
    }

    &msg( $who, "error: Invalid regex. Try s/1/2/, s#3#4#..." );
}

# cmd: move.
sub do_move {
    my ( $chan, $args ) = @_;

    if ( $args eq '' ) {
        &help('topic mv');
        return;
    }

    my ( $from, $action, $to );

    # better way of doing this?
    if ( $args =~
        /^(first|last|\d+)\s+(before|after|swap)\s+(first|last|\d+)$/i )
    {
        ( $from, $action, $to ) = ( $1, $2, $3 );
    }
    else {
        &msg( $who, "Invalid arguments." );
        return;
    }

    my @subtopics = &topicDecipher($chan);
    my @newtopics;
    my $topiccount = scalar @subtopics;

    if ( $topiccount == 1 ) {
        &msg( $who, "error: impossible to move the only subtopic, dumbass." );
        return;
    }

    # Is there an easier way to do this?
    $from =~ s/first/1/i;
    $to   =~ s/first/1/i;
    $from =~ s/last/$topiccount/i;
    $to   =~ s/last/$topiccount/i;

    if ( $from > $topiccount || $to > $topiccount || $from < 1 || $to < 1 ) {
        &msg( $who, "error: <from> or <to> is out of range." );
        return;
    }

    if ( $from == $to ) {
        &msg( $who, "error: <from> and <to> are the same." );
        return;
    }

    $topic{$chan}{'What'} = "Move $from to $to";

    if ( $action =~ /^(swap)$/i ) {
        my $tmp = $subtopics[ $to - 1 ];
        $subtopics[ $to - 1 ]   = $subtopics[ $from - 1 ];
        $subtopics[ $from - 1 ] = $tmp;

        $_ = "Swapped #\002$from\002 with #\002$to\002.";
        &topicNew( $chan, &topicCipher(@subtopics), $_ );
        return;
    }

    # action != swap:
    # Is there a better way to do this? guess not.
    my $i        = 1;
    my $subtopic = $subtopics[ $from - 1 ];
    foreach (@subtopics) {
        my $j = $i * 2 - 1;
        $newtopics[$j] = $_ if ( $i != $from );
        $i++;
    }

    if ( $action =~ /^(before|b4)$/i ) {
        $newtopics[ $to * 2 - 2 ] = $subtopic;
    }
    else {

        # action =~ /after/.
        $newtopics[ $to * 2 ] = $subtopic;
    }

    undef @subtopics;    # lets reuse this array.
    foreach (@newtopics) {
        next if ( !defined $_ or $_ eq '' );
        push( @subtopics, $_ );
    }

    $_ = "Moved #\002$from\002 $action #\002$to\002.";
    &topicNew( $chan, &topicCipher(@subtopics), $_ );
}

# cmd: shuffle.
sub do_shuffle {
    my ( $chan, $args ) = @_;
    my @subtopics = &topicDecipher($chan);
    my @newtopics;

    $topic{$chan}{'What'} = 'shuffled';

    foreach ( &makeRandom( scalar @subtopics ) ) {
        push( @newtopics, $subtopics[$_] );
    }

    $_ = "Shuffling the bag of lollies.";
    &topicNew( $chan, &topicCipher(@newtopics), $_ );
}

# cmd: history.
sub do_history {
    my ( $chan, $args ) = @_;

    if ( !scalar @{ $topic{$chan}{'History'} } ) {
        &msg( $who, "Sorry, no topics in history list." );
        return;
    }

    &msg( $who, "History of topics on \002$chan\002:" );
    for ( 1 .. scalar @{ $topic{$chan}{'History'} } ) {
        my $topic = ${ $topic{$chan}{'History'} }[ $_ - 1 ];
        &msg( $who, "  #\002$_\002: $topic" );

        # To prevent excess floods.
        sleep 1 if ( length($topic) > 160 );
    }

    &msg( $who, "End of list." );
}

# cmd: restore.
sub do_restore {
    my ( $chan, $args ) = @_;

    if ( $args eq '' ) {
        &help('topic restore');
        return;
    }

    $topic{$chan}{'What'} = "Restore topic $args";

    # following needs to be verified.
    if ( $args =~ /^last$/i ) {
        if ( ${ $topic{$chan}{'History'} }[0] eq $topic{$chan}{'Current'} ) {
            &msg( $who, "error: cannot restore last topic because it's mine." );
            return;
        }
        $args = 1;
    }

    if ( $args !~ /\d+/ ) {
        &msg( $who, "error: argument is not positive integer." );
        return;
    }

    if ( $args > $#{ $topic{$chan}{'History'} } || $args < 1 ) {
        &msg( $who, "error: argument is out of range." );
        return;
    }

    $_ = "Changing topic according to request.";
    &topicNew( $chan, ${ $topic{$chan}{'History'} }[ $args - 1 ], $_ );
}

# cmd: rehash.
sub do_rehash {
    my ($chan) = @_;

    $_ = "Rehashing topic...";
    $topic{$chan}{'What'} = 'Rehash';
    &topicNew( $chan, $topic{$chan}{'Current'}, $_, 1 );
}

# cmd: info.
sub do_info {
    my ($chan) = @_;

    my $reply = "no topic info.";
    if ( exists $topic{$chan}{'Who'} and exists $topic{$chan}{'Time'} ) {
        $reply =
            "topic on \002$chan\002 was last set by "
          . $topic{$chan}{'Who'}
          . ".  This was done "
          . &Time2String( time() - $topic{$chan}{'Time'} ) . ' ago'
          . ".  Length: "
          . length( $topic{$chan}{'Current'} );
        my $change = $topic{$chan}{'What'};
        $reply .= ".  Change => $change" if ( defined $change );
    }

    &performStrictReply($reply);
}

###############################
##### MAIN
###############################

###
# Usage: &Topic($cmd, $args);
sub Topic {
    my ( $chan, $cmd, $args ) = @_;

    if ( $cmd =~ /^-(\S+)/ ) {
        $cache{topicNotUpdate}{$chan} = 1;
        $cmd = $1;
    }

    if ( $cmd =~ /^(add)$/i ) {
        &do_add( $chan, $args );

    }
    elsif ( $cmd =~ /^(del|delete|rm|remove|kill|purge)$/i ) {
        &do_delete( $chan, $args );

    }
    elsif ( $cmd =~ /^list$/i ) {
        &do_list( $chan, $args );

    }
    elsif ( $cmd =~ /^(mod|modify|change|alter)$/i ) {
        &do_modify( $chan, $args );

    }
    elsif ( $cmd =~ /^(mv|move)$/i ) {
        &do_move( $chan, $args );

    }
    elsif ( $cmd =~ /^shuffle$/i ) {
        &do_shuffle( $chan, $args );

    }
    elsif ( $cmd =~ /^(history)$/i ) {
        &do_history( $chan, $args );

    }
    elsif ( $cmd =~ /^restore$/i ) {
        &do_restore( $chan, $args );

    }
    elsif ( $cmd =~ /^(flush|rehash)$/i ) {
        &do_rehash($chan);

    }
    elsif ( $cmd =~ /^info$/i ) {
        &do_info($chan);

    }
    else {
        ### HELP:
        if ( $cmd ne '' and $cmd !~ /^help/i ) {
            &msg( $who, "Invalid command [$cmd]." );
            &msg( $who, "Try 'help topic'." );
            return;
        }

        &help('topic');
    }

    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
