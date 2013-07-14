# This program is distributed under the same terms as infobot.

package wikipedia;

use strict;

my $missing;
my $wikipedia_base_url   = 'http://www.wikipedia.org/wiki/';
my $wikipedia_search_url = $wikipedia_base_url . 'Special:Search?';
my $wikipedia_export_url = $wikipedia_base_url . 'Special:Export/';

BEGIN {

    # utility functions for encoding the wikipedia request
    eval "use URI::Escape";
    if ($@) {
        $missing++;
    }

    eval "use LWP::UserAgent";
    if ($@) {
        $missing++;
    }

    eval "use HTML::Entities";
    if ($@) {
        $missing++;
    }
}

sub wikipedia {
    return '' if $missing;
    my ($phrase) = @_;
    my ( $reply, $valid_result ) = wikipedia_lookup(@_);
    if ($reply) {
        &::performStrictReply($reply);
    }
    else {
        &::performStrictReply(
"'$phrase' not found in Wikipedia. Perhaps try a different spelling or case?"
        );
    }
}

sub wikipedia_silent {
    return '' if $missing;
    my ( $reply, $valid_result ) = wikipedia_lookup(@_);
    if ( $valid_result and $reply ) {
        &::performStrictReply($reply);
    }
}

sub wikipedia_lookup {
    my ($phrase) = @_;
    &::DEBUG("wikipedia($phrase)");

    my $ua = new LWP::UserAgent;
    $ua->proxy( 'http', $::param{'httpProxy'} ) if ( &::IsParam('httpProxy') );

    # Let's pretend
    $ua->agent( "Mozilla/5.0 " . $ua->agent );
    $ua->timeout(5);

    # chop ? from the end
    $phrase =~ s/\?$//;

    # convert phrase to wikipedia conventions
    #  $phrase = uri_escape($phrase);
    #  $phrase =~ s/%20/+/g;
    #  $phrase =~ s/%25/%/g;
    $phrase =~ s/ /+/g;

    # using the search form will make the request case-insensitive
    # HEAD will follow redirects, catching the first mode of redirects
    # that wikipedia uses
    my $url = $wikipedia_search_url . 'search=' . $phrase . '&go=Go';
    my $req = HTTP::Request->new( 'HEAD', $url );
    $req->header( 'Accept-Language' => 'en' );
    &::DEBUG($url);

    my $res = $ua->request($req);
    &::DEBUG( $res->code );

    if ( !$res->is_success ) {
        return (
            "Wikipedia might be temporarily unavailable ("
              . $res->code
              . "). Please try again in a few minutes...",
            0
        );
    }
    else {

        # we have been redirected somewhere
        # (either content or the generic Search form)
        # let's find the title of the article
        $url    = $res->request->uri;
        $phrase = $url;
        $phrase =~ s/.*\/wiki\///;

        if ( !$res->code == '200' ) {
            return (
"Wikipedia might be temporarily unavailable or something is broken ("
                  . $res->code
                  . "). Please try again later...",
                0
            );
        }
        else {
            if ( $url =~ m/Special:Search/ ) {

                # we were sent to the the search page
                return (
"I couldn't find a matching article in wikipedia, look for yerselves: "
                      . $url,
                    0
                );
            }
            else {

                # we hit content, let's retrieve it
                my $text = wikipedia_get_text($phrase);

                # filtering unprintables
                $text =~ s/[[:cntrl:]]//g;

                # filtering headings
                $text =~ s/==+[^=]*=+//g;

                # filtering wikipedia tables
                $text =~ s/\{\|[^}]+\|\}//g;

                # some people cannot live without HTML tags, even in a wiki
                # $text =~ s/&lt;div.*&gt;//gi;
                # $text =~ s/&lt;!--.*&gt;//gi;
                # $text =~ s/<[^>]*>//g;
                # or HTML entities
                $text =~ s/&amp;/&/g;
                decode_entities($text);

                # or tags, again
                $text =~ s/<[^>]*>//g;

                #$text =~ s/[&#]+[0-9a-z]+;//gi;
                # filter wikipedia tags: [[abc: def]]
                $text =~ s/\[\[[[:alpha:]]*:[^]]*\]\]//gi;

                # {{abc}}:tag
                $text =~ s/\{\{[[:alpha:]]+\}\}:[^\s]+//gi;

                # {{abc}}
                $text =~ s/\{\{[[:alpha:]]+\}\}//gi;

                # unescape quotes
                $text =~ s/'''/'/g;
                $text =~ s/''/"/g;

                # filter wikipedia links: [[tag|link]] -> link
                $text =~ s/\[\[[^]]+\|([^]]+)\]\]/$1/g;

                # [[link]] -> link
                $text =~ s/\[\[([^]]+)\]\]/$1/g;

                # shrink whitespace
                $text =~ s/[[:space:]]+/ /g;

                # chop leading whitespace
                $text =~ s/^ //g;

                # shorten article to first one or two sentences
                # new: we rely on the output function to know what to do
                #      with long messages
                #$text = substr($text, 0, 330);
                #$text =~ s/(.+)\.([^.]*)$/$1./g;

                return ( 'At ' . $url . " (URL), Wikipedia explains: " . $text,
                    1 );
            }
        }
    }
}

sub wikipedia_get_text {
    return '' if $missing;
    my ($article) = @_;
    &::DEBUG("wikipedia_get_text($article)");

    my $ua = new LWP::UserAgent;
    $ua->proxy( 'http', $::param{'httpProxy'} ) if ( &::IsParam('httpProxy') );

    # Let's pretend
    $ua->agent( "Mozilla/5.0 " . $ua->agent );
    $ua->timeout(5);

    &::DEBUG( $wikipedia_export_url . $article );
    my $req = HTTP::Request->new( 'GET', $wikipedia_export_url . $article );
    $req->header( 'Accept-Language' => 'en' );
    $req->header( 'Accept-Charset'  => 'utf-8' );

    my $res = $ua->request($req);
    my ( $title, $redirect, $text );
    &::DEBUG( $res->code );

    if ( $res->is_success ) {
        if ( $res->code == '200' ) {
            foreach ( split( /\n/, $res->as_string ) ) {
                if (/<title>(.*?)<\/title>/) {
                    $title = $1;
                    $title =~ s/&amp\;/&/g;
                }
                elsif (/#REDIRECT\s*\[\[(.*?)\]\]/i) {
                    $redirect = $1;
                    $redirect =~ tr/ /_/;
                    &::DEBUG( 'wiki redirect to ' . $redirect );
                    last;
                }
                elsif (/<text[^>]*>(.*)/) {
                    $text = '"' . $1;
                }
                elsif (/(.*)<\/text>/) {
                    $text = $text . ' ' . $1 . '"';
                    last;
                }
                elsif ($text) {
                    $text = $text . ' ' . $_;
                }
            }
            &::DEBUG( "wikipedia returned text: " . $text
                  . ', redirect '
                  . $redirect
                  . "\n" );

            if ( !$redirect and !$text ) {
                return ( $res->as_string );
            }
            return ( $text or wikipedia_get_text($redirect) );
        }
    }

}

1;

# vim:ts=4:sw=4:expandtab:tw=80
