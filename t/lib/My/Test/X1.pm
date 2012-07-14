package My::Test::X1;
use strict;
use warnings;
use Test::X1 ();

Test::X1::define_functions(__PACKAGE__);

package My::Test::X1::Manager;
use AnyEvent;

sub my_cv {
    my $cv = AE::cv;
    my $timer; $timer = AE::timer 0.5, 0, sub {
        $cv->send;
        undef $timer;
    };
    return $cv;
}

package My::Test::X1::Context;

my $Value = 0;

sub my_value {
    return ++$Value;
}

1;
