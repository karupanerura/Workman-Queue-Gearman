package Workman::Queue::Gearman;
use strict;
use warnings;
use utf8;

use parent qw/Workman::Queue/;
use Class::Accessor::Lite ro => [qw/prefix job_servers/];

our $VERSION = '0.01';

use Queue::Gearman;
use Workman::Job;
use Workman::Request;
use Workman::Server::Exception::DequeueAbort;
use JSON::XS;
use Log::Minimal qw/warnf croakf/;

use constant MSG_ABORT => 'ABORT';

sub _client {
    my $self = shift;
    return $self->{_client} ||= $self->_create_new_client();
}

sub _create_new_client {
    my $self = shift;
    my $json = JSON::XS->new->utf8->allow_nonref;
    return Queue::Gearman->new(
        servers            => [@{ $self->job_servers }],
        serialize_method   => sub { $json->encode(@_) },
        deserialize_method => sub { $json->decode(@_) },
        prefix             => $self->prefix,
    );
}

sub register_tasks {
    my ($self, $taskset) = @_;

    for my $name ($taskset->get_all_task_names) {
        $self->_client->can_do($name);
    }

    return;
}

sub enqueue {
    my ($self, $name, $args, $opt) = @_;

    my $client = $self->_client;
    return Workman::Request->new(
        on_wait => sub {
            my $task = $client->enqueue_forground($name => $args);

        WAIT: # block
            $task->wait() until $task->is_finished;

            if ($task->fail) {
                if ($task->exception && $task->exception eq MSG_ABORT) {
                    $task = $client->enqueue_forground($name => $args); ## reenqueue
                    goto WAIT;
                }
                return;
            }

            return $task->result;
        },
        on_background => sub {
            $client->enqueue_background($name => $args);
            return;
        },
    );
}

sub dequeue {
    my $self = shift;

    my $job = $self->_client->dequeue();
    return unless defined $job;

    return Workman::Job->new(
        name     => $job->func,
        args     => $job->arg,
        on_done  => sub {
            my $result = shift;
            $job->complete($result);
        },
        on_fail => sub {
            $job->fail();
        },
        on_abort => sub {
            $job->fail(MSG_ABORT);
        },
    );
}

sub dequeue_abort {
    my $self = shift;
    Workman::Server::Exception::DequeueAbort->throw();
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

