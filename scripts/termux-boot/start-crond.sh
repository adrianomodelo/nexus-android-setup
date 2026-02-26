#!/data/data/com.termux/files/usr/bin/bash
# Esperar Termux iniciar (start-sshd.sh cuida disso)
sleep 15
pgrep -x crond > /dev/null || crond
