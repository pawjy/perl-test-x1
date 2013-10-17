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
                my $x = 100 / 0;
                undef $timer;
                $c->done;
                undef $c;
            } $c;
        },
    );
} n => 1, name => ['ae', 'timer'];

test {
    my $c = shift;
    hoge();
    $c->done;
} n => 2, name => ['sync-only'];

run_tests;

!!1;

use Test::More tests => 6;

my ($output, $err) = PackedTest->run;

like $output, qr/^1\.\.3$/m;

like $err, qr/^Illegal division by zero at .+?died\.t line 20\.$/m;
like $output, qr/^not ok \d+ - \[\d+\] sync-only - lives_ok$/m;

#like $err, qr/^# \[\d+\] ae\.timer: \$c->done is not invoked \(or \|die\|d within test\?\)/m;
#like $err, qr/^# \[\d+\] ae\.timer: Looks like you planned 1 test but ran 0\.$/m;
like $err, qr/Undefined subroutine &main::hoge called at .+?died.t line 31/;
like $err, qr/^# Looks like you /m;
like $err, qr/Possible memory leak detected/;
