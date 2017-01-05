# glpi-icinga
Glpi script to register/close tickets based on icinga/nagios/icinga2 alerts. Designed to work with new api of GLPI 9.1+




Setup
=====
define a user in glpi that can make and close tickets. Assign him an API key (user_token)

in global GLPI options enable the API and generate API Access entry for your monitoring host ip and also generate a key for it (app_token).


You can quickly verify that with login.sh script. It should generate a session key for you.




Nagios/Icinga1
--------------

Define commands (you can pass more args to the scripts) in commands.cfg


define command {
        command_name    handler-glpi-host-ticket
        command_line    /usr/bin/perl /usr/local/lib/nagios/event-handlers/glpi-9.1/ticket-host.pl lasthoststate="$LASTHOSTSTATE$" hoststate="$HOSTSTATE$" state="$HOSTSTATETYPE$" eventhost="$HOSTNAME$" hostattempts="$HOSTATTEMPT$" maxhostattempts="$MAXHOSTATTEMPTS$" hostproblemid="$ HOSTPROBLEMID$" lasthostproblemid="$LASTHOSTPROBLEMID$" hoststatetype="$HOSTSTATETYPE$" >> /tmp/ticket-host.log
}

define command {
        command_name    handler-glpi-service-ticket
        command_line    /usr/bin/perl /usr/local/lib/nagios/event-handlers/glpi-9.1/ticket-service.pl event="$SERVICESTATE$" state="$SERVICESTATETYPE$" hoststate="$HOSTSTATE$" eventhost="$HOSTNAME$" service="$SERVICEDESC$" serviceattempts=" $SERVICEATTEMPT$" maxserviceattempts="$MAXSERVICEATTEMPTS$" servicestate="$SERVICESTATE$" lastservicestate="$LASTSERVICESTATE$" serviceoutput="$SERVICEOUTPUT$" servicestatetype="$SERVICESTATETYPE$" longserviceoutput="$LONGSERVICEOUTPUT$" >> /tmp/ticket-service.log
}



Script location is arbitrary.


Edit the scripts configuration section to reflect your GLPI setup and access keys. Hopefully it should work.



