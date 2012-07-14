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
    ok 1;
    is 120, 120;
    $c->done;
} n => 2, name => ['hoge'];

test {
    my $c = shift;
    ok 21;
    is 120, 120;
    $c->done;
} n => 2, name => ['fuga'];

run_tests;

!!1;

use Test::More tests => 6;

local $ENV{TEST_METHOD} = '2';
my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.2$/m;

unlike $output, qr/^ok \d+ - \[1\] hoge - \[1\]$/m;
unlike $output, qr/^ok \d+ - \[1\] hoge - \[2\]$/m;

like $output, qr/^ok \d+ - \[2\] fuga - \[1\]$/m;
like $output, qr/^ok \d+ - \[2\] fuga - \[2\]$/m;

unlike $output, qr/^not ok/m;
