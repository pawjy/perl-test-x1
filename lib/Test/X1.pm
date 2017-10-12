package Test::X1;
use strict;
use warnings;
no warnings 'utf8';
use warnings FATAL => 'recursion';
our $VERSION = '5.0';
use AnyEvent;
push our @CARP_NOT, qw(Test::X1::Manager);

sub define_functions ($) {
    my $CLASS = shift;
    no strict 'refs';
    push @{$CLASS . '::EXPORT'}, qw(test run_tests get_test_manager);
    eval sprintf q{
        package %s;
        use Scalar::Util qw(weaken);

        sub import (;@) {
            my $orig = shift;
            my ($copy) = caller;
            no strict 'refs';
            for my $method (@{$orig . '::EXPORT'}) {
                *{$copy . '::' . $method} = $orig->can($method);
            }
        }

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

        if ('%s' ne 'Test::X1') {
            push @%s::Manager::ISA, qw(Test::X1::Manager);
            push @%s::Context::ISA, qw(Test::X1::Context);
        }

        1;
    }, ($CLASS) x 9 or die $@;
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
        pid => $$,
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

sub test_method_excluded_regexp {
    my $self = shift;
    return $self->{test_method_excluded_regexp}
        if exists $self->{test_method_excluded_regexp};
    my $tm = $ENV{TEST_METHOD_EXCLUDED};
    if (defined $tm) {
        return $self->{test_method_excluded_regexp} = qr/$tm/;
    } else {
        return $self->{test_method_excluded_regexp} = undef;
    }
}

sub define_test {
    my $self = shift;

    croak "Can't define a test after |run_tests| (\$c argument is missing?)"
        if $self->{test_started};

    my ($code, %args) = @_;
    $args{id} = $self->{next_test_number}++;

    my $methods = $self->test_method_regexp;
    my $methods_x = $self->test_method_excluded_regexp;
    if (defined $methods or defined $methods_x) {
        my $context_class = ref $self;
        $context_class =~ s/::Manager$/::Context/;
        my $name = $context_class->test_name(\%args);
        return if defined $methods and not $name =~ /$methods/;
        return if defined $methods_x and $name =~ /$methods_x/;
    }

    if (Carp::shortmess =~ / at (.+) line ([0-9]+)\.?$/s) {
        $args{defined_location_file} = $1;
        $args{defined_location_line} = $2;
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
            $self->diag(undef, sprintf '%s - %s - subtests skipped.',
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

    my $builder = Test::More->builder;
    binmode $builder->output, ":utf8";
    binmode $builder->failure_output, ":utf8";
    binmode $builder->todo_output, ":utf8";
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
                        ref $name eq 'ARRAY' ? @$name : $name;
                    $name = length $name
                        ? $self->{test_context}->next_subtest_name . ' ' . $name
                        : $self->{test_context}->next_subtest_name;
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

    my $schedule_test;
    $cv->begin(sub {
        undef $schedule_test;
        $_[0]->send;
    }); # (b)

    my $context_args = $self->context_args;
    my $context_class = ref $self;
    $context_class =~ s/::Manager$/::Context/;

    my @test = @{$self->{tests}};
    $schedule_test = sub {
        if (@test) {
            my $test = shift @test;
            my $test_cv = AE::cv();

            my $run_test;
            my $test_name;
            my $context = $context_class->new(
                args => $test->[1],
                cv => $test_cv,
                cb => sub {
                    $skipped_tests += $_[0]->{skipped_tests} || 0;
                },
                %$context_args,
            );
            my $run_timeout = $test->[1]->{timeout} || 60;
            my $run_timer;
            $run_test = sub {
                $run_timer = AE::timer $run_timeout, 0, sub {
                    if (defined $context and not $context->{done}) {
                        $context->receive_exception("Test: Timeout ($run_timeout)");
                        $context->done;
                    }
                    undef $run_timer;
                };
                local $self->{test_context} = $context;
                eval {
                    $test->[0]->($context);
                    1;
                } or do {
                    $context->receive_exception($@);
                    $context->done;
                    undef $run_timer;
                };
            };
            my $wait = exists $test->[1]->{wait}
                ? delete $test->[1]->{wait} : $self->default_test_wait_cv;
            $wait = $wait->() if ref $wait eq 'CODE';
            my $wait_timeout = 60;
            if (ref $wait eq 'HASH') {
                $self->{destroy_cvs}->{$wait->{destroy_as_cv}} = $wait->{destroy_as_cv}
                    if $wait->{destroy_as_cv};
                $wait_timeout = $wait->{timeout} || $wait_timeout;
                $wait = $wait->{cv};
            }
            if ($wait) {
                $cv->begin; # (a)
                $context->{wait_timeout} = $wait_timeout;
                my $wait_timer; $wait_timer = AE::timer $wait_timeout, 0, sub {
                    $context->receive_exception("Wait: Timeout ($wait_timeout)");
                    $context->done;
                    $cv->end; # (a)
                    undef $wait_timer;
                };
                my $test_cb_old = $wait->cb;
                $wait->cb(sub {
                    eval {
                        $context->{received_data} = $_[0]->recv;
                    };
                    if ($@) {
                        $context->receive_exception("Wait: failed ($@)");
                        $cv->end; # (a)
                        $context->done;
                        undef $wait_timer;
                        return;
                    }
                    if (UNIVERSAL::can($context->{received_data}, 'context_begin')) {
                        my $args = [@_];
                        return unless $wait_timer;
                        $wait_timer = AE::timer $wait_timeout, 0, sub {
                            $context->receive_exception("context_begin: Timeout ($wait_timeout)");
                            $cv->end; # (a)
                            $context->done;
                            undef $wait_timer;
                        };
                        $context->{received_data}->context_begin(sub {
                            return unless $wait_timer;
                            $context->{received_data}->context_begin(sub {
                                return unless $wait_timer;
                                undef $wait_timer;
                                $run_test->();
                                $test_cb_old->(@$args) if $test_cb_old;
                                if (UNIVERSAL::can($context->{received_data}, 'context_end')) {
                                    $wait_timer = AE::timer $wait_timeout, 0, sub {
                                        $context->receive_exception("context_end: Timeout ($wait_timeout)");
                                        $cv->end; # (a)
                                        undef $wait_timer;
                                    };
                                    $context->{received_data}->context_end(sub {
                                        return unless $wait_timer;
                                        undef $wait_timer;
                                        $cv->end; # (a)
                                    });
                                } else {
                                    $cv->end; # (a)
                                }
                            });
                        });
                    } else {
                        undef $wait_timer;
                        $run_test->();
                        $test_cb_old->(@_) if $test_cb_old;
                        $cv->end; # (a)
                    }
                });
            } else {
                $run_test->();
            }

            $test_cv->cb(sub {
                AE::postpone {
                    $schedule_test->();
                    delete $context->{received_data};
                    undef $context;
                    undef $run_timer;
                };
            });
        } else {
            $cv->end; # (e)
        }
    }; # $schedule_test
    for (1..($ENV{TEST_MAX_CONCUR} || 5)) {
        $cv->begin; # (e)
        $schedule_test->();
    }

    $cv->end; # (b)

    # Run tests
    $cv->recv;

    delete $self->{test_context};
    undef $schedule_test;
    {
        # XXX The |destory_cvs| callback should be invoked as soon as
        # all relevant tests has been run.
        my $cv = AE::cv;
        $cv->begin; # (c)
        for (grep { $_ } values %{$self->{destroy_cvs} or {}}) {
            $cv->begin; # (d)
            $_->()->cb(sub { $cv->end }); # (d)
        }
        $cv->end; # (c)
        $cv->recv;
    }

    if ($skipped_tests) {
      local $Test::Builder::Level = $Test::Builder::Level + 2;
      Test::More::is $skipped_tests, 0, "No skipped tests";
      $self->diag(undef, sprintf "Looks like you skipped %d test%s.",
                             $skipped_tests, $skipped_tests == 1 ? '' : 's');
    }
    Test::More::done_testing()
            unless $test_count and not $more_tests;
    undef $self;
}

sub default_test_wait_cv {
    return undef;
}

sub context_args {
    return {};
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
    return unless ($_[0]->{pid} || 0) == $$;
    {
        local $@;
        eval { die };
        if ($@ =~ /during global destruction/) {
            warn "Possible memory leak detected (Test::X1::Manager)\n";
        }
    }
    $_[0]->stop_test_manager;
}

package Test::X1::Context;
use Scalar::Util qw(weaken);

sub new {
    my $class = shift;
    require AE;
    my $self = bless {@_, signals => [], pid => $$}, $class;
    weaken (my $s = $self);
    push @{$self->{signals}}, AE::signal (TERM => sub { $s->onterminate ('TERM') });
    push @{$self->{signals}}, AE::signal (INT => sub { $s->onterminate ('INT') });
    push @{$self->{signals}}, AE::signal (QUIT => sub { $s->onterminate ('QUIT') });
    return $self;
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
        my $name = '[' . $args->{id} . ']';
        if (defined $args->{name}) {
            if (ref $args->{name} eq 'ARRAY') {
                $name .= ' ' . (join '.', map {
                    defined $_ ? length $_ ? $_ : '(empty)' : '(undef)';
                } @{$args->{name}});
            } else {
                $name .= ' ' . $args->{name};
            }
        }
        $name;
    };
}

sub test_location ($) {
  my $self = shift;
  my $file = $self->{args}->{defined_location_file};
  $file = '(unknown)' unless defined $file;
  $file =~ tr/\x0D\x0A\x22/\x20\x20\x20/;
  my $line = 0+($self->{args}->{defined_location_line} || 0);
  return ($file, $line);
} # test_location

sub next_subtest_name {
    my $self = shift;
    my $local_id = $self->{done_tests} || 0;
    $local_id++;
    my $name = '[' . $local_id . ']';
    if (defined $self->{test_block_name} and length $self->{test_block_name}) {
       return $self->test_name . ' - ' . $name . ' ' . $self->{test_block_name};
   } else {
       return $self->test_name . ' - ' . $name;
   }
}

sub diag {
    my ($self, undef, $msg) = @_;
    Test::More->builder->diag($self->test_name . ': ' . $msg);
}

sub receive_exception ($$) {
  my ($self, $err) = @_;
  $self->_subtest_failed ($err, undef, 'lives_ok');
} # receive_exception

sub _subtest_failed ($$$$) {
  my ($self, $v1, $v2, $name) = @_;
  local $Test::X1::ErrorReportedByX1 = 1;
  my ($file, $line) = $self->test_location;
  my $code = sprintf qq{#line %d "%s"\n%s},
      $line, $file,
      q{Test::More::is($v1, $v2, $self->test_name . ' - ' . $name);};
  eval $code;
  die $@ if $@;
} # _subtest_failed

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
        $self->_subtest_failed ('done', undef, '$c->done');
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
                #Test::More->builder->skip for 1..($self->{args}->{n} - $done_tests);
                $self->{skipped_tests} += ($self->{args}->{n} - $done_tests);
            }
            $self->diag(undef, sprintf "Looks like you planned %d test%s but ran %d.",
                            $self->{args}->{n},
                            $self->{args}->{n} == 1 ? '': 's',
                            $done_tests);
        }
    } elsif ($done_tests == 0) {
        $self->diag(undef, 'No subtests run!');
    }

    delete $self->{signals};
    $self->{done} = 1;
    $self->{cb}->($self) if $self->{cb};

    if ($self->{received_data} and
        UNIVERSAL::can($self->{received_data}, 'context_end')) {
        ## If there is received data, the test always has the "wait"
        ## such that the |wait_timeout| has been set.
        my $wait_timeout = $self->{wait_timeout};
        my $wait_timer; $wait_timer = AE::timer $wait_timeout, 0, sub {
            $self->receive_exception("context_end: Timeout ($wait_timeout)");
            $self->{cv}->send;
            undef $wait_timer;
        };
        $self->{received_data}->context_end(sub {
            undef $wait_timer;
            $self->{cv}->send;
        });
    } else {
        $self->{cv}->send;
    }
}

sub onterminate ($$) {
  my ($self, $type) = @_;
  $self->diag (undef, "Terminated by SIG$type");
  delete $self->{signals};
  AE::postpone (sub { exit });
} # onterminate

sub DESTROY {
    my $self = shift;
    return unless ($self->{pid} || 0) == $$;
    #${^GLOBAL_PHASE}
    {
        local $@;
        eval { die };
        if ($@ =~ /during global destruction/) {
            warn "Possible memory leak detected (Test::X1::Context)\n";
        }
    }
    unless ($self->{done}) {
        die "Can't continue test anymore (an exception is thrown before the test?)\n" unless $self->{cv};
        $self->_subtest_failed (undef, 'done', '$c->done');
        $self->diag(undef, "\$c->done is not invoked (or |die|d within test?)");
        $self->done;
    }
}

1;

=head1 LICENSE

Copyright 2012-2013 Hatena <https://www.hatena.ne.jp/>.

Copyright 2012-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
