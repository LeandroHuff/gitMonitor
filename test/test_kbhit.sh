#!/usr/bin/env bash
source libShell.sh || exit 1
libInit -v -g -l 1 || exit 1
logBegin || exit 1
function logI() { echo -e "\033[37minfo:\033[0m $*" ; }
logI "Press key [q or Q] to exit from program."
while true
do
    key=$(kbHit)
    if  [ "$key" = 'q' ] || [ "$key" = 'Q' ]
    then
        logI "Key=$key"
        break
    fi
    sleep 0.1
done
logEnd
libStop
exit 0
