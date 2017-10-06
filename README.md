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

```
define command {
        command_name    handler-glpi-host-ticket
        command_line    /usr/bin/perl /usr/local/lib/nagios/event-handlers/glpi-9.1/ticket-host.pl >> /tmp/ticket-host.log
}

define command {
        command_name    handler-glpi-service-ticket
        command_line    /usr/bin/perl /usr/local/lib/nagios/event-handlers/glpi-9.1/ticket-service.pl >> /tmp/ticket-service.log
}
```



Icinga2
-------

```

/** a dummy contact for ticket issuing */
object User "glpi" {
  display_name = "GLPI(ticket)"
  enable_notifications = true
  states = [ Up, Down, OK, Critical ]
  types = [ Problem, Recovery ]
}

object NotificationCommand "host-glpi-ticket-handler" {
  import "plugin-notification-command"

  command = [ SysconfDir + "/icinga2/scripts/ticket-host.pl" ]

  env = {
    NOTIFICATIONTYPE = "$notification.type$"
    HOSTALIAS = "$host.display_name$"
    HOSTADDRESS = "$address$"
    HOSTSTATE = "$host.state$"
    LONGDATETIME = "$icinga.long_date_time$"
    HOSTOUTPUT = "$host.output$"
    NOTIFICATIONAUTHORNAME = "$notification.author$"
    NOTIFICATIONCOMMENT = "$notification.comment$"
    HOSTDISPLAYNAME = "$host.display_name$"
    USEREMAIL = "$user.email$"
  }
}

object NotificationCommand "service-glpi-ticket-handler" {
  import "plugin-notification-command"

  command = [ SysconfDir + "/icinga2/scripts/ticket-service.pl" ]

  env = {
    NOTIFICATIONTYPE = "$notification.type$"
    SERVICEDESC = "$service.name$"
    HOSTALIAS = "$host.display_name$"
    HOSTADDRESS = "$address$"
    SERVICESTATE = "$service.state$"
    LONGDATETIME = "$icinga.long_date_time$"
    SERVICEOUTPUT = "$service.output$"
    LONGSERVICEOUTPUT = "$service.output$"
    NOTIFICATIONAUTHORNAME = "$notification.author$"
    NOTIFICATIONCOMMENT = "$notification.comment$"
    HOSTDISPLAYNAME = "$host.display_name$"
    SERVICEDISPLAYNAME = "$service.display_name$"
    USEREMAIL = "$user.email$"
  }
}

apply Notification "host-glpi-ticket" to Host {

  //this is a dummy user, with no other notifications setup
  users = [ "glpi" ]
  period = "24x7"
  command = "host-glpi-ticket-handler"
  // don't repeat ticket creation for the same problem
  interval = 0

  // notify about all hosts with exceptions
  assign where host.address
  ignore where host.vars.no_glpi_tickets
}

apply Notification "service-glpi-ticket" to Service {

  //this is a dummy user, with no other notifications setup
  users = [ "glpi" ]
  period = "24x7"
  command = "service-glpi-ticket-handler"

  // don't repeat ticket creation for the same problem
  interval = 0

  // notify about all services with exceptions
  assign where service.name
  ignore where service.vars.no_glpi_tickets
  ignore where host.vars.no_glpi_tickets
}

```

Script location is arbitrary. Make sure the perl dependencies are installed.


Edit the scripts configuration section to reflect your GLPI setup and access keys. Hopefully it should work.



