package Test::AllRequests;

use strict;
use warnings;
use parent 'Device::Modbus::Unit';

sub init_unit {
    my $unit = shift;

    #                Zone            addr qty   method
    #           -------------------  ---- ---  ------------------------
    $unit->get('discrete_coils',      19, 19,  'get_coils'            );
    $unit->get('discrete_inputs',    196, 19,  'get_discr_inputs'     );
    $unit->get('holding_registers',  107,  3,  'get_hold_reg'         );
    $unit->get('input_registers',      8,  4,  'get_input_reg'        );
    $unit->put('discrete_coils',     172,  1,  'write_single_coil'    );
    $unit->put('holding_registers',    1,  1,  'write_single_reg'     );
    $unit->put('discrete_coils',      19, 10,  'write_multiple_coils' );
    $unit->put('holding_registers',    1,  2,  'write_multiple_regs'  );
}

sub get_coils {
    my ($unit, $server, $req, $addr, $qty) = @_;
    return (1,0,1,1,0,0,1,1,   1,1,0,1,0,1,1,0,  1,0,1);
}

sub get_discr_inputs {
    my ($unit, $server, $req, $addr, $qty) = @_;
    return (0,0,1,1,0,1,0,1,  1,1,0,1,1,0,1,1,  1,0,1);
}

sub get_hold_reg {
    my ($unit, $server, $req, $addr, $qty) = @_;
    return (0x022b, 0x0000, 0x0064);
}

sub get_input_reg {
    my ($unit, $server, $req, $addr, $qty) = @_;
    return (0x000a, 0x000b, 0x000c, 0x000d);
}

sub write_single_coil {
    my ($unit, $server, $req, $addr, $qty, $val) = @_;
}

sub write_single_reg {
    my ($unit, $server, $req, $addr, $qty, $val) = @_;
}

sub write_multiple_coils {
    my ($unit, $server, $req, $addr, $qty, $val) = @_;
}

sub write_multiple_regs {
    my ($unit, $server, $req, $addr, $qty, $val) = @_;
}

1;
