package Test::Simple;

use strict;
use warnings;
extends 'Device::Modbus::Unit';

# Called when object is added to server
sub init_unit {
    my $unit = shift;
    #----------     Area    -------| Addr | Qty | Routine -----
    $unit->get('holding_registers',  '25',  '3', 'read_hr');
}

# Request handler
sub read_hr {
    my ($unit, $server, $req, $addr, $qty) = @_;
    return (1,2,3);
}

1;
