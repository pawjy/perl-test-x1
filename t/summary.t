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
    my $timer; $timer = AnyEvent->timer(
        after => 0.2,
        cb => sub {
            test {
                undef $timer;
                ok 0;
                $c->done;
            } $c;
        },
    );
} n => 1, name => ['ae', 'timer'];

test {
    my $c = shift;
    ok 0;
    is 120, 120;
    $c->done;
} n => 2, name => ['sync-only'];

test {
  my $c = shift;
  ok 1;
  done $c;
};

run_tests;

!!1;

use Test::More tests => 3;

my ($output, $err) = PackedTest->run;

like $err, qr/^# Failed: .*\[1\]/m;
like $err, qr/^# Failed: .*\[2\]/m;
unlike $err, qr/^# Failed: .*\[3\]/m;
