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
  ok 1;
  ok 2;
  ok 3;
  done $c;
} n => 2;

run_tests;

!!1;

use Test::More tests => 3;

my ($output, $err, $result) = PackedTest->run;

is $output, q{1..2
ok 1 - [1] - [1]
ok 2 - [1] - [2]
ok 3 - [1] - [3]
};

is $err, q{# [1]: Looks like you planned 2 tests but ran 3.
# Looks like you planned 2 tests but ran 3.
};

isnt $result >> 8, 0, "exit code is error";
