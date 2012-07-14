use strict;
BEGIN {
    my $dir_name = __FILE__; $dir_name =~ s{[^/\\]+$}{}; $dir_name ||= '.';
    unshift @INC, $dir_name . '/lib/', $dir_name . '/../lib/';
}
use warnings;
use PackedTest;

!!1;

use Test::More;
use My::Test::X1;

my $tm = get_test_manager;
my $cv = $tm->my_cv;

test {
    my $c = shift;
    my $timer; $timer = AnyEvent->timer(
        after => 0.2,
        cb => sub {
            test {
                undef $timer;
                ok $c->my_value > 1;
                $c->done;
            } $c;
        },
    );
} n => 1, wait => $cv;

test {
    my $c = shift;
    ok 1;
    ok $c->my_value > 1;
    $c->done;
} n => 2, wait => $cv;

test {
    my $c = shift;
    ok 1;
    $c->done;
} n => 1, name => 'no wait';

test {
    my $c = shift;
    isa_ok $tm->my_cv, 'AnyEvent::CondVar';
    done $c;
} n => 1, name => 'test manager extension';

test {
    my $c = shift;
    ok $c->my_value;
    done $c;
} n => 1, name => 'test context extension';

run_tests;

!!1;

use Test::More tests => 3;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.6$/m;
like $output, qr/^ok 1 - no wait \(3\)\.1$/m;
unlike $output, qr/^not ok/m;
