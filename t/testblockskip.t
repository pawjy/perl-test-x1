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
    test {
        is 120, 120;
    } $c, name => 'foo';
    test {
        is 120, 120;
    } $c, name => 'bar';
    $c->done;
} n => 2, name => ['hoge'];

run_tests;

!!1;

use Test::More tests => 3;

local $ENV{TEST_BLOCK_SKIP} = 'foo';
my ($output, $err) = PackedTest->run;

is $output, q{1..2
ok 1 # skip
ok 2 - [1] hoge - [1] bar
not ok 3 - No skipped tests
};

like $err, qr/^# \[1\] hoge - foo - subtests skipped\.$/m;
like $err, qr/^# \[1\] hoge: Looks like you planned 2 tests but ran 1\.$/m;
