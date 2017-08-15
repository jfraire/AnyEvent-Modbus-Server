use 5.010;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Device::Modbus::AnyEvent',
    VERSION_FROM      => 'lib/Device/Modbus/AnyEvent.pm', # finds $VERSION
    PREREQ_PM         => {

    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Device/Modbus/AnyEvent.pm', # retrieve abstract from module
       AUTHOR         => 'Julio Fraire <julio.fraire@gmail.com>') : ()),
);
