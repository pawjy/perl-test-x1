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

test {
    my $c = shift;
    ok not 1;
    done $c;
} n => 1, wait => {cv => $cv, timeout => 1.2};

test {
    my $c = shift;
    ok not 1;
    done $c;
} n => 1, wait => {cv => $cv, timeout => 1.3};

run_tests;

!!1;

use Test::More tests => 4;

my ($output, $err) = PackedTest->run;

is $output, q{1..2
not ok 1 - [1] - lives_ok
not ok 2 - [2] - lives_ok
not ok 3 - No skipped tests
};

like $err, qr{got: 'Wait: Timeout \(1\.2\)'};
like $err, qr{got: 'Wait: Timeout \(1\.3\)'};
unlike $err, qr{Possible memory leak detected}; # $c is referenced by $timer
