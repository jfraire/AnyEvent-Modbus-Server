#! /usr/bin/env perl

use lib 't/lib';
use Device::Modbus::TCP::Client;
use AnyEvent::Log;
use Test::More tests => 12;
use strict;
use warnings;

BEGIN {
    use_ok 'AnyEvent::Modbus::TCP::Server';
    use_ok 'Test::AllRequests';
}

# Fork. Child builds a server who dies after a couple of seconds
$|++;
my $pid = fork;
unless (defined $pid && $pid) {
    # We are the child. Start a server.
    # Send an alarm signal in two seconds.
    $AnyEvent::Log::FILTER->level("fatal");
    alarm(2);
    my $unit = Test::AllRequests->new( id => 3 );

    my $server = AnyEvent::Modbus::TCP::Server->new(
        port => 6545,
    );
    $server->add_server_unit($unit);

    # Just wait for the server to stop
    my $cv = AnyEvent->condvar;
    my $guard = $server->start;

    my $exit = AnyEvent->signal(
        signal => 'ALRM',
        cb     => sub {
            undef $guard;
            $cv->send;
        }
    );

    $cv->recv;
    exit 0;
}

# The parent is the client. Send requests and evaluate responses.
note "Test forked, and server started on PID $pid";

my $client = Device::Modbus::TCP::Client->new( port => 6545 );

my @tests = ([
        $client->read_coils(
            unit     => 3,
            address  => 19,
            quantity => 19
        ),
        Device::Modbus::Response->new(
            function => 'Read Coils',
            values   => [1,0,1,1,0,0,1,1,   1,1,0,1,0,1,1,0,  1,0,1]
        ),
    ],
    [
        $client->read_discrete_inputs(
            unit     => 3,
            address  => 196,
            quantity => 19
        ),
        Device::Modbus::Response->new(
            function => 'Read Discrete Inputs',
            values   => [0,0,1,1,0,1,0,1,  1,1,0,1,1,0,1,1,  1,0,1]
        ),
    ],
    [
        $client->read_holding_registers(
            unit     => 3,
            address  => 107,
            quantity => 3
        ),
        my $response = Device::Modbus::Response->new(
            function => 'Read Holding Registers',
            values   => [0x022b, 0x0000, 0x0064]
        ),
    ],
    [
        $client->read_input_registers(
            unit     => 3,
            address  => 8,
            quantity => 4
        ),
        Device::Modbus::Response->new(
            function => 'Read Input Registers',
            values   => [ 0x000a, 0x000b, 0x000c, 0x000d ]
        ),
    ],
    [
        $client->write_single_coil(
            unit     => 3,
            address  => 172,
            value    => 1
        ),
        Device::Modbus::Response->new(
            function => 'Write Single Coil',
            address  => 172,
            value    => 1
        ),
    ],
    [
        $client->write_single_coil(
            unit     => 3,
            address  => 172,
            value    => 0
        ),
        Device::Modbus::Response->new(
            function => 'Write Single Coil',
            address  => 172,
            value    => 0
        )
    ],
    [
        $client->write_single_register(
            unit     => 3,
            address  => 1,
            value    => 0x03
        ),
        Device::Modbus::Response->new(
            function => 'Write Single Register',
            address  => 1,
            value    => 0x03
        ),
    ],
    [
        $client->write_multiple_coils(
            unit     => 3,
            address  => 19,
            values   => [1,0,1,1,0,0,1,1,1,0]
        ),
        Device::Modbus::Response->new(
            function => 'Write Multiple Coils',
            address  => 19,
            quantity => 10
        ),
    ],
    [
        $client->write_multiple_registers(
            unit     => 3,
            address  => 1,
            values   => [0x000A, 0x0102]
        ),
        Device::Modbus::Response->new(
            function => 'Write Multiple Registers',
            address  => 1,
            quantity => 2
        ),
    ],
);


sleep 1;

foreach my $test (@tests) {
    my ($req, $res) = @$test;

    my $function = $req->{code};
    $client->send_request($req);
    my $adu = $client->receive_response;
#    note explain $adu;
    is $adu->code, $function,
        "The response for code $function is correct";
}

$client->disconnect;
is wait(), $pid, "Waited for child whose pid was $pid" ;

done_testing();
