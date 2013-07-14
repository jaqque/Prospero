#!/usr/bin/perl
#
# BZFlag
# Copyright (c) 1993 - 2002 Tim Riker
#
# This package is free software;  you can redistribute it and/or
# modify it under the terms of the license found in the file
# named LICENSE that should have accompanied this file.
#
# THIS PACKAGE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

package BZFlag;
use strict;
use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);

my $no_BZFlag;

BEGIN {
    $no_BZFlag = 0;
    eval "use Socket";
    eval "use LWP::UserAgent";
    $no_BZFlag++ if ($@);
}

sub BZFlag {
    my ($message) = @_;
    my ($retval);
    if ($no_BZFlag) {
        &::status("BZFlag module requires Socket.");
        return 'BZFlag module not active';
    }
    if ( $message =~ /^bzfquery\s+([^:]*)(?::([0-9]*))?$/xi ) {
        $retval = &query( $1, $2 );
    }
    elsif ( $message =~ /^bzflist$/xi ) {
        $retval = &list();
    }
    else {
        $retval = "BZFlag: unhandled command \"$message\"";
    }
    &::performStrictReply($retval);
}

sub list {
    my ($response);
    my $ua = new LWP::UserAgent;
    $ua->proxy( 'http', $::param{'httpProxy'} ) if ( &::IsParam('httpProxy') );

    $ua->timeout(5);

    my $req =
      HTTP::Request->new( 'GET', 'http://db.bzflag.org/db/?action=LIST' );
    my $res = $ua->request($req);
    my %servers;
    my $totalServers = 0;
    for my $line ( split( "\n", $res->content ) ) {
        my ( $serverport, $version, $flags, $ip, $comments ) =
          split( " ", $line, 5 );

        # not "(A4)18" to handle old dumb perl
        my (
            $style,          $maxShots,     $shakeWins,    $shakeTimeout,
            $maxPlayerScore, $maxTeamScore, $maxTime,      $maxPlayers,
            $rogueSize,      $rogueMax,     $redSize,      $redMax,
            $greenSize,      $greenMax,     $blueSize,     $blueMax,
            $purpleSize,     $purpleMax,    $observerSize, $observerMax
        ) = unpack( 'A4A4A4A4A4A4A4A2A2A2A2A2A2A2A2A2A2A2A2A2', $flags );
        my $playerSize =
          hex($rogueSize) + hex($redSize) + hex($greenSize) + hex($blueSize) +
          hex($purpleSize) + hex($observerSize);
        $servers{$serverport} = $playerSize;
        $servers{$version}  += $playerSize;
        $servers{'PLAYERS'} += $playerSize;
        $totalServers       += 1;
    }
    $response .= "s=$totalServers";
    foreach
      my $key ( sort { $servers{$b} <=> $servers{$a} } ( keys(%servers) ) )
    {
        if ( $servers{$key} > 0 ) {
            $response .= " $key($servers{$key})";
        }
    }
    &::performStrictReply($response);
    return;
}

sub list17 {
    my ($response);
    my $ua = new LWP::UserAgent;
    $ua->proxy( 'http', $::param{'httpProxy'} ) if ( &::IsParam('httpProxy') );

    $ua->timeout(5);

    my $req = HTTP::Request->new( 'GET', 'http://list.bzflag.org:5156/' );
    my $res = $ua->request($req);
    my %servers;
    my $totalServers = 0;
    my $totalPlayers = 0;
    for my $line ( split( "\n", $res->content ) ) {
        my ( $serverport, $version, $flags, $ip, $comments ) =
          split( " ", $line, 5 );

        # not "(A4)18" to handle old dumb perl
        my (
            $style,        $maxPlayers, $maxShots,     $rogueSize,
            $redSize,      $greenSize,  $blueSize,     $purpleSize,
            $rogueMax,     $redMax,     $greenMax,     $blueMax,
            $purpleMax,    $shakeWins,  $shakeTimeout, $maxPlayerScore,
            $maxTeamScore, $maxTime
        ) = unpack( 'A4A4A4A4A4A4A4A4A4A4A4A4A4A4A4A4A4A4', $flags );
        my $playerSize =
          hex($rogueSize) + hex($redSize) + hex($greenSize) + hex($blueSize) +
          hex($purpleSize);
        $servers{$serverport} = $playerSize;
        $totalServers += 1;
        $totalPlayers += $playerSize;
    }
    $response .= "s=$totalServers p=$totalPlayers";
    foreach
      my $key ( sort { $servers{$b} <=> $servers{$a} } ( keys(%servers) ) )
    {
        if ( $servers{$key} > 0 ) {
            $response .= " $key($servers{$key})";
        }
    }
    &::performStrictReply($response);
    return;
}

sub querytext {
    my ($servernameport) = @_;
    my ( $servername, $port ) = split( ":", $servernameport );
    if ($no_BZFlag) {
        &::status("BZFlag module requires Socket.");
        return 'BZFlag module not active';
    }

#my @teamName = ('Rogue', 'Red', 'Green', 'Blue', 'Purple', 'Observer', 'Rabbit');
    my @teamName = ( 'X', 'R', 'G', 'B', 'P', 'O', 'K' );
    my ( $message, $server, $response );
    $port = 5154 unless $port;

    # socket define
    my $sockaddr = 'S n a4 x8';

    # port to port number
    my ( $name, $aliases, $proto ) = getprotobyname('tcp');
    ( $name, $aliases, $port ) = getservbyname( $port, 'tcp' )
      unless $port =~ /^\d+$/;

    # get server address
    my ( $type, $len, $serveraddr );
    ( $name, $aliases, $type, $len, $serveraddr ) = gethostbyname($servername);
    $server = pack( $sockaddr, AF_INET, $port, $serveraddr );

    # connect
    # TODO wrap this with a 5 second alarm()
    return 'socket() error' unless socket( S1, AF_INET, SOCK_STREAM, $proto );
    return "could not connect to $servername:$port"
      unless connect( S1, $server );

    # don't buffer
    select(S1);
    $| = 1;
    select(STDOUT);

    # get hello
    my $buffer;
    return 'read error' unless read( S1, $buffer, 8 ) == 8;

    # parse reply
    my ( $magic, $major, $minor, $something, $revision ) =
      unpack( "a4 a1 a1 a1 a1", $buffer );
    my ($version) = $magic . $major . $minor . $something . $revision;

    # quit if version isn't valid
    return 'not a bzflag server' if ( $magic ne 'BZFS' );
    $response .= "$major$minor$something$revision ";

    # check version
    if ( $version eq 'BZFS0026' ) {

        # 1.11.x handled here
        return 'read error' unless read( S1, $buffer, 1 ) == 1;
        my ($id) = unpack( 'C', $buffer );
        return "rejected by server" if ( $id == 255 );

        # send game request
        print S1 pack( 'n2', 0, 0x7167 );

        # get reply
        my $nbytes = read( S1, $buffer, 4 );
        my ( $infolen, $infocode ) = unpack( 'n2', $buffer );
        if ( $infocode == 0x6774 ) {

            # read and ignore MsgGameTime from new servers
            $nbytes = read( S1, $buffer, 8 );
            $nbytes = read( S1, $buffer, 4 );
            ( $infolen, $infocode ) = unpack( 'n2', $buffer );
        }
        $nbytes = read( S1, $buffer, 42 );
        if ( $nbytes != 42 ) {
            return "Error: read $nbytes bytes, expecting 46: $^E\n";
        }

        my (
            $style,        $maxPlayers,     $maxShots,     $rogueSize,
            $redSize,      $greenSize,      $blueSize,     $purpleSize,
            $observerSize, $rogueMax,       $redMax,       $greenMax,
            $blueMax,      $purpleMax,      $observerMax,  $shakeWins,
            $shakeTimeout, $maxPlayerScore, $maxTeamScore, $maxTime,
            $timeElapsed
        ) = unpack( 'n23', $buffer );
        return "bad server data $infocode" unless $infocode == 0x7167;

        # send players request
        print S1 pack( 'n2', 0, 0x7170 );

        # get number of teams and players we'll be receiving
        return 'count read error' unless read( S1, $buffer, 8 ) == 8;
        my ( $countlen, $countcode, $numTeams, $numPlayers ) =
          unpack( 'n4', $buffer );

        # get the teams
        return 'bad count data' unless $countcode == 0x7170;
        return 'count read error' unless read( S1, $buffer, 5 ) == 5;
        ( $countlen, $countcode, $numTeams ) = unpack( "n n C", $buffer );
        for ( 1 .. $numTeams ) {
            return 'team read error' unless read( S1, $buffer, 8 ) == 8;
            my ( $team, $size, $won, $lost ) = unpack( 'n4', $buffer );
            if ( $size > 0 ) {
                my $score = $won - $lost;
                $response .= "$teamName[$team]:$score($won-$lost) ";
            }
        }

        # get the players
        for ( 1 .. $numPlayers ) {
            last unless read( S1, $buffer, 175 ) == 175;
            my (
                $playerlen, $playercode, $pID, $type, $team,
                $won,       $lost,       $tks, $sign, $email
            ) = unpack( 'n2Cn5A32A128', $buffer );

#my ($playerlen,$playercode,$pAddr,$pPort,$pNum,$type,$team,$won,$lost,$sign,$email) =
#		unpack("n2Nn2 n4A32A128", $buffer);
            return 'bad player data' unless $playercode == 0x6170;
            my $score = $won - $lost;
            $response .= " $sign($teamName[$team]";
            $response .= ":$email" if ($email);
            $response .= ")$score($won-$lost)";
        }
        $response .= "No Players" if ( $numPlayers < 1 );

        # close socket
    }
    elsif ( $major == 1 && $minor == 9 ) {

        # 1.10.x handled here
        $revision = $something * 10 + $revision;
        return 'read error' unless read( S1, $buffer, 1 ) == 1;
        my ($id) = unpack( 'C', $buffer );

        # send game request
        print S1 pack( 'n2', 0, 0x7167 );

        # FIXME the packets are wrong from here down
        # get reply
        return 'server read error' unless read( S1, $buffer, 40 ) == 40;
        my (
            $infolen,      $infocode,       $style,        $maxPlayers,
            $maxShots,     $rogueSize,      $redSize,      $greenSize,
            $blueSize,     $purpleSize,     $rogueMax,     $redMax,
            $greenMax,     $blueMax,        $purpleMax,    $shakeWins,
            $shakeTimeout, $maxPlayerScore, $maxTeamScore, $maxTime
        ) = unpack( 'n20', $buffer );
        return 'bad server data' unless $infocode == 0x7167;

        # send players request
        print S1 pack( 'n2', 0, 0x7170 );

        # get number of teams and players we'll be receiving
        return 'count read error' unless read( S1, $buffer, 8 ) == 8;
        my ( $countlen, $countcode, $numTeams, $numPlayers ) =
          unpack( 'n4', $buffer );

        # get the teams
        return 'bad count data' unless $countcode == 0x7170;
        return 'count read error' unless read( S1, $buffer, 5 ) == 5;
        ( $countlen, $countcode, $numTeams ) = unpack( "n n C", $buffer );
        for ( 1 .. $numTeams ) {
            return 'team read error' unless read( S1, $buffer, 8 ) == 8;
            my ( $team, $size, $won, $lost ) = unpack( 'n4', $buffer );
            if ( $size > 0 ) {
                my $score = $won - $lost;
                $response .= "$teamName[$team]:$score($won-$lost) ";
            }
        }

        # get the players
        for ( 1 .. $numPlayers ) {
            last unless read( S1, $buffer, 175 ) == 175;
            my (
                $playerlen, $playercode, $pID, $type, $team,
                $won,       $lost,       $tks, $sign, $email
            ) = unpack( 'n2Cn5A32A128', $buffer );

#my ($playerlen,$playercode,$pAddr,$pPort,$pNum,$type,$team,$won,$lost,$sign,$email) =
#		unpack("n2Nn2 n4A32A128", $buffer);
            return 'bad player data' unless $playercode == 0x6170;
            my $score = $won - $lost;
            $response .= " $sign($teamName[$team]";
            $response .= ":$email" if ($email);
            $response .= ")$score($won-$lost)";
        }
        $response .= "No Players" if ( $numPlayers < 1 );

        # close socket
        close(S1);
    }
    elsif ( $major == 1 && $minor == 0 && $something == 7 ) {

        # 1.7* versions handled here
        # old servers send a reconnect port number
        return 'read error' unless read( S1, $buffer, 2 ) == 2;
        my ($reconnect) = unpack( 'n', $buffer );
        $minor = $minor * 10 + $something;

        # quit if rejected
        return 'rejected by server' if ( $reconnect == 0 );

        # reconnect on new port
        $server = pack( $sockaddr, AF_INET, $reconnect, $serveraddr );
        return 'socket() error on reconnect'
          unless socket( S, AF_INET, SOCK_STREAM, $proto );
        return "could not reconnect to $servername:$reconnect"
          unless connect( S, $server );
        select(S);
        $| = 1;
        select(STDOUT);

        # close first socket
        close(S1);

        # send game request
        print S pack( 'n2', 0, 0x7167 );

        # get reply
        return 'server read error' unless read( S, $buffer, 40 ) == 40;
        my (
            $infolen,      $infocode,       $style,        $maxPlayers,
            $maxShots,     $rogueSize,      $redSize,      $greenSize,
            $blueSize,     $purpleSize,     $rogueMax,     $redMax,
            $greenMax,     $blueMax,        $purpleMax,    $shakeWins,
            $shakeTimeout, $maxPlayerScore, $maxTeamScore, $maxTime
        ) = unpack( 'n20', $buffer );
        return 'bad server data' unless $infocode == 0x7167;

        # send players request
        print S pack( 'n2', 0, 0x7170 );

        # get number of teams and players we'll be receiving
        return 'count read error' unless read( S, $buffer, 8 ) == 8;
        my ( $countlen, $countcode, $numTeams, $numPlayers ) =
          unpack( 'n4', $buffer );
        return 'bad count data' unless $countcode == 0x7170;

        # get the teams
        for ( 1 .. $numTeams ) {
            return 'team read error' unless read( S, $buffer, 14 ) == 14;
            my ( $teamlen, $teamcode, $team, $size, $aSize, $won, $lost ) =
              unpack( 'n7', $buffer );
            return 'bad team data' unless $teamcode == 0x7475;
            if ( $size > 0 ) {
                my $score = $won - $lost;
                $response .= "$teamName[$team]:$score($won-$lost) ";
            }
        }

        # get the players
        for ( 1 .. $numPlayers ) {
            last unless read( S, $buffer, 180 ) == 180;
            my (
                $playerlen, $playercode, $pAddr, $pPort,
                $pNum,      $type,       $team,  $won,
                $lost,      $sign,       $email
            ) = unpack( "n2Nn2 n4A32A128", $buffer );
            return 'bad player data' unless $playercode == 0x6170;
            my $score = $won - $lost;
            $response .= " $sign($teamName[$team]";
            $response .= ":$email" if ($email);
            $response .= ")$score($won-$lost)";
        }
        $response .= "No Players" if ( $numPlayers <= 1 );

        # close socket
        close(S);
    }
    else {
        $response = "incompatible version: $version";
    }

    return $response;
}

sub query {
    my ($servernameport) = @_;
    &::performStrictReply( &querytext($servernameport) );
    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
