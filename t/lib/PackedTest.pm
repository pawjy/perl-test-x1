package PackedTest;
use strict;
use warnings;
use AnyEvent::Util;
use Filter::Util::Call;

sub import {
    my $class = shift;
    filter_add(bless {state => 0}, $class);
}

sub filter {
    my $self = shift;

    my $status = filter_read;

    if (/^\s*!!1\s*;\s*$/) {
        $self->{state}++;
    }

    if ($ENV{PACKEDTEST_TEST_SCRIPT}) {
        if ($self->{state} == 0 or $self->{state} == 1) {
            #
        } else {
            $_ = '';
        }
    } else {
        if ($self->{state} == 0 or $self->{state} == 2) {
            #
        } else {
            $_ = '';
        }
    }

    return $status;
}

sub run {
    my $file_name = ((caller)[1]);

    my $cv = run_cmd
        "PACKEDTEST_TEST_SCRIPT=1 perl @{[quotemeta $file_name]}",
        '>' => \my $output,
        '2>' => \my $err,
    ;
    my $result = $cv->recv;

    return ($output, $err, $result);
}

1;
