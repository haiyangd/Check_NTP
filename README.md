# Check_NTP.sh - Troubleshoot NTP

A script to run some basic checks on a NTP client setup.

* runs ntpstat to check clock synchronisation

* checks that the configured peers can be contacted

* get a list of contacted peers

NOTE: assumes an already configured set up.

## Dependencies

Bash > 4.3
NTP > 4.2

Though will probably work on older versions

## Installation

No specific installation requirements. Download the script & run.

## How to run

Requires root privileges, so either as root:
	./Check_NTP.sh

or as an ordinary user:
	sudo ./Check_NTP.sh

See: https://blog.steel-eyed.com/troubleshooting-ntp/
