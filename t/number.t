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
                ok 1;
                ok 2;
                ok 3;
                undef $timer;
                $c->done;
            } $c;
        },
    );
} n => 1, name => ['ae', 'timer'];

test {
    my $c = shift;
    ok 1;
    ok 2;
    ok 3;
    $c->done;
} n => 2, name => ['sync-only'];

run_tests;

!!1;

use Test::More tests => 3;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.3$/m;
like $err, qr/^# \[\d+\] ae\.timer: Looks like you planned 1 test but ran 3\.$/m;
like $err, qr/^# \[\d+\] sync-only: Looks like you planned 2 tests but ran 3.$/m;
