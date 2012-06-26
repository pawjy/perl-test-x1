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
                done $c;
                ok 1;
            } $c;
        },
    );
} n => 1, name => ['ae', 'timer'];

test {
    my $c = shift;
    ok 1;
    done $c;
    is 120, 120;
} n => 2, name => ['sync-only'];

run_tests;

!!1;

use Test::More tests => 7;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.3$/m;

like $output, qr/^ok \d+ - ae\.timer \(\d+\)\.1$/m;
like $err, qr/^# ae.timer \(\d+\)\.1: A subtest occurs after \$c->done is called\.$/m;

like $output, qr/^ok \d+ - sync-only \(\d+\)\.1$/m;
like $err, qr/^# sync-only \(\d+\)\.2: A subtest occurs after \$c->done is called\.$/m;

like $err, qr/^# Looks like you planned 3 tests but ran 5\.$/m;
like $err, qr/^# Looks like you skipped 2 tests\.$/m;
