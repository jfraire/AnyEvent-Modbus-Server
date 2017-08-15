use 5.010;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'AnyEvent::Modbus::Server',
    VERSION_FROM      => 'lib/AnyEvent/Modbus/Server.pm',
    PREREQ_PM         => {
		AnyEvent            => 7.13,
		Device::Modbus      => 0.022,
		Device::Modbus::TCP => 0.025,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/AnyEvent/Modbus/Server.pm',
       AUTHOR         => 'Julio Fraire <julio.fraire@gmail.com>') : ()),
);
