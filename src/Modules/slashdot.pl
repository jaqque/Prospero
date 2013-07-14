#
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

package Slashdot;

use strict;

sub slashdotParse {
    my @list;

    foreach (@_) {
        next unless (/<title>(.*?)<\/title>/);
        my $title = $1;
        $title =~ s/&amp\;/&/g;
        push( @list, $title );
    }

    return @list;
}

sub Slashdot {
    my @results = &::getURL("http://slashdot.org/slashdot.xml");
    my $retval  = "i could not get the headlines.";

    if ( scalar @results ) {
        my $prefix = 'Slashdot Headlines ';
        my @list   = &slashdotParse(@results);
        $retval = &::formListReply( 0, $prefix, @list );
    }

    &::performStrictReply($retval);
}

sub slashdotAnnounce {
    my $file = "$::param{tempDir}/slashdot.xml";

    my @Cxml = &::getURL("http://slashdot.org/slashdot.xml");
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

    my @Chl = &slashdotParse(@Cxml);
    my @Ohl = &slashdotParse(@Oxml);

    my @new;
    foreach (@Chl) {
        last if ( $_ eq $Ohl[0] );
        push( @new, $_ );
    }

    if ( scalar @new == 0 ) {
        &::status("Slashdot: no new headlines.");
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

    return "Slashdot: News for nerds, stuff that matters -- "
      . join( " \002::\002 ", @new );
}

1;

# vim:ts=4:sw=4:expandtab:tw=80
