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

my $cv1 = AE::cv;
my $cv2 = AE::cv;

{
    package test::Package1;
    sub context_begin {
        #
    }
}
$cv1->send(bless {}, 'test::Package1');

{
    package test::Package2;
    sub context_begin {
        $_[1]->();
    }
    sub context_end {
        #
    }
}
$cv2->send(bless {}, 'test::Package2');

test {
    my $c = shift;
    diag "test 1 started";
    ok not 1;
    done $c;
} n => 1, wait => {cv => $cv1, timeout => 1.2};

test {
    my $c = shift;
    diag "test 2 started";
    ok 1;
    done $c;
} n => 1, wait => {cv => $cv2, timeout => 1.3};

run_tests;

!!1;

use Test::More tests => 6;

my ($output, $err) = PackedTest->run;

is $output, q{1..2
ok 1 - [2] - [1]
not ok 2 - [1] - lives_ok
not ok 3 - [2] - lives_ok
not ok 4 - [2] - lives_ok
not ok 5 - No skipped tests
};

like $err, qr{got: 'context_begin: Timeout \(1\.2\)'};
unlike $err, qr{test 1 started};
like $err, qr{test 2 started};
like $err, qr{got: 'context_end: Timeout \(1\.3\)'};
unlike $err, qr{Possible memory leak detected}; # $c is referenced by $timer
