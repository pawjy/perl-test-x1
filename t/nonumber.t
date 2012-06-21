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
};

test {
    my $c = shift;
    ok 1;
    ok 2;
    ok 3;
    $c->done;
};

run_tests;

!!1;

use Test::More tests => 3;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.6$/m;
unlike $output, qr/^not ok/m;
unlike $err, qr/^# Looks/m;
