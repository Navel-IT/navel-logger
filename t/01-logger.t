# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-logger is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

use strict;
use warnings;

use Test::More tests => 3;
use Test::Exception;

BEGIN {
    use_ok('Navel::Logger');
}

#-> main

my $log_file = './' . __FILE__ . '.log';

lives_ok {
    my $logger = Navel::Logger->new(
        facility => 'local0',
        severity => 'notice',
        file_path => $log_file
    )->notice($log_file)->flush_queue();
} 'Navel::Logger->new()->notice()->flush_queue(): push data in ' . $log_file;

END {
    ok(-f $log_file, $log_file . ' created') && unlink $log_file;
}

#-> END

__END__
