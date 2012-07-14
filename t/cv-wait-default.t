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
use AnyEvent;

my $cv = AE::cv;

no warnings 'redefine';
local *Test::X1::Manager::default_test_wait_cv = sub { $cv };

test {
    my $c = shift;
    is $c->received_data, 12345;
    done $c;
} n => 1;

test {
    my $c = shift;
    is $c->received_data, 12345;
    is $c->received_data, 12345;
    done $c;
} n => 2;

test {
    my $c = shift;
    is $c->received_data, undef;
    done $c;
} n => 1, name => 'not waiting', wait => undef;

my $w = AE::timer 0.1, 0, sub {
    note "before cv->send";
    $cv->send(12345);
    note "after cv->send";
};

run_tests;

!!1;

use Test::More tests => 1;

my ($output, $err) = PackedTest->run;

is $output, q{1..4
ok 1 - [3] not waiting - [1]
# before cv->send
ok 2 - [2] - [1]
ok 3 - [2] - [2]
ok 4 - [1] - [1]
# after cv->send
};
