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
    hoge();
    $c->done;
} n => 2, name => ['sync-only'];

run_tests;

!!1;

use Test::More tests => 5;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.2$/m;

like $output, qr/^not ok \d+ - \[\d+\] sync-only - lives_ok$/m;

like $err, qr/Undefined subroutine &main::hoge called at .+?died-sync-only.t line /;
like $err, qr/^# Looks like you /m;
unlike $err, qr/Possible memory leak detected/;
