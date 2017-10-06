#!/bin/sh



if [ $# -lt 3 ] ; then
    echo "$0 host state oldstate"
    echo "e..g $0 server01 DOWN UP to make a ticket"
    echo "$0 server01 UP DOWN to close open tickets"
    exit 1
fi

export HOSTALIAS=$1
export HOSTSTATE=$2
export LASTHOSTSTATE=$3
export HOSTSTATETYPE="HARD"
export HOSTATTEMPT=5
export MAXHOSTATTEMPTS=5
export HOSTADDRESS="1.2.3.4" # this will be used to link new tickets against server in glpi with that IP address

./ticket-host.pl 
