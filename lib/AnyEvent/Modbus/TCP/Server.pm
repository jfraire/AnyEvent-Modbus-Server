package AnyEvent::Modbus::TCP::Server;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Role::Tiny::With;

use Device::Modbus::Request;
use Device::Modbus::Response;
use Device::Modbus::Exception;
use Device::Modbus::TCP::ADU;

use v5.10;
use strict;
use warnings;

use parent('AnyEvent::Modbus::Server');
with 'Device::Modbus::TCP';

sub new {
    my ($class, %args) = @_;

    # Default values
    $args{host} //= '127.0.0.1';
    $args{port} //= 502;

    bless {%{$class->proto()}, %args}, $class;
}

sub host {
    my $self = shift;
    $self->{host} = shift if @_;
    return $self->{host};
}

sub port {
    my $self = shift;
    $self->{port} = shift if @_;
    return $self->{port};
}

sub start {
    my $self  = shift;
    my $guard; $guard = tcp_server( $self->host, $self->port, sub {
        my ($fh, $host, $port) = @_;
        # If the file handle is not defined, there is a problem
        if (!defined $fh) {
            AE::log error => "Could not start server: $!";
            return;
        }

        my $handle; $handle = AnyEvent::Handle->new(
            fh        => $fh,
            keepalive => 1,
            on_read   => sub {
                my $handle = shift;
                $self->process_request($handle);
            },
            on_eof   => sub {
                AE::log info => "Client disconnected";
                $handle->destroy;
            },
            on_error => sub {
                my ($handle, $fatal, $msg) = @_;
                AE::log error => $msg;
                $handle->destroy;
                undef $guard;
            },
        );        
    });
    return $guard;
}

# Return exception if unit is not supported by server
sub request_for_others {
    my ($self, $adu) = @_;
    return Device::Modbus::Exception->new(
            function       => $Device::Modbus::function_for{$adu->code},
            exception_code => 2,
            unit           => $adu->unit
    );
}

1;
