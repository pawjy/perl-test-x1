use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/\\]+$}{}; $dir_name ||= '.';
    unshift @INC, $dir_name . '/lib/', $dir_name . '/../lib/';
}
use warnings;
use PackedTest;

!!1;

use Test::X1;
use Test::More;

test {
    my $c = shift;
    ok 1, "\x{4E02}\x{4E03}";
    test {
        is 120, 120, "\x{4E06}";
    } $c, name => "\x{4E04}\x{4E05}";
    $c->done;
} n => 2, name => ["\x{4E00}\x{4E01}"];

test {
    my $c = shift;
    ok 1, "\xF0";
    done $c;
} n => 1, name => "\xC1\xC4\x81";

run_tests;

!!1;

use Encode;
use Test::More tests => 6;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.3$/m;

like $output, qr{$_}m for encode 'utf-8',
    qq/^ok \\d+ - \\[1\\] \x{4E00}\x{4E01} - \\[1\\] \x{4E02}\x{4E03}\$/;
like $output, qr{$_}m for encode 'utf-8',
    qq/^ok \\d+ - \\[1\\] \x{4E00}\x{4E01} - \\[2\\] \x{4E04}\x{4E05} \x{4E06}\$/;
like $output, qr{$_}m for encode 'utf-8',
    qq/^ok \\d+ - \\[2\\] \xC1\xC4\x81 - \\[1\\] \xF0\$/;

unlike $output, qr/^not ok/m;

unlike $err, qr{Wide character in print};
