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
                ok 1, 'sub1';
                $c->done;
            } $c;
        },
    );
} n => 1, name => ['ae', 'timer'];

test {
    my $c = shift;
    ok 1, 'sub2';
    is 120, 120;
    $c->done;
} n => 2, name => ['sync-only'];

test {
    my $c = shift;
    test {
        ok 1, ['sub2', '', undef, 0];
    } $c, name => ['block', '', undef, 0];
    $c->done;
} n => 1, name => ['name', '', undef, 0];

run_tests;

!!1;

use Test::More tests => 6;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.4$/m;

like $output, qr/^ok \d+ - ae\.timer \(\d+\)\.1\.sub1$/m;

like $output, qr/^ok \d+ - sync-only \(\d+\)\.1\.sub2$/m;
like $output, qr/^ok \d+ - sync-only \(\d+\)\.2$/m;

like $output, qr/^ok \d+ - \Qname.(empty).(undef).0\E \(\d+\)\Q.block.(empty).(undef).0.1.sub2.(empty).(undef).0\E$/m;

unlike $output, qr/^not ok/m;
