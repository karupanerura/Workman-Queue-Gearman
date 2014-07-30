# NAME

Workman::Queue::Gearman - queue manager for Workman

# SYNOPSIS

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

# DESCRIPTION

Workman::Queue::Gearman is ...

# LICENSE

Copyright (C) karupanerura.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

karupanerura <karupa@cpan.org>
