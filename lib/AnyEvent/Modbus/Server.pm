package AnyEvent::Modbus::Server;

use AnyEvent;
use AnyEvent::Handle;

use Device::Modbus::TCP::ADU;
use Device::Modbus::Request;
use Device::Modbus::Response;
use Device::Modbus::Exception;

use v5.10;
use strict;
use warnings;

use parent('Device::Modbus::Server');

our $VERSION = '0.01';

# Called when there is a new request
sub process_request {
    my ($self, $handle) = @_;

    # Two reads have to be made. First we read the header and then,
    # we read the body of the request.
    $handle->unshift_read( chunk => 8, sub {
        my ($handle, $data) = @_;

        # Read header
        my ($id, $proto, $length, $unit, $code) = unpack 'nnnCC', $data;
        my $request;
        my $adu_req = Device::Modbus::TCP::ADU->new(
            id      => $id,
            unit    => $unit,
        );

        # This routine is common for all requests.
        # It is called when the request has been parsed, at the end of the
        # second reading.
        my $process_request = sub {
            my $handle = shift;
            $adu_req->message($request);

            # Process the request
            my $response = $self->modbus_server($adu_req);

            # Build the response ADU
            my $adu = Device::Modbus::TCP::ADU->new(
                id      => $id,
                unit    => $unit,
                message => $response
            );

            # Send the response to the client
            $handle->push_write($adu->binary_message);
        };

        # Read the rest of the incoming ADU to parse the request.
        # We read $length-2 because length includes unit and code bytes.
        $handle->unshift_read(chunk => $length - 2, sub {
            if (grep { $code == $_ } (0x01, 0x02, 0x03, 0x04)) {
                # Read coils, discrete inputs, holding registers, input registers
                my ($address, $quantity) = unpack 'nn', $_[1];
                $request = Device::Modbus::Request->new(
                    code       => $code,
                    address    => $address,
                    quantity   => $quantity
                );
            }
            elsif (grep { $code == $_ } (0x05, 0x06)) {
                # Write single coil and single register
                my ($address, $value) = unpack 'nn', $_[1];
                if ($code == 0x05 && $value != 0xFF00 && $value != 0) {
                    $request = Device::Modbus::Exception->new(
                        code           => $code + 0x80,
                        exception_code => 3
                    );
                }
                else {
                    $request = Device::Modbus::Request->new(
                        code       => $code,
                        address    => $address,
                        value      => $value
                    );
                }
            }
            elsif ($code == 0x0F) {
                # Write multiple coils
                my ($address, $qty, $bytes) = unpack 'nnC', $_[1];
                my $bytes_qty = $qty % 8 ? int($qty/8) + 1 : $qty/8;
                if ($bytes == $bytes_qty) {
                    $_[0]->unshift_read( chunk => $bytes_qty, sub {
                        my @values = unpack 'C*', $_[1];
                        @values    = Device::Modbus->explode_bit_values(@values);

                        $request = Device::Modbus::Request->new(
                            code       => $code,
                            address    => $address,
                            quantity   => $qty,
                            bytes      => $bytes,
                            values     => \@values
                        );
                    });
                }
                else {
                    $request = Device::Modbus::Exception->new(
                        code           => $code + 0x80,
                        exception_code => 3
                    );
                }
            }
            elsif ($code == 0x10) {
                # Write multiple registers
                my ($address, $qty, $bytes) = unpack 'nnC', $_[1];
                if ($bytes == 2 * $qty) {
                    $_[0]->unshift_read(chunk => $bytes, sub {
                        my (@values) = unpack 'n*', $_[1];

                        $request = Device::Modbus::Request->new(
                            code       => $code,
                            address    => $address,
                            quantity   => $qty,
                            bytes      => $bytes,
                            values     => \@values
                        );
                    });
                }
                else {
                    $request = Device::Modbus::Exception->new(
                        code           => $code + 0x80,
                        exception_code => 3
                    );
                }
            }
            elsif ($code == 0x17) {
                # Read/Write multiple registers
                my ($read_addr, $read_qty, $write_addr, $write_qty, $bytes)
                    = unpack 'nnnnC', $_[1];

                if ($bytes == 2 * $write_qty) {
                    $_[0]->unshift_read( chunk => $bytes, sub {
                        my (@values) = $self->parse_buffer($bytes, 'n*');

                        $request = Device::Modbus::Request->new(
                            code           => $code,
                            read_address   => $read_addr,
                            read_quantity  => $read_qty,
                            write_address  => $write_addr,
                            write_quantity => $write_qty,
                            bytes          => $bytes,
                            values         => \@values
                        );
                    });
                }
                else {
                    $request = Device::Modbus::Exception->new(
                        code           => $code + 0x80,
                        exception_code => 3
                    );
                }
            }
            else {
                # Unimplemented function
                $request = Device::Modbus::Exception->new(
                    code           => $code + 0x80,
                    exception_code => 1,
                );
            }

            # Process the request. $_[0] is the handle; $process_request
            # is the code ref built above and it includes the $request
            # object already.
            $process_request->($_[0]);
        });
    });
}

sub log {
    my ($self, $level, $msg) = @_;
    AE::log $level => $msg;
}

1;

=pod

=head1 NAME

AnyEvent::Modbus::Server - An asynchronous MODBUS server implementation

=head1 SYNOPSIS

 use Device::Modbus::AnyEvent::TCP::Server;
 use Application::Unit;
 use strict;
 use warnings;

 my $server = Device::Modbus::AnyEvent::TCP::Server->new(
    host => '127.0.0.1',
    port => 8765,
 );

 my $unit = Application::Unit->new(id => 1);
 $server->add_server_unit($unit);

 my $cv = AnyEvent->condvar;

 my $guard = $server->start;

 my $exit = AnyEvent->signal(
    signal => 'INT',
    cb     => sub {
        undef $guard;
        $cv->send;
    }
 );

 $cv->recv;

=head1 DESCRIPTION

This distribution proposes an asynchronous MODBUS TCP server built on top of L<Device::Modbus::Server> and L<AnyEvent>. The unit-based interface has been kept.

For a proper explanation of the server, please refer to L<Device::Modbus::Server>. This document will discuss only the constructor of the asynchronous Modbus TCP. As of this writing, the asynchronous RTU version has not been developed.

=head1 MODBUS TCP SERVER

=head2 Constructor

The server is built on the C<tcp_server> proposed by L<AnyEvent::Socket>, and it only supports two attributes: C<host> and C<port>:

 my $server = Device::Modbus::AnyEvent::TCP::Server->new(
   host => '10.10.0.53', # Default is 127.0.0.1
   port => 8765,         # Default is 502
 );

Just like attributes, the server has only a few methods. Please see L<Device::Modbus::Server> for a discussion on how they all fit together.

=head2 Adding a Server Unit

As you can see in the synopsis, after instantiating the server you must define at least one server unit. A server unit is a class that specifies the functionality of the server. It is a mapping between client requests and server-side work.

 my $unit = Application::Unit->new( id => 33 );
 $server->add_server_unit( $unit );

All there is left to do is to launch the server.

=head2 Starting the server

 This is as simple as calling the start method. It will return a I<guard> object whose life is tied to that of the server. The server will be stopped if this object is destroyed.

 my $guard = $server->start;

And that is it, your MODBUS server should be listening in the required port.

=head1 SEE ALSO

L<Device::Modbus>, L<Device::Modbus::Server>, L<AnyEvent>, L<AnyEvent::Socket>.

=head1 LICENSE

Please refer to the LICENSE file you received with this distribution.

=cut
