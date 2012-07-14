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
} n => 1, name => ['ae', 'timer'];

test {
    my $c = shift;
    ok 1;
    is 120, 120;
} n => 2, name => ['sync-only'];

run_tests;

!!1;

use Test::More tests => 8;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.3$/m;

like $output, qr/^ok \d+ - \[\d+\] ae\.timer - \[1\]$/m;
like $output, qr/^not ok \d+ - \[\d+\] ae\.timer \$c->done$/m;

like $output, qr/^ok \d+ - \[\d+\] sync-only - \[1\]$/m;
like $output, qr/^ok \d+ - \[\d+\] sync-only - \[2\]$/m;
like $output, qr/^not ok \d+ - \[\d+\] sync-only \$c->done$/m;

like $err, qr/^# Looks like you planned 3 tests but ran 5\.$/m;
like $err, qr/^# Looks like you failed 2 tests of 5 run\.$/m;
