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

my $destroy_cv1 = AE::cv;
my $destroy_cv2 = AE::cv;

test {
    my $c = shift;
    ok 1;
    done $c;
} n => 1, wait => {cv => undef, destroy_as_cv => sub {
    note "destroy_as_cv";
    my $t; $t = AE::timer 0.1, 0, sub {
        note "destroy_cv->send 1";
        $destroy_cv1->send;
        undef $t;
    };
    $destroy_cv1;
}};

my $destroy = sub {
    note "destroy_as_cv";
    my $t; $t = AE::timer 0.3, 0, sub {
        note "destroy_cv->send 2";
        $destroy_cv2->send;
        undef $t;
    };
    return $destroy_cv2;
};

test {
    my $c = shift;
    ok 1;
    done $c;
} n => 1, wait => {cv => undef, destroy_as_cv => $destroy};

test {
    my $c = shift;
    ok 1;
    done $c;
} n => 1, wait => {cv => undef, destroy_as_cv => $destroy};

run_tests;

!!1;

use Test::More tests => 1;

my ($output, $err) = PackedTest->run;

is $output, q{1..3
ok 1 - [1] - [1]
ok 2 - [2] - [1]
ok 3 - [3] - [1]
# destroy_as_cv
# destroy_as_cv
# destroy_cv->send 1
# destroy_cv->send 2
};
