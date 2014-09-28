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

test {
    my $c = shift;
    my $timer; $timer = AE::timer 2, 0, sub {
        test {
            ok not 1;
            done $c;
            undef $c;
            undef $timer;
        } $c;
    };
} n => 1, timeout => 1;

run_tests;

!!1;

use Test::More tests => 4;

my ($output, $err) = PackedTest->run;

is $output, q{1..1
not ok 1 - [1] - lives_ok
ok 2 # skip
};

like $err, qr{at .+?timeout.t line 25.\s+#\s+got: 'Test: Timeout \(1\)'};
like $err, qr{Possible memory leak detected}; # $c is referenced by $timer
unlike $err, qr/X1.pm/;
