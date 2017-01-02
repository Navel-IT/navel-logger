# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-logger is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Logger::Message 0.1;

use Navel::Base;

use Navel::Logger::Message::Facility::Local;
use Navel::Logger::Message::Severity;
use Navel::Utils qw/
    flatten
    isint
    strftime
/;

#-> methods

sub stepped_message {
    my $class = shift;

    my $stepped_message = '';

    for (@_) {
        my $shift = 0;

        my @data;

        if (ref eq 'ARRAY') {
             $shift = 4;

             @data = flatten($_);
        } else {
             @data = ($_);
        }

        if (@data = grep { defined } @data) {
            $stepped_message .= ((defined $stepped_message ? '' : "\n") . join "\n", map {
                (' ' x $shift) . $_
            } @data) . "\n";
        }
    }

    chomp $stepped_message;

    $stepped_message;
}

sub new {
    my ($class, %options) = @_;

    my $self = bless {
        text => $options{text},
        time => $options{time},
        datetime_format => $options{datetime_format},
        hostname => $options{hostname},
        service => $options{service},
        service_pid => $options{service_pid}
    }, ref $class || $class;

    $self->set_facility($options{facility})->set_severity($options{severity});
}

sub set_facility {
    my $self = shift;

    $self->{facility} = Navel::Logger::Message::Facility::Local->new(shift);

    $self;
}

sub set_severity {
    my $self = shift;

    $self->{severity} = Navel::Logger::Message::Severity->new(shift);

    $self;
}

sub priority {
    my $self = shift;

    $self->{facility}->value * 8 + $self->{severity}->value;
}

sub prepare_properties {
    my $self = shift;

    $self->{hostname} =~ s/\s//g if defined $self->{hostname};
    $self->{service} =~ s/\s//g if defined $self->{service};

    $self;
}

sub constructor_properties {
    my $self = shift;

    return {
        %{$self},
        %{
            {
                facility => $self->{facility}->{label},
                severity => $self->{severity}->{label}
            }
        }
    };
}

sub to_string {
    my $self = shift->prepare_properties;

    (isint($self->{time}) && length $self->{datetime_format} ? strftime($self->{datetime_format}, (localtime $self->{time})) . ' ' : '') . (length $self->{hostname} ? $self->{hostname} . ' ' : '') . (length $self->{service} ? $self->{service} . (isint($self->{service_pid}) > 0 ? '[' . $self->{service_pid} . ']' : '') : '') . ' ' . $self->priority . ' ' . ($self->{text} // '');
}

sub to_syslog {
    my $self = shift->prepare_properties;

    [
        $self->{facility}->{label} . '|' . $self->{severity}->{label},
        '%s',
        $self->{text} // ''
    ];
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Logger::Message

=head1 DESCRIPTION

The messsage format follow the specification provided by the RFC 3164

=head1 COPYRIGHT

Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-logger is licensed under the Apache License, Version 2.0

=cut
