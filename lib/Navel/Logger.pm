# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-logger is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Logger 0.1;

use Navel::Base;

use open qw/
    :std
    :utf8
/;

use AnyEvent::AIO;
use IO::AIO;

use Term::ANSIColor 'colored';

use Sys::Syslog 'syslog';

use Navel::Logger::Message;
use Navel::Logger::Message::Facility::Local;
use Navel::Logger::Message::Severity;
use Navel::Queue;
use Navel::Utils qw/
    blessed
    croak
    path
/;

#-> methods

sub new {
    my ($class, %options) = @_;

    bless {
        datetime_format => $options{datetime_format},
        hostname => $options{hostname},
        service => $options{service},
        service_pid => $options{service_pid} || $$,
        facility => Navel::Logger::Message::Facility::Local->new($options{facility}),
        severity => Navel::Logger::Message::Severity->new($options{severity}),
        colored => $options{colored} // 1,
        syslog => $options{syslog} || 0,
        file_path => $options{file_path},
        aio_filehandle => undef,
        queue => Navel::Queue->new()
    }, ref $class || $class;
}

sub messages {
    my $self = shift;

    [
        grep {
            $self->{severity}->compare($_->{severity});
        } @{$self->{queue}->{items}}
    ];
}

sub messages_to_string {
    my ($self, %options) = @_;

    my $colored = exists $options{colored} ? $options{colored} : $self->{colored};

    [
        map {
            $colored ? colored($_->to_string(), $_->{severity}->color()) : $_->to_string();
        } @{$self->messages()}
    ];
}

sub messages_to_syslog {
    my $self = shift;

    [
        map {
            $_->to_syslog();
        } @{$self->messages()}
    ];
}

sub say_messages {
    my ($self, %options) = @_;

    my $messages_to_string = $self->messages_to_string(%options);

    say join "\n", @{$messages_to_string} if @{$messages_to_string};

    $self;
}

sub enqueue {
    my ($self, %options) = @_;

    unless (blessed($options{message}) && $options{message}->isa('Navel::Logger::Message')) {
        $options{message} = Navel::Logger::Message->new(
            %options,
            (
                time => time,
                datetime_format => $self->{datetime_format},
                hostname => $self->{hostname},
                service => $self->{service},
                service_pid => $self->{service_pid},
                facility => $self->{facility}->{label}
            )
        );
    }

    $self->{queue}->enqueue($options{message});

    $self;
}

sub async_open {
    my ($self, %options) = @_;

    unless (blessed($self->{aio_filehandle})) {
        local $!;

        aio_open($self->{file_path}, IO::AIO::O_CREAT | IO::AIO::O_WRONLY | IO::AIO::O_APPEND, 0666, sub {
            if (my $filehandle = shift) {
                $self->{aio_filehandle} = $filehandle;

                $options{on_success}->($self->{aio_filehandle}) if ref $options{on_success} eq 'CODE';
            } else {
                $options{on_error}->($!) if ref $options{on_error} eq 'CODE';
            }
        });
    } else {
        $options{on_success}->($self->{aio_filehandle}) if ref $options{on_success} eq 'CODE';
    }

    $self;
}

sub async_close {
    my $self = shift;

    aio_close($self->{aio_filehandle}) if blessed($self->{aio_filehandle});

    undef $self->{aio_filehandle};

    $self;
}

sub flush_messages {
    my ($self, %options) = @_;

    if ($self->{syslog}) {
        local $@;

        for (@{$self->messages_to_syslog()}) {
            eval {
                syslog(@{$_});
            };
        }
    } elsif (defined $self->{file_path}) {
        my $messages_to_string = $self->messages_to_string(
            colored => 0
        );

        if (@{$messages_to_string}) {
            if ($options{async}) {
                $self->async_open(
                    on_success => sub {
                        my $to_write = (join "\n", @{$messages_to_string}) . "\n";

                        aio_write(shift, undef, (length $to_write), $to_write, 0);
                    },
                    on_error => sub {
                        $self->async_close();
                    }
                );
            } else {
                local $@;

                eval {
                    path($self->{file_path})->append(
                        [
                            map {
                                $_ . "\n"
                            } @{$messages_to_string}
                        ]
                    );
                };
            }
        }
    } else {
        $self->say_messages();
    }

    $self->{queue}->dequeue();
}

BEGIN {
    no strict 'refs';

    for my $severity (keys %Navel::Logger::Message::Severity::SEVERITIES) {
        *{__PACKAGE__ . '::' . $severity} = sub {
            shift->enqueue(
                text => shift,
                severity => $severity
            );
        };
    }
}

# sub AUTOLOAD {}

sub DESTROY {
    local $!;

    shift->async_close();
}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Logger

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-logger is licensed under the Apache License, Version 2.0

=cut
