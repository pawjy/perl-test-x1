package Test::X1;
use strict;
use warnings;
our $VERSION = '1.0';

sub define_functions ($) {
    my $CLASS = shift;
    no strict 'refs';
    push @{$CLASS . '::EXPORT'}, qw(test run_tests get_test_manager);
    eval sprintf q{
        package %s;
        use Exporter::Lite;
        use Scalar::Util qw(weaken);

        sub get_test_manager () {
            $%s::manager ||= %s::Manager->new;
        }

        sub test (&;@) {
            if (defined $_[1] and UNIVERSAL::isa($_[1], 'Test::X1::Context')) {
                get_test_manager->execute_with_context(@_);
             } else {
                get_test_manager->define_test(@_);
             }
        }
        
        sub run_tests () {
            get_test_manager->run_tests;
            weaken $%s::manager;
        }

        END {
            $%s::manager->stop_test_manager if $%s::manager;
        }

        1;
    }, $CLASS, $CLASS, $CLASS, $CLASS, $CLASS, $CLASS or die $@;
}

Test::X1::define_functions(__PACKAGE__);

package Test::X1::Manager;
use Carp qw(croak);
use Test::More ();
use Term::ANSIColor ();

sub new {
    return bless {
        next_test_number => 1,
        tests => [],
        #test_started
        #test_context
    }, $_[0];
}

sub test_method_regexp {
    my $self = shift;
    return $self->{test_method_regexp} if exists $self->{test_method_regexp};
    my $tm = $ENV{TEST_METHOD};
    if (defined $tm) {
        return $self->{test_method_regexp} = qr/$tm/;
    } else {
        return $self->{test_method_regexp} = undef;
    }
}

sub define_test {
    my $self = shift;

    croak "Can't define a test after |run_tests| (\$c argument is missing?)"
        if $self->{test_started};

    my ($code, %args) = @_;
    $args{id} = $self->{next_test_number}++;

    my $methods = $self->test_method_regexp;
    if ($methods) {
        my $context_class = ref $self;
        $context_class =~ s/::Manager$/::Context/;
        my $name = $context_class->test_name(\%args);
        return unless $name =~ /$methods/;
    }

    push @{$self->{tests}}, [$code, \%args];
}

sub test_block_skip_regexp {
    my $self = shift;
    return $self->{test_block_skip_regexp}
        if exists $self->{test_block_skip_regexp};
    my $regexp = $ENV{TEST_BLOCK_SKIP};
    if (defined $regexp) {
        $self->{test_block_skip_regexp} = qr/$regexp/;
    } else {
        $self->{test_block_skip_regexp} = undef;
    }
}

sub execute_with_context {
    my ($self, $code, $context, %args) = @_;
    local $self->{test_context} = $context;
    my $name = $args{name};
    if (defined $name) {
        $name = join '.', 
            map { defined $_ ? length $_ ? $_ : '(empty)' : '(undef)' }
            ref $name eq 'ARRAY' ? @$name : $name;
    }
    local $context->{test_block_name} = $name;
    if ($name) {
        my $skip = $self->test_block_skip_regexp;
        if ($skip and $name =~ /$skip/) {
            Test::More->builder->skip;
            $self->diag(undef, sprintf '%s.%s - subtests skipped.',
                                   $context->test_name, $name);
            return;
        }
    }
    return $code->();
}

sub run_tests {
    my $self = shift;
    $self->{test_started} = 1;
    
    my $test_count = 0;
    my $more_tests;
    for (@{$self->{tests}}) {
        if (defined $_->[1]->{n}) {
            $test_count += $_->[1]->{n};
        } else {
            $more_tests = 1;
        }
    }

    Test::More::plan(tests => $test_count) if $test_count and not $more_tests;

    no warnings 'redefine';
    require Test::Builder;
    my $original_ok = Test::Builder->can('ok');
    local *Test::Builder::ok = sub {
        my ($builder, $test, $name) = @_;
        local $Test::Builder::Level = $Test::Builder::Level + 1;

        if ($self->{test_context}) {
            if (defined $name) {
                if ($Test::X1::ErrorReportedByX1) {
                    #
                } else {
                    $name = join '.', 
                        map { defined $_ ? length $_ ? $_ : '(empty)' : '(undef)' } 
                        $self->{test_context}->next_subtest_name,
                        ref $name eq 'ARRAY' ? @$name : $name;
                }
            } else {
                $name = $self->{test_context}->next_subtest_name;
            }

            if ($self->{test_context}->{done}) {
                $self->diag(undef, $name . ': A subtest occurs after $c->done is called.');
            }

            $self->{test_context}->{done_tests}++;
        }
        
        my $result = $original_ok->($builder, $test, $name);

        if ($self->{test_context} and not $result) {
            $self->{test_context}->{failed_tests}++;
        }

        return $result;
    };

    my $skipped_tests = 0;

    require AnyEvent;
    my $cv = AnyEvent->condvar;

    $self->within_test_env(sub {
        my $self = shift;
        $cv->begin(sub {
            $cv->send;
        });

        my $context_args = $self->context_args;

        my $context_class = ref $self;
        $context_class =~ s/::Manager$/::Context/;
        for my $test (@{$self->{tests}}) {
            my $test_name;
            my $context = $context_class->new(
                args => $test->[1],
                cv => $cv,
                cb => sub {
                    $skipped_tests += $_[0]->{skipped_tests} || 0;
                },
                %$context_args,
            );
            $cv->begin;
            my $run_test = sub {
                local $self->{test_context} = $context;
                eval {
                    $test->[0]->($context);
                    1;
                } or do {
                    $context->receive_exception($@);
                };
            };
            my $wait = exists $test->[1]->{wait}
                ? $test->[1]->{wait} : $self->default_test_wait_cv;
            if ($wait) {
                my $test_cb_old = $wait->cb;
                $wait->cb(sub {
                    local $context->{received_data} = $_[0]->recv;
                    $run_test->();
                    $test_cb_old->(@_) if $test_cb_old;
                });
            } else {
                $run_test->();
            }
        }

        $cv->end;
    });

    $cv->recv;
    $self->terminate_test_env;
    delete $self->{test_context};

    Test::More::done_testing()
            unless $test_count and not $more_tests;
    if ($skipped_tests) {
        $self->diag(undef, sprintf "Looks like you skipped %d test%s.",
                               $skipped_tests, $skipped_tests == 1 ? '' : 's');
    }
}

sub default_test_wait_cv {
    return undef;
}

sub within_test_env {
    my ($self, $code) = @_;
    $code->($self);
}

sub context_args {
    return {};
}

sub terminate_test_env {
    #
}

sub diag {
    if (-t STDOUT) {
        Test::More->builder->diag(Term::ANSIColor::colored [$_[1]], $_[2]);
    } else {
        Test::More->builder->diag($_[2]);
    }
}

sub note {
    if (-t STDOUT) {
        Test::More->builder->note(Term::ANSIColor::colored [$_[1]], $_[2]);
    } else {
        Test::More->builder->note($_[2]);
    }
}

sub stop_test_manager {
    #
}

sub DESTROY {
    $_[0]->stop_test_manager;
}

package Test::X1::Context;

sub new {
    my $class = shift;
    return bless {@_}, $class;
}

sub test_name {
    my ($self, $args);
    if (ref $_[0]) {
        $self = shift;
        $args = $self->{args};
    } else {
        $self = {};
        $args = $_[1];
    }
    return $self->{test_name} ||= do {
        my $name = '(' . $args->{id} . ')';
        if (defined $args->{name}) {
            if (ref $args->{name} eq 'ARRAY') {
                $name = (join '.', map {
                    defined $_ ? length $_ ? $_ : '(empty)' : '(undef)';
                } @{$args->{name}}) . ' ' . $name;
            } else {
                $name = $args->{name} . ' ' . $name;
            }
        }
        $name;
    };
}

sub next_subtest_name {
    my $self = shift;
    my $local_id = $self->{done_tests} || 0;
    $local_id++;
    return join '.',
        $self->test_name,
        (defined $self->{test_block_name} ? $self->{test_block_name} : ()),
        $local_id;
}

sub diag {
    my ($self, undef, $msg) = @_;
    Test::More->builder->diag($self->test_name . ': ' . $msg);
}

sub receive_exception {
    my ($self, $err) = @_;
    local $Test::X1::ErrorReportedByX1 = 1;
    Test::More::is($err, undef, $self->test_name . '.lives_ok');
}

sub received_data {
    return $_[0]->{received_data};
}

sub cb {
    if (@_ > 1) {
        $_[0]->{cb} = $_[1];
    }
    return $_[0]->{cb};
}

sub done {
    my $self = shift;
    if ($self->{done}) {
        local $Test::X1::ErrorReportedByX1 = 1;
        Test::More::is('done', undef, $self->test_name . ' $c->done');
        $self->diag(undef, '$c->done is called more than once in a test');
        return;
    }

    my $done_tests = $self->{done_tests} || 0;
    my $failed_tests = $self->{failed_tests} || 0;
    if ($failed_tests) {
        $self->diag(undef, sprintf "%d test%s failed",
                               $failed_tests, $failed_tests == 1 ? '' : 's');
    }
    if (defined $self->{args}->{n}) {
        if ($self->{args}->{n} != $done_tests) {
            if ($self->{args}->{n} > $done_tests) {
                Test::More->builder->skip for 1..($self->{args}->{n} - $done_tests);
                $self->{skipped_tests} += ($self->{args}->{n} - $done_tests);
            }
            $self->diag(undef, sprintf "Looks like you planned %d test%s but ran %d.",
                            $self->{args}->{n},
                            $self->{args}->{n} == 1 ? '': 's',
                            $done_tests);
        }
    } elsif ($done_tests == 0) {
        $self->diag(undef, 'No test');
    }

    $self->{done} = 1;
    $self->{cb}->($self) if $self->{cb};

    $self->{cv}->end;
}

sub DESTROY {
    my $self = shift;
    unless ($self->{done}) {
        die "Can't continue test anymore (an exception is thrown before the test?)\n" unless $self->{cv};

        local $Test::X1::ErrorReportedByX1 = 1;
        Test::More::is(undef, 'done', $self->test_name . ' $c->done');
        $self->diag(undef, "\$c->done is not invoked (or |die|d within test?)");
        $self->done;
    }
}

1;
