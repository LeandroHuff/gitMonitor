#!/usr/bin/env bash

declare -a libLIST=(Config Conn EscCodes File Git Log Math Random Regex Shell String)
declare -a libLOADED=()
declare    libPATH="/var/home/$USER/dev/libShell"
declare    DEBUG=0
declare -i LEN=0
declare -i INDEX=0
declare -a ARGS=()

function logFail() { echo -e "\033[31mfailure\033[0m: $*" ; }
function logDebug() { [ $DEBUG -eq 0 ] || echo -e "\033[32m  debug\033[0m: $*" ; }

function unsetVars()
{
    # Unset Variables
    unset -v libLIST
    unset -v libLOADED
    unset -v listLEN
    unset -v libPATH
    # Unset Functions
    unset -f logFail
    unset -f _help
    unset -f main
    unset -f unsetVars
    unset -f _exit
    return 0
}

function _exit()
{
    local code=$( [ -n "$1" ] && echo $1 || echo 0 )
    logR
    logEnd
    logStop
    LEN=${#libLOADED[@]}
    for ((INDEX=0 ; INDEX < LEN ; INDEX++))
    do
        $(lib${libLOADED[$INDEX]}Exit) || logFail "Unload lib${libLOADED[$INDEX]}.sh"
    done
    unsetVars
    exit $code
}

function main()
{
    local len=0
    local currentBranch=''
    local targetBranch='AutoUpdate'
    local string=''
    local run=true
    local res repository added modified deleted copied renamed tfmodified untracked unmerged commits ignored
    local -a list=(codeTemplate daemons driverLinux gitMonitor libShell makeDoc research researchD setupLinux shellScript shellTools)
    # Setup Libs
    logInit "$@"
    logBegin
    libShellSetup -t 5
    # Internet connecton active intervals.
    local sleepTIME=$((60*30))
    # No internet connection active intervals.
    local sleepNOCONN=$((60*5))
    local counter=5
    local path="/var/home/$USER/dev"
    logI 'Press [Q] or [q] to exit from program.'
    logI '      [U] or [u] to start update.'
    while [ $run ]
    do
        key=$(getChar)
        if [[ "$key" == 'q' || "$key" == 'Q' ]]
        then
            echo
            logD 'Key [Q] or [q] has been pressed, getting out.'
            run=false
            break
        elif [[ "$key" == 'u' || "$key" == 'U' ]]
        then
            echo
            key=''
            logD 'Key [U] or [u] has been pressed, starting update.'
            counter=0
        fi
        if [ $counter -le 0 ]
        then
            echo
            if isConnected
            then
                logD 'Starting update repositories.'
                counter=$sleepTIME
                len=${#list[@]}
                for ((index=0 ; index < $len ; index++))
                do
                    logD "Repository from list: ${list[$index]}"
                    if [ -d "${path}/${list[$index]}" ]
                    then
                        cd "${path}/${list[$index]}"
                        if [ $? -ne 0 ]
                        then
                            logF "Folder ${path}/${list[$index]} not found."
                            break
                        fi
                    fi
                    repository="$(gitRepositoryName)"
                    logD "Repository Name: ${repository}"
                    currentBranch=$(gitBranchName)
                    if ! isBranchCurrent "${targetBranch}"
                    then
                        logD "Switching to target branch: ${targetBranch}"
                        gitSwitch "${targetBranch}"
                        if [ $? -ne 0 ]
                        then
                            logF "Switch to branch ${targetBranch} return code:$?"
                            cd ..
                            continue
                        fi
                    fi
                    commits=$(gitCommitCounter)
                    added=$(gitCountChanges 'A')
                    modified=$(gitCountChanges 'M')
                    deleted=$(gitCountChanges 'D')
                    copied=$(gitCountChanges 'C')
                    renamed=$(gitCountChanges 'R')
                    tfmodified=$(gitCountChanges 'T')
                    unmerged=$(gitCountChanges 'U')
                    untracked=$(gitCountChanges '\?')
                    ignored=$(gitCountChanges '\!')
                    # check all counters for changes
                    if [ $added      -gt 0 ] || \
                       [ $modified   -gt 0 ] || \
                       [ $deleted    -gt 0 ] || \
                       [ $copied     -gt 0 ] || \
                       [ $renamed    -gt 0 ] || \
                       [ $tfmodified -gt 0 ] || \
                       [ $unmerged   -gt 0 ] || \
                       [ $untracked  -gt 0 ] || \
                       [ $ignored    -gt 0 ]
                    then
                        printf -v string "🗘 %s\t %s%s%s%s%s%s%s%s%s%s%s on %s at %s." \
                        "${repository}" \
                        "${targetBranch}" \
                        "$([ $commits    -eq 0 ] && echo -n '' || { [ $commits -gt 0 ] && echo -n " 🡱:${commits}" || echo -n " 🡫:${commits}" ; })" \
                        "$([ $added      -eq 0 ] && echo -n '' || echo -n " A:${added}")" \
                        "$([ $copied     -eq 0 ] && echo -n '' || echo -n " C:${copied}")" \
                        "$([ $deleted    -eq 0 ] && echo -n '' || echo -n " D:${deleted}")" \
                        "$([ $modified   -eq 0 ] && echo -n '' || echo -n " M:${modified}")" \
                        "$([ $renamed    -eq 0 ] && echo -n '' || echo -n " R:${renamed}")" \
                        "$([ $tfmodified -eq 0 ] && echo -n '' || echo -n " T:${tfmodified}")" \
                        "$([ $unmerged   -eq 0 ] && echo -n '' || echo -n " U:${unmerged}")" \
                        "$([ $untracked  -eq 0 ] && echo -n '' || echo -n " ?:${untracked}")" \
                        "$([ $ignored    -eq 0 ] && echo -n '' || echo -n " !:${ignored}")" \
                        "$(getDate)" \
                        "$(getTime)"
                        logIt "\033[37m update\033[0m: $string"
                        logD "gitAdd '.'"
                        gitAdd '.' || logE "gitAdd('.') return code:$?"
                        logD "gitCommitSigned ${string}"
                        gitCommitSigned "${string}" || logE "gitCommit() return code:$?"
                        if isBranchBehind
                        then
                            logD "isBranchBehind"
                            logD "gitFetch"
                            gitFetch || logE "gitFetch() return code:$?"
                            logD "gitPull"
                            gitPull  || logE "gitPull() return code:$?"
                        fi
                        logD "gitPush"
                        gitPush || logE "gitPush() returned code:$?"
                    else
                        logI "🗘 ${repository}\t ${targetBranch} is up to date."
                    fi
                done
            else
                logW 'No internet connection available.'
                counter=$sleepNOCONN
            fi
            echo
            logI 'Press [Q] or [q] to exit from program.'
            logI 'Press [U] or [u] to start update.'
        fi
        printf -v string "Next Update: %4ds" ${counter}
        logNLF "${string}"
        sleep 1
        counter=$((counter-1))
    done

    # Reset Libs
    logEnd
    logStop

    return 0
}

declare -i LEN=$#
declare -a ARGS=("$@")

for ((INDEX=0 ; INDEX < LEN ; INDEX++))
do
    if [ "${ARGS[$INDEX]}" = '-g' ]
    then
        DEBUG=1
    fi
done

# Load Libs
LEN=${#libLIST[@]}
for ((INDEX=0 ; INDEX < LEN ; INDEX++))
do
    if [ -f "${libPATH}/lib${libLIST[$INDEX]}.sh" ] && [[ "lib${libLIST[$INDEX]}.sh" != "$(basename "$0")" ]] ; then
        source "${libPATH}/lib${libLIST[$INDEX]}.sh"
        err=$?
        if [ $err -eq 0 ]
        then
            logDebug "Load ${libPATH}/lib${libLIST[$INDEX]}.sh"
            libLOADED+=("${libLIST[$INDEX]}")
        else
            logFail "Load ${libPATH}/lib${libLIST[$INDEX]}.sh"
            _exit 1
        fi
    else
        logFail "File ${libPATH}/lib${libLIST[$INDEX]}.sh not found."
    fi
done

# Call main()
main "$@"

# Call _exit()
_exit $?
