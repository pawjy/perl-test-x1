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
    my $timer; $timer = AnyEvent->timer(
        after => 0.2,
        cb => sub {
            test {
                undef $timer;
                ok 1;
            } $c;
        },
    );
} n => 1, name => ['ae', 'timer'], timeout => 3.1;

test {
    my $c = shift;
    ok 1;
    is 120, 120;
} n => 2, name => ['sync-only'], timeout => 3.2;

run_tests;

!!1;

use Test::More tests => 10;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.3$/m;

like $output, qr/^ok \d+ - \[\d+\] ae\.timer - \[1\]$/m;
like $output, qr/^not ok \d+ - \[\d+\] ae\.timer - lives_ok$/m;

like $output, qr/^ok \d+ - \[\d+\] sync-only - \[1\]$/m;
like $output, qr/^ok \d+ - \[\d+\] sync-only - \[2\]$/m;
like $output, qr/^not ok \d+ - \[\d+\] sync-only - lives_ok$/m;

like $err, qr/Test: Timeout \(3\.1\)/;
like $err, qr/Test: Timeout \(3\.2\)/;

like $err, qr/^# Looks like you planned 3 tests but ran 5\.$/m;
like $err, qr/^# Looks like you failed 2 tests of 5 run\.$/m;
