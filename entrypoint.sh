#!/bin/bash
set -e

# Initialize nagios configuration if mounted empty
if [ ! -f "/opt/nagios/etc/nagios.cfg" ]; then
    echo "First run detected, initializing Nagios configuration..."
    mkdir -p /opt/nagios/etc
    cp -r /opt/nagios.template/etc/* /opt/nagios/etc/
fi

# Start supervisord
exec "$@" 