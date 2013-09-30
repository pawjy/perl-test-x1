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

my @cv;
push @cv, AE::cv for 0..6;

for my $i (0..6) {
    test {
        my $c = shift;
        warn "cv[$i] test sync section\n";
        $cv[$i]->cb(sub {
            warn "cv[$i] test async section\n";
            test {
                ok 1;
            } $c;
            $c->done;
        });
    } n => 1;
}

my $timer = AE::timer 0.2, 0, sub {
    warn "Send...\n";
    $cv[$_]->send for 0..6;
};

run_tests;

!!1;

use Test::More tests => 2;

local $ENV{TEST_MAX_CONCUR} = 3;
my ($output, $err) = PackedTest->run;

is $output, q{1..7
ok 1 - [1] - [1]
ok 2 - [2] - [1]
ok 3 - [3] - [1]
ok 4 - [4] - [1]
ok 5 - [5] - [1]
ok 6 - [6] - [1]
ok 7 - [7] - [1]
};

is $err, q{cv[0] test sync section
cv[1] test sync section
cv[2] test sync section
Send...
cv[0] test async section
cv[1] test async section
cv[2] test async section
cv[3] test sync section
cv[3] test async section
cv[4] test sync section
cv[4] test async section
cv[5] test sync section
cv[5] test async section
cv[6] test sync section
cv[6] test async section
};
