#! /usr/bin/perl

use lib 't/lib';
use Device::Modbus::TCP::Client;
use AnyEvent::Log;
use Test::More tests => 12;
use strict;
use warnings;

BEGIN {
    use_ok 'AnyEvent::Modbus::TCP::Server';
    use_ok 'Test::Unit';
}

# Fork. Child builds a server who dies after a couple of seconds
$|++;
my $pid = fork;
unless (defined $pid && $pid) {
    # We are the child. Start a server.
    # Send an alarm signal in two seconds.
    alarm(2);
    my $unit   = Test::Unit->new( id => 3 );

    my $server = AnyEvent::Modbus::TCP::Server->new(
        port              => 6545,
    );
    $server->add_server_unit($unit);

    # Configure AE::Logging
    my $fname = "/tmp/test_server_$$";
#    diag "Logging to $fname";
    $AnyEvent::Log::LOG->log_to_file($fname);
    $AnyEvent::Log::FILTER->level("trace");

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
ok $pid, "Test forked, and server started on PID $pid";

my $client = Device::Modbus::TCP::Client->new( port => 6545 );
isa_ok $client, 'Device::Modbus::Client';

my $req = $client->read_holding_registers(
    unit     => 3,
    address  => 2,
    quantity => 1
);
isa_ok $req, 'Device::Modbus::Request';

sleep 1;

$client->send_request($req);

my $adu = $client->receive_response;

isa_ok $adu, 'Device::Modbus::TCP::ADU';
is_deeply $adu->values, [6], 'Value returned from server is correct';
$client->disconnect;


is wait(), $pid, "Waited for child whose pid was $pid" ;

# Now check the log of the server. Pull everything into a variable
my $log;
{
    local $/  = undef;
    my $fname = "/tmp/test_server_$pid";
    open my $server_log, '<', $fname
        or die "Unable to open log file $fname: $!";
    $log = <$server_log>;
    close $server_log;
}

like $log, qr/<holding_registers> address: <2> quantity: <1>/,
    'Message interpreted correctly';
like $log, qr/Match was successful/s,
    'Match succeeded';
like $log, qr/Executed server routine/s,
    'Execution succeeded';
like $log, qr/Client disconnected/s,
    'Client disconnected';

done_testing();
