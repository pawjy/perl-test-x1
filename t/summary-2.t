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

test {
  my $c = shift;
  ok 1;
  done $c;
};

run_tests;

!!1;

use Test::More tests => 1;

my ($output, $err) = PackedTest->run;

unlike $err, qr/^# Failed: /m;
