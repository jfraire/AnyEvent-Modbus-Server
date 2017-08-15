#! /usr/bin/env perl

use Test::More tests => 7;
use strict;
use warnings;
use v5.10;

use_ok 'AnyEvent::Modbus::TCP::Server';

my $server = AnyEvent::Modbus::TCP::Server->new;
is $server->host, '127.0.0.1',
    'Host accessor works and defaults to 127.0.0.1';
$server->host('Hola Crayola');
is $server->host, 'Hola Crayola',
    'Host mutator works';
is $server->port, 502,
    'Port accessor works and defaults to 502';
$server->port('Le Havre');
is $server->port, 'Le Havre',
    'Port can be changed';
    
isa_ok $server, 'AnyEvent::Modbus::Server';
isa_ok $server, 'Device::Modbus::Server';

done_testing();
