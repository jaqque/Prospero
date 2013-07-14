#
#     Plug.pl: hacked for http://Plug.org/ by Tim Riker <Tim@Rikers.org>
# Slashdot.pl: Slashdot headline retrival
#      Author: Chris Tessone <tessone@imsa.edu>
#    Modified: dms
#   Licensing: Artistic License (as perl itself)
#     Version: v0.4 (19991125)
#

###
# fixed up to use XML'd /. backdoor 7/31 by richardh@rahga.com
# My only request if this gets included in infobot is that the
# other header gets trimmed to 2 lines, dump the fluff ;) -rah
#
# added a status message so people know to install LWP - oznoid
# also simplified the return code because it wasn't working.
###


package Plug;

use strict;

sub plugParse {
    my @list;

    foreach (@_) {
        next unless (/<title>(.*?)<\/title>/);
        my $title = $1;
        $title =~ s/&amp\;/&/g;
        push( @list, $title );
    }

    return @list;
}

sub Plug {
    my @results = &::getURL("http://www.plug.org/index.xml");
    my $retval  = "i could not get the headlines.";

    if ( scalar @results ) {
        my $prefix = 'Plug Headlines ';
        my @list   = &plugParse(@results);
        $retval = &::formListReply( 0, $prefix, @list );
    }

    &::performStrictReply($retval);
}

sub plugAnnounce {
    my $file = "$::param{tempDir}/plug.xml";

    my @Cxml = &::getURL("http://www.plug.org/index.xml");
    if ( !scalar @Cxml ) {
        &::DEBUG("sdA: failure (Cxml == NULL).");
        return;
    }

    if ( !-e $file ) {    # first time run.
        open( OUT, ">$file" );
        foreach (@Cxml) {
            print OUT "$_\n";
        }
        close OUT;

        return;
    }

    my @Oxml;
    open( IN, $file );
    while (<IN>) {
        chop;
        push( @Oxml, $_ );
    }
    close IN;

    my @Chl = &plugParse(@Cxml);
    my @Ohl = &plugParse(@Oxml);

    my @new;
    foreach (@Chl) {
        last if ( $_ eq $Ohl[0] );
        push( @new, $_ );
    }

    if ( scalar @new == 0 ) {
        &::status("Plug: no new headlines.");
        return;
    }

    if ( scalar @new == scalar @Chl ) {
        &::DEBUG("sdA: scalar(new) == scalar(Chl). bad?");
    }

    open( OUT, ">$file" );
    foreach (@Cxml) {
        print OUT "$_\n";
    }
    close OUT;

    return "Plug: " . join( " \002::\002 ", @new );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
