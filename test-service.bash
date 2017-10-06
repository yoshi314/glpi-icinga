#!/bin/sh

# wygenerowanie ticketu ze usluga $2 na $1 jest critical


if [ $# -lt 4 ] ; then
    echo "$0 host service state oldstate"
    echo "e.g. $0 server01 service01 OK CRITICAL"
    echo "e.g. $0 server01 service01 CRITICAL OK"
    exit 1
fi

export HOSTALIAS=$1
export SERVICEDESC=$2
export SERVICESTATE=$3
export LASTSERVICESTATE=$4
export HOSTSTATE="UP"
export LONGSERVICEOUTPUT="test test test"
export SERVICESTATETYPE="HARD"
export HOSTADDRESS="192.168.16.18" # this ip will be used to find host in glpi and link tickets to it


./ticket-service.pl
