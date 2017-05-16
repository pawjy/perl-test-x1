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

  done $c;
} n => 2;

run_tests;

!!1;

use Test::More tests => 5;

my ($output, $err, $result) = PackedTest->run;

is $output, q{1..2
not ok 1 - No skipped tests
};

like $err, qr{^# \[1\]: Looks like you planned 2 tests but ran 0.$}m;
like $err, qr{^# Looks like you skipped 2 tests.$}m;
like $err, qr{^# Looks like you failed 1 test of 1}m;

isnt $result >> 8, 0, "exit code is error";
