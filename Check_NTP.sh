#!/usr/bin/env bash

# Various tests to ensure that NTP is running correctly on a client.

peer_count() {
    ERR_FILE="/tmp/peers_$$"
    COUNT=$( ntpq -pn 2> $ERR_FILE | grep -E ^.\([0-9]\+\.\){4} | wc -l )

    # if $ERR_FILE is not empty then we have an error.
    if [ -s $ERR_FILE ]; then
        printf "Can't get peers list: $(cat $ERR_FILE)\n"
    else
        printf "Number of peers = $COUNT\n"
    fi
    #remove_files $ERR_FILE
}

remove_files() {
    rm -f $@ 2>&1 > /dev/null
}

ntpstatus() {
    ntpstat 2>&1 > /dev/null
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

ntpstatus
peer_count
