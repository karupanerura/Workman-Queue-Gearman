requires 'Class::Accessor::Lite';
requires 'JSON::XS';
requires 'Log::Minimal';
requires 'Queue::Gearman';
requires 'Workman::Job';
requires 'Workman::Queue';
requires 'Workman::Request';
requires 'Workman::Server::Exception::DequeueAbort';
requires 'parent';

on configure => sub {
    requires 'Module::Build::Tiny', '0.035';
    requires 'perl', '5.008_001';
};

on test => sub {
    requires 'File::Which';
    requires 'Test::More';
    requires 'Test::TCP';
    requires 'Workman::Test::Queue';
};
