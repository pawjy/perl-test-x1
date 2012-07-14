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

no warnings 'redefine';
*Test::X1::Manager::stop_test_manager = sub {
#line 1 "custom stop_test_manager"
    warn "stop_test_manager invoked";
};

test {
    my $c = shift;
    ok 1;
    done $c;
} n => 1;

my $tm = get_test_manager;
$tm->{foo} = $tm;

run_tests;

!!1;

use Test::More tests => 2;

my ($output, $err) = PackedTest->run;

is $output, q{1..1
ok 1 - [1] - [1]
};

is $err, q{stop_test_manager invoked at custom stop_test_manager line 1.
stop_test_manager invoked at custom stop_test_manager line 1 during global destruction.
};
