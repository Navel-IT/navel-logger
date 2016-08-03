# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-logger is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Logger 0.1;

use Navel::Base;

use open qw/
    :std
    :utf8
/;

use AnyEvent::IO;

use Term::ANSIColor 'colored';

use Sys::Syslog 'syslog';

use Navel::Logger::Message;
use Navel::Logger::Message::Facility::Local;
use Navel::Logger::Message::Severity;
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
        colored => defined $options{colored} ? $options{colored} : 1,
        syslog => $options{syslog} || 0,
        file_path => $options{file_path},
        aio_filehandle => undef,
        queue => []
    }, ref $class || $class;
}

sub queue {
    my $self = shift;

    [
        grep {
            $self->{severity}->compare($_->{severity});
        } @{$self->{queue}}
    ];
}

sub queue_to_string {
    my ($self, %options) = @_;

    my $colored = exists $options{colored} ? $options{colored} : $self->{colored};

    [
        map {
            $colored ? colored($_->to_string(), $_->{severity}->color()) : $_->to_string();
        } @{$self->queue()}
    ];
}

sub queue_to_syslog {
    my $self = shift;

    [
        map {
            $_->to_syslog();
        } @{$self->queue()}
    ];
}

sub say_queue {
    my ($self, %options) = @_;

    my $queue_to_string = $self->queue_to_string(%options);

    say join "\n", @{$queue_to_string} if @{$queue_to_string};

    $self;
}

sub push_in_queue {
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

    push @{$self->{queue}}, $options{message};

    $self;
}

sub clear_queue {
    my $self = shift;

    undef @{$self->{queue}};

    $self;
}

sub async_open {
    my ($self, %options) = @_;

    unless (blessed($self->{aio_filehandle})) {
        local $!;

        aio_open($self->{file_path}, AnyEvent::IO::O_CREAT | AnyEvent::IO::O_WRONLY | AnyEvent::IO::O_APPEND, 0666, sub {
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
    my ($self, %options) = @_;

    aio_close($self->{aio_filehandle}, $options{callback} eq 'CODE' ? $options{callback} : sub {}) if blessed($self->{aio_filehandle});

    undef $self->{aio_filehandle};

    $self;
}

sub flush_queue {
    my ($self, %options) = @_;

    if ($self->{syslog}) {
        local $@;

        for (@{$self->queue_to_syslog()}) {
            eval {
                syslog(@{$_});
            };
        }
    } elsif (defined $self->{file_path}) {
        my $queue_to_string = $self->queue_to_string(
            colored => 0
        );

        if (@{$queue_to_string}) {
            if ($options{async}) {
                $self->async_open(
                    on_success => sub {
                        aio_write(shift, (join "\n", @{$queue_to_string}) . "\n", sub {
                        });
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
                            } @{$queue_to_string}
                        ]
                    );
                };
            }
        }
    } else {
        $self->say_queue();
    }

    $self->clear_queue();
}

BEGIN {
    no strict 'refs';

    for my $severity (@{Navel::Logger::Message::Severity->severities()}) {
        *{__PACKAGE__ . '::' . $severity} = sub {
            shift->push_in_queue(
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

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-logger is licensed under the Apache License, Version 2.0

=cut
