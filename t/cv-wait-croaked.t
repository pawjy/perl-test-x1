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
{
    my $timer; $timer = AE::timer 1, 0, sub {
        $cv->croak ("abc");
        undef $timer;
    };
}

test {
    my $c = shift;
    ok not 1;
    done $c;
} n => 1, wait => {cv => $cv}, name => "wait";

test {
    my $c = shift;
    ok not 1;
    done $c;
} n => 1, wait => $cv, name => "wait";

run_tests;

!!1;

use Test::More tests => 4;

my ($output, $err) = PackedTest->run;

like $output, qr{^1..2
not ok 1 - ... wait - lives_ok
not ok 2 - ... wait - lives_ok
not ok 3 - No skipped tests
$};

like $err, qr{got: 'Wait: failed \(abc at .+?\)'}s;
like $err, qr{Wait: failed.+?got: 'Wait: failed \(abc at .+?\)'}s;
unlike $err, qr{Possible memory leak detected}; # $c is referenced by $timer
