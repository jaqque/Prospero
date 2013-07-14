#
#     RSSTest.pl: RSS Tractker hacked from Plug.pl/Rss.pl
#     Author: Dan McGrath <djmcgrath@users.sourceforge.net>
#  Licensing: Artistic License (as perl itself)
#    Version: v0.1
#

package RSSFeeds;

use strict;
use XML::Feed;

use vars qw(%channels %param $dbh $who $chan);

sub getCacheEntry {
    my ( $file, $url ) = @_;
    my @entries;

    &::DEBUG("rssFeed: Searching cache for $url");

    open CACHE, "<$file" or return;
    binmode( CACHE, ":encoding(UTF-8)" );

    while (<CACHE>) {
        next unless /^$url:/;
        chop;
        s/^$url:(.*)/$1/;
        push @entries, $_;
    }
    close CACHE;

    return @entries;
}

sub saveCache {
    my ( $file, $url, @entries ) = @_;

    open IN,  "<$file"     or return;
    open OUT, ">$file.tmp" or return;

    binmode( IN,  ":encoding(UTF-8)" );
    binmode( OUT, ":encoding(UTF-8)" );

    # copy all but old ones
    while (<IN>) {
        next if /^$url:/;
        print OUT $_;
    }

    # append new ones
    foreach (@entries) {
        print OUT "$url:$_\n";
    }

    close IN;
    close OUT;

    rename "$file.tmp", "$file";
}

sub createCache {
    my $file = shift;

    &::status("rssFeed: Creating cache in $file");

    open CACHE, ">$file" or return;
    close CACHE;
}

sub getFeed {
    my ( $cacheFile, $chan, $rssFeedUrl ) = @_;

    &::DEBUG("rssFeed: URL: $rssFeedUrl");

    my $feed = XML::Feed->parse( URI->new($rssFeedUrl) )
      or return XML::Feed->errstr;

    my $curTitle = $feed->title;
    &::DEBUG("rssFeed: TITLE: $curTitle");
    my @curEntries;

    for my $entry ( $feed->entries ) {
        &::DEBUG( "rssFeed: ENTRY: " . $entry->title );
        push @curEntries, $entry->title;
    }

    # Create the cache if it doesnt exist
    &createCache($cacheFile)
      if ( !-e $cacheFile );

    my @oldEntries = &getCacheEntry( $cacheFile, $rssFeedUrl );
    my @newEntries;
    foreach (@curEntries) {
        &::DEBUG("rssFeed: CACHE: $_");
        last if ( $_ eq $oldEntries[0] );
        push @newEntries, $_;
    }

    if ( scalar @newEntries == 0 ) {    # if there wasn't anything new
        return "rssFeed: No new headlines for $curTitle.";
    }

    # save to hash again
    &saveCache( $cacheFile, $rssFeedUrl, @curEntries )
      or return "rssFeed: Could not save cache!";

    my $reply = &::formListReply( 0, $curTitle, @newEntries );
    &::msg( $chan, $reply );

    #		"\002<<\002$curTitle\002>>\002 " . join( " \002::\002 ", @newEntries ) );

    return;
}

sub RSS {
    my ($command) = @_;
    my $cacheFile = "$::param{tempDir}/rssFeed.cache";
    my %feeds;

    if ( not $command =~ /^(flush|update)?$/i ) {
        &::status("rssFeed: Unknown command: $command");
        return;
    }

    if ( $command =~ /^flush$/i ) {
        if ( not &::IsFlag("o") ) {
            &::status(
                "rssFeed: User $::who tried to flush the cache, but isn't +o!");
            return;
        }
        unlink $cacheFile if ( -e $cacheFile );
        &::status("rssFeed: Flushing cache.");
        &::performStrictReply("$::who: Flushed RSS Feed cache.");
        return;
    }

    if ( $command =~ /^update$/i ) {
        if ( not &::IsFlag("o") ) {
            &::status(
"rssFeed: User $::who tried to manually update feeds, but isn't +o!"
            );
            return;
        }
        &::status("rssFeed: Manual update of feeds requested by $::who.");
    }

    foreach my $chan ( keys %::channels ) {
        my $rssFeedUrl = &::getChanConf( 'rssFeedUrl', $chan );
        my @urls = split / /, $rssFeedUrl;

        # Store by url then chan to allow for same url's in multiple channels
        foreach (@urls) { $feeds{$chan}{$_} = 1 }
    }

    foreach my $chans ( keys %feeds ) {
        foreach ( keys %{ $feeds{$chans} } ) {
            my $result = &getFeed( $cacheFile, $chans, $_ );
            &::status($result) if $result;
        }
    }
    return;
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
