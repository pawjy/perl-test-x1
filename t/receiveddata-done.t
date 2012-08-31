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

{
    package test::Object1;

    sub context_begin {
        my ($self, $cb) = @_;
        print "# test::Object1 ($self->{id})->context_begin\n";
        $cb->();
    }

    sub context_end {
        my ($self, $cb) = @_;
        print "# test::Object1 ($self->{id})->context_end\n";
        $cb->();
    }
}

my $i = 0;
my $cv = AE::cv;
$cv->send(bless {id => ++$i}, 'test::Object1');

test {
    my $c = shift;
    my $timer; $timer = AnyEvent->timer(
        after => 0.2,
        cb => sub {
            test {
                undef $timer;
                isa_ok $c->received_data, 'test::Object1';
                $c->done;
            } $c;
        },
    );
} n => 1, wait => $cv;

test {
    my $c = shift;
    isa_ok $c->received_data, 'test::Object1';
    $c->done;
} n => 1, wait => $cv;

run_tests;

print "# done\n";

!!1;

use Test::More tests => 2;

my ($output, $err) = PackedTest->run;

is $output, q{1..2
# test::Object1 (1)->context_begin
# test::Object1 (1)->context_begin
# test::Object1 (1)->context_end
# test::Object1 (1)->context_begin
# test::Object1 (1)->context_begin
# test::Object1 (1)->context_end
ok 1 - [2] - [1] The object isa test::Object1
# test::Object1 (1)->context_end
ok 2 - [1] - [1] The object isa test::Object1
# test::Object1 (1)->context_end
# done
};
is $err, '';
