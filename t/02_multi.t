use strict;
use warnings;
use Test::More;
use Test::TCP;
use File::Which qw/which/;

use Workman::Test::Queue;
use Workman::Queue::Gearman;

my $bin = which('gearmand') or plan skip_all => "gearmand is not installed.";
my @gearmand = map {
    Test::TCP->new(
        code => sub {
            my $port = shift;
            exec $bin, '--port' => $port;
            die "cannot execute $bin: $!";
        },
    );
} 1..3;

my $queue = Workman::Queue::Gearman->new(job_servers => [map { '127.0.0.1:'.$_->port } @gearmand]);
Workman::Test::Queue->new($queue)->run();
