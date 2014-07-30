use strict;
use warnings;
use Test::More;
use Test::TCP;
use File::Which qw/which/;

use AnyEvent::Loop;
use AnyEvent;
use Workman::Test::Queue;
use Workman::Queue::Gearman;

my $bin = which('gearmand') or plan skip_all => "gearmand is not installed.";
my $gearmand = Test::TCP->new(
    code => sub {
        my $port = shift;
        exec $bin, '--port' => $port;
        die "cannot execute $bin: $!";
    },
);

my $queue = Workman::Queue::Gearman->new(job_servers => ['127.0.0.1:'.$gearmand->port]);
Workman::Test::Queue->new($queue)->run;
