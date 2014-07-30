package Workman::Queue::Gearman;
use strict;
use warnings;
use utf8;

use parent qw/Workman::Queue/;
use Class::Accessor::Lite ro => [qw/prefix job_servers/];

our $VERSION = '0.01';

use AnyEvent;
use AnyEvent::Gearman::Worker;
use AnyEvent::Gearman::Client;
use Workman::Job;
use Workman::Request;
use Workman::Server::Exception::DequeueAbort;
use JSON::XS;
use Log::Minimal qw/warnf croakf/;

sub _json {
    my $self = shift;
    return $self->{_json} ||= JSON::XS->new->utf8;
}

sub register_tasks {
    my ($self, $taskset) = @_;
    if (exists $self->{taskset}) {
        warnf '[%d] workers already registerd to gearmand.', $$;
        return;
    }
    $self->{taskset} = $taskset;
    return;
}

sub _setup_gearman_worker {
    my $self = shift;
    return if exists $self->{gearman};

    if (not exists $self->{taskset}) {
        croakf '[%d] required call $queue->register_tasks before call dequeue.', $$;
    }

    my $gearman = $self->{gearman} = AnyEvent::Gearman::Worker->new(
        job_servers => [@{ $self->job_servers }],
        $self->prefix ? (
            prefix  => $self->prefix,
        ) : (),
    );

    for my $name ($self->{taskset}->get_all_task_names) {
        $gearman->register_function($name => sub {
            my $job = shift;
            $self->_send_job($job);
        });
    }

    return;
}

sub _client {
    my $self = shift;
    return $self->{_client} ||= AnyEvent::Gearman::Client->new(
        job_servers => [@{ $self->job_servers }],
        $self->prefix ? (
            prefix  => $self->prefix,
        ) : (),
    );
}

sub _unsetup_gearman_worker {
    my $self = shift;
    my $gearman = delete $self->{gearman} or return;
    $_->mark_dead() for @{ $gearman->job_servers };
    return;
}

sub enqueue {
    my ($self, $name, $args, $opt) = @_;
    $self->_unsetup_gearman_worker();

    my $cv       = AnyEvent->condvar;
    my $client   = $self->_client;
    my $workload = $self->_deflate($args);
    return Workman::Request->new(
        on_wait => sub {
            $client->add_task(
                $name => $workload,
                on_complete => sub {
                    my (undef, $res) = @_;
                    my ($result, $e) = @{ $self->_inflate($res) };
                    if (defined $e) {
                        $cv->croak($e);
                    }
                    else {
                        $cv->send($result);
                    }
                },
            );
            return $cv->recv;
        },
        on_background => sub {
            $client->add_task_bg(
                $name => $workload,
                on_created => sub { $cv->send() },
            );
            $cv->recv;
        },
    );
}

sub dequeue {
    my $self = shift;
    $self->_setup_gearman_worker();

    local $self->{cv} = AnyEvent->condvar;
    return $self->{cv}->recv;
}

sub dequeue_abort {
    my $self = shift;
    if (defined $self->{cv}) {
        local $SIG{__DIE__} = sub { $self->{cv}->croak(@_) };
        Workman::Server::Exception::DequeueAbort->throw();
    }
}

sub _inflate {
    my ($self, $workload) = @_;
    return $self->_json->decode($workload);
}

sub _deflate {
    my ($self, $args) = @_;
    return $self->_json->encode($args);
}

sub _send_job {
    my ($self, $job) = @_;
    $self->{cv}->send(
        Workman::Job->new(
            name     => $job->function,
            args     => $self->_inflate($job->workload),
            on_done  => sub {
                my $result = shift;
                $job->complete(
                    $self->_deflate([$result, undef])
                );
            },
            on_abort => sub {
                my $e = shift;
                $job->complete(
                    $self->_deflate([undef, $e])
                );
            },
        )
    );
}

1;
__END__

=encoding utf-8

=head1 NAME

Workman::Queue::Gearman - queue manager for Workman

=head1 SYNOPSIS

    my $queue   = Workman::Queue::Gearman->new(job_servers => ['127.0.0.1:7003'], prefix => "myproj:");
    my $profile = Workman::Server::Profile->new(max_workers => 10, queue => $queue);
    $profile->set_task_loader(sub {
        my $set = shift;

        warn "[$$] register tasks...";
        my $task = Workman::Task->new(Echo => sub {
            my $args = shift;
            return $args;
        });
        $set->add($task);
    });

    # start
    Workman::Server->new(profile => $profile)->run();

=head1 DESCRIPTION

Workman::Queue::Gearman is ...

=head1 LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

karupanerura E<lt>karupa@cpan.orgE<gt>

=cut

