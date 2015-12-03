#!/usr/bin/env bash

# Copyright (c) 2015 Sean Steppie.  All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Name:         Check_NTP.sh
# Author:       developer ( at ) steel-eyed.com
# Description:  Various tests to ensure that NTP is running correctly on a client.
# Dependencies: Bash > 4.3
#               NTP > 4.2
#
# Revision History:
# 2015-12-01    1.0.0   Initial Version.
#
# NOTES:
# As per the above warranty, I do not guarantee that this script is of any
# practical use - use at your own discretion.
#
# See the Troubleshooting section from the ntp website:
#   http://support.ntp.org/bin/view/Support/TroubleshootingNTP
#
# This script assumes an already configured setup & can be used to check that
# everything is working as it should be.
#
# When troubleshooting ntpd problems, remember that any firewalls you have
# should be configured to allow unrestricted access to UDP port 123 in both
# directions.
#
# ntpdate and ntpd use unprivileged, high port numbers so you may be able to
# query with these utilities but ntpd may still not work if the firewall
# configuration has not been done.
#

# Location of ntp.conf - used to get peers servers
NTP_CONF=/etc/ntp.conf

# ISINIT/ISSYSTEMD - 0 for false, 1 for true. Only one should be set as true.
# If both are 0, then check_init() will be run to try to work out which is
# running.
ISINIT=0
ISSYSTEMD=0

# Will try to use init scripts or systemd to check if ntpd is running, so will
# check which of there are running to try to work what type of commands to run.
# If either ISINIT or ISSYSTEMD is set to 1, then these won't be used.
INIT=/sbin/init
SYSTEMD=/usr/lib/systemd/systemd

# Will be set if ntpd is running.
ISRUNNING=-1

# Check if init or systemd is running.
check_init() {
    pidof $INIT > /dev/null 2>&1
    if [ $? -eq 1 ]; then
        pidof $SYSTEMD > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            ISSYSTEMD=1
        else
            printf "Cannot tell system type is init or systemd"
        fi
    else
        ISINIT=1
    fi
}

# Check if ntpd is running via init script or systemd
check_running() {
    if [  $ISINIT -eq 0 -a  $ISSYSTEMD -eq 0 ]; then
        check_init
    fi

    if [ $ISINIT -eq 1 ]; then
        service ntpd status > /dev/null 2>&1
    elif [ $ISSYSTEMD -eq 1 ]; then
        systemctl status ntpd > /dev/null 2>&1
    fi

    if [ $? -eq 0 ];  then
        ISRUNNING=1
    else
        ISRUNNING=0
        printf "ntpd not running\n"
    fi
}

# Counts the number of peers visible.
peer_count() {
    ERR_FILE="/tmp/peers_$$"
    COUNT=$( ntpq -pn 2> $ERR_FILE | grep -E ^.\([0-9]\+\.\){4} | wc -l )

    # if $ERR_FILE is not empty then we have an error.
    if [ -s $ERR_FILE ]; then
        printf "Can't get peers list: $(cat $ERR_FILE)\n"
    else
        printf "Number of peers = $COUNT\n"
    fi
    remove_files $ERR_FILE
}

# Deletes any files passed.
remove_files() {
    rm -f $@ > /dev/null 2>&1
}

# Run ntpstat and outputs an appropriate message based on the the return status.
ntpstatus() {
    ntpstat > /dev/null 2>&1
    RETVAL=$?
    case $RETVAL in
    0)
        printf "Clock is synchronised.\n"
        ;;
    1)
        printf "Clock is not synchronised.\n"
        ;;
    2)
        printf "State is indeterminant.\n"
        ;;
    3)
        printf "Got an unexpected exit status: $RETVAL\n"
        ;;
    esac
}

# Get configured peers and attempt to contact them.
check_peers() {
    SERVERS=""
    if [ -e ${NTP_CONF} ]; then
        SERVERS=$(grep ^server $NTP_CONF | awk '{print $2}' )
    else
        printf "$NTP_CONF: doesn't exist.\n"
        return
    fi

    missing=""
    SUCCESS=0
    TOTAL=0
    for server in ${SERVERS}; do
         TOTAL=$((TOTAL+1))
         ntpdate -q $server > /dev/null 2>&1
         if [ $? -eq 0 ]; then
            SUCCESS=$((SUCCESS+1))
         else
            missing="$server $missing"
         fi
    done
    printf "Connected to $SUCCESS servers out of a total of $TOTAL\n"
    if [ "$missing" != "" ]; then
        printf "Cannot connect to: $missing\n"
    fi
}

get_variables() {
    ERR_FILE="/tmp/values_$$"
    VARS="version stratum offset"
    for var in $VARS; do
        result=$( ntpq -c "readvar 0 $var" 2> $ERR_FILE )
        if [ -s $ERR_FILE ]; then
            printf "Got error: $(cat $ERR_FILE) while trying to contact ntpd\n"
            break
        fi
        if [ -z "$result" ]; then
            print "Got no result when trying to get: $item"
            next
        fi
        value=$(echo $result | sed "s/^[^=]\+=//")
        printf "$var: $value\n"
    done
}

# Main
check_running
if [ $ISRUNNING -eq 1 ]; then
    printf "ntpd seems to be running, running checks.\n"
    printf "\nntpstat\n=======\n"
    ntpstatus
    printf "\nCheck Peers\n=============\n( may take some time )\n"
    check_peers
    printf "\nPeer Count\n==========\n"
    peer_count
    printf "\nVariables\n"
    get_variables
fi
