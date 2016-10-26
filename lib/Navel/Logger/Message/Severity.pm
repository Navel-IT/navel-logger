# Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-logger is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Logger::Message::Severity 0.1;

use Navel::Base;

use Navel::Utils qw/
    croak
    blessed
/;

#-> class variables

our %SEVERITIES = (
    emerg => {
        value => 0,
        color => 'magenta'
    },
    alert => {
        value => 1,
        color => 'red'
    },
    crit => {
        value => 2,
        color => 'red'
    },
    err => {
        value => 3,
        color => 'red'
    },
    warning => {
        value => 4,
        color => 'yellow'
    },
    notice => {
        value => 5,
        color => 'white'
    },
    info => {
        value => 6,
        color => 'green'
    },
    debug => {
        value => 7,
        color => 'cyan'
    }
);

#-> methods

sub new {
    my ($class, $label) = @_;

    die "label must be defined\n" unless defined $label;

    $label = lc $label;

    die "severity is invalid\n" unless exists $SEVERITIES{$label};

    bless {
        label => $label
    }, ref $class || $class;
}

sub value {
    $SEVERITIES{shift->{label}}->{value};
}

sub color {
    $SEVERITIES{shift->{label}}->{color};
}

sub compare {
    my ($self, $severity) = @_;

    croak('severity must be of ' . __PACKAGE__ . ' class') unless blessed($severity) && $severity->isa(__PACKAGE__);

    $self->value >= $severity->value;
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Logger::Message::Severity

=head1 COPYRIGHT

Copyright (C) 2015-2016 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-logger is licensed under the Apache License, Version 2.0

=cut
