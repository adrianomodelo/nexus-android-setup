#!/data/data/com.termux/files/usr/bin/bash
# Abrir Termux service + activity (necessário para sshd persistir)
# O .bashrc já cuida do auto-start do sshd
am startservice -n com.termux/.app.TermuxService > /dev/null 2>&1
sleep 5
am start -n com.termux/.app.TermuxActivity > /dev/null 2>&1
sleep 5
# Garantir sshd mesmo se .bashrc não executou
pgrep -x sshd > /dev/null || sshd
