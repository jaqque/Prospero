#upsidedown.pl: display a string in pseudo-upsidedown utf-8 characters
#       Author: Tim Riker
#    Licensing: Artistic License
#      Version: v0.1 (20080425)
#
# taken from http://www.xs4all.nl/~johnpc/uniud/uniud-0.14.tar.gz
#
# NOTICE: This source contains UTF-8 unicode characters, but only in the
# comments. You can safely remove them if your editor barfs on them.

use strict;
use utf8;
use PerlIO;
use Getopt::Long qw(:config nopermute bundling auto_help);
use Pod::Usage;
use vars qw($VERSION);

$VERSION = 0.14;

package upsidedown;

#die "huh?" unless ${^UNICODE} == 127; # force -CSDAL

my %updown = (
    ' ' => ' ',
    '!' => "\x{00a1}",          # ¡
    '"' => "\x{201e}",          # „
    '#' => '#',
    '$' => '$',
    '%' => '%',
    '&' => "\x{214b}",          # ⅋
    "'" => "\x{0375}",          # ͵
    '(' => ')',
    ')' => '(',
    '*' => '*',
    '+' => '+',
    ',' => "\x{2018}",          # ‘
    '-' => '-',
    '.' => "\x{02d9}",          # ˙
    '/' => '/',
    '0' => '0',
    '1' => "\x{002c}\x{20d3}",  # ,⃓ can be improved
    '2' => "\x{10f7}",          # ჷ
    '3' => "\x{03b5}",          # ε
    '4' => "\x{21c1}\x{20d3}",  # ⇁⃓ can be improved
    '5' => "\x{1515}",          # ᔕ or maybe just "S"
    '6' => '9',
    '7' => "\x{005f}\x{0338}",  # _̸
    '8' => '8',
    '9' => '6',
    ':' => ':',
    ';' => "\x{22c5}\x{0315}",  # ⋅̕ sloppy, should be improved
    '<' => '>',
    '=' => '=',
    '>' => '<',
    '?' => "\x{00bf}",          # ¿
    '@' => '@',                 # can be improved
    'A' => "\x{13cc}",          # Ꮜ
    'B' => "\x{03f4}",          # ϴ can be improved
    'C' => "\x{0186}",          # Ɔ
    'D' => 'p',                 # should be an uppercase D!!
    'E' => "\x{018e}",          # Ǝ
    'F' => "\x{2132}",          # Ⅎ
    'G' => "\x{2141}",          # ⅁
    'H' => 'H',
    'I' => 'I',
    'J' => "\x{017f}\x{0332}",  # ſ̲
    'K' => "\x{029e}",          # ʞ should be an uppercase K!!
    'L' => "\x{2142}",          # ⅂
    'M' => "\x{019c}",          # Ɯ or maybe just "W"
    'N' => 'N',
    'O' => 'O',
    'P' => 'd',                 # should be uppercase P
    'Q' => "\x{053e}",          # Ծ can be improved
    'R' => "\x{0222}",          # Ȣ can be improved
    'S' => 'S',
    'T' => "\x{22a5}",          # ⊥
    'U' => "\x{144e}",          # ᑎ
    'V' => "\x{039b}",          # Λ
    'W' => 'M',
    'X' => 'X',
    'Y' => "\x{2144}",          # ⅄
    'Z' => 'Z',
    '[' => ']',
    '\\' => '\\',
    ']' => '[',
    '^' => "\x{203f}",          # ‿
    '_' => "\x{203e}",          # ‾
    '`' => "\x{0020}\x{0316}",  #  ̖
    'a' => "\x{0250}",          # ɐ
    'b' => 'q',
    'c' => "\x{0254}",          # ɔ
    'd' => 'p',
    'e' => "\x{01dd}",          # ǝ
    'f' => "\x{025f}",          # ɟ
    'g' => "\x{0253}",          # ɓ
    'h' => "\x{0265}",          # ɥ
    'i' => "\x{0131}\x{0323}",  # ı̣
    'j' => "\x{017f}\x{0323}",  # ſ̣
    'k' => "\x{029e}",          # ʞ
    'l' => "\x{01ae}",          # Ʈ can be improved
    'm' => "\x{026f}",          # ɯ
    'n' => 'u',
    'o' => 'o',
    'p' => 'd',
    'q' => 'b',
    'r' => "\x{0279}",          # ɹ
    's' => 's',
    't' => "\x{0287}",          # ʇ
    'u' => 'n',
    'v' => "\x{028c}",          # ʌ
    'w' => "\x{028d}",          # ʍ
    'x' => 'x',
    'y' => "\x{028e}",          # ʎ
    'z' => 'z',
    '{' => '}',
    '|' => '|',
    '}' => '{',
    '~' => "\x{223c}",          # ∼
);
my $missing = "\x{fffd}";       # � replacement character

# turnedstr - handle turning one string
sub turnedstr {
    my $str = shift;
    my $turned = '';
    my $tlength = 0;

    # add reverse mappings
    foreach my $up (keys %updown) {
        $updown{$updown{$up}} = $up if ! exists $updown{$updown{$up}};
    }

    for my $char ( $str =~ /(\X)/g ) {
#print STDERR "str=\"$str\" char=\"$char\"\n";
        if ( exists $updown{$char} ) {
            my $t = $updown{$char};
            $t = $missing if !length($t);
            $turned = $t . $turned;
            $tlength++;
        }
        elsif ( $char eq "\t" ) {
            my $tablen = 8 - $tlength % 8;
            $turned = " " x $tablen . $turned;
            $tlength += $tablen;
        }
        elsif ( ord($char) >= 32 ) {
            ### other chars copied literally
            $turned = $char . $turned;
            $tlength++;
        }
    }

    return $turned;
}

sub upsidedown {
    my ($message) = @_;
    &::performStrictReply( turnedstr( $message ) );
}

#binmode(STDERR, "encoding(UTF-8)");
#print STDERR turnedstr("upsidedown ɟǝpɔqɐabcdef") . "\n";
1;

# vim:ts=4:sw=4:expandtab:tw=80
