# Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-logger is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

package Navel::Logger::Message::Facility::Local 0.1;

use Navel::Base;

#-> class variables

my %facilities = (
    'local0' => 16,
    'local1' => 17,
    'local2' => 18,
    'local3' => 19,
    'local4' => 20,
    'local5' => 21,
    'local6' => 22,
    'local7' => 23
);

#-> methods

sub facilities {
    [
        keys %facilities
    ];
}

sub new {
    my ($class, $label) = @_;

    die "label must be defined\n" unless defined $label;

    $label = lc $label;

    die "facility is invalid\n" unless exists $facilities{$label};

    bless {
        label => $label
    }, ref $class || $class;
}

sub value {
    $facilities{shift->{label}};
}

# sub AUTOLOAD {}

# sub DESTROY {}

1;

#-> END

__END__

=pod

=encoding utf8

=head1 NAME

Navel::Logger::Message::Facility::Local

=head1 COPYRIGHT

Copyright (C) 2015 Yoann Le Garff, Nicolas Boquet and Yann Le Bras

=head1 LICENSE

navel-logger is licensed under the Apache License, Version 2.0

=cut
