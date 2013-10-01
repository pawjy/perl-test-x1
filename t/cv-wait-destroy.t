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
my $destroy_cv = AE::cv;

test {
    my $c = shift;
    is $c->received_data, 12345;
    done $c;
} n => 1, wait => {cv => $cv, destroy_as_cv => sub {
    note "destroy_as_cv";
    my $t; $t = AE::timer 0, 0.3, sub {
        note "destroy_cv->send";
        $destroy_cv->send;
        undef $t;
    };
    $destroy_cv;
}};

test {
    my $c = shift;
    is $c->received_data, 12345;
    is $c->received_data, 12345;
    done $c;
} n => 2, wait => $cv;

test {
    my $c = shift;
    is $c->received_data, undef;
    done $c;
} n => 1, name => 'not waiting';

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
# destroy_as_cv
# destroy_cv->send
};
