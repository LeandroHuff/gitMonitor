#!/usr/bin/env bash

declare -a libLIST=(Config Conn EscCodes File Git Log Math Random Regex Shell String)
declare -a libLOADED=()
declare -i listLEN=${#libLIST[@]}
declare    libPATH="/var/home/$USER/dev/libShell"

function logFail() { echo -e "\033[31mfailure\033[0m: $*" ; }

function unsetVars()
{
    unset -v libLIST
    unset -v libLOADED
    unset -v VERSION

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
    for ((index=0 ; index < $listLEN ; index++)) ; do
        $(lib${libLOADED[$index]}Exit) || logFail "Unload lib${libLOADED[$index]}.sh"
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
    logInit -l 1 -g -v
    logSetup -l 3
    logBegin
    libShellSetup -t 5

    local sleepTIME=300
    local sleepNOCONN=60
    local counter=1
    local path="/var/home/$USER/dev"

    while [ $run ] ; do
        if key=$(getChar) && [[ "$key" == 'q' || "$key" == 'Q' ]] ; then
            echo
            run=false
            break
        fi
        if [ $counter -le 0 ] ; then
            echo
            if isConnected ; then
                counter=$sleepTIME
                len=${#list[@]}
                for ((index=0 ; index < $len ; index++)) ; do
                    if [ -d "${path}/${list[$index]}" ] ; then
                        cd "${path}/${list[$index]}"
                        if [ $? -ne 0 ] ; then
                            logF "Folder ${path}/${list[$index]} not found."
                            break
                        fi
                    fi
                    repository="$(gitRepositoryName)"
                    currentBranch=$(gitBranchName)
                    if ! isBranchCurrent "${targetBranch}" ; then
                        gitSwitch "${targetBranch}"
                        if [ $? -ne 0 ] ; then
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
                       [ $ignored    -gt 0 ] ; then
                        printf -v string "🗘 %s   %s%s%s%s%s%s%s%s%s%s%s on %s at %s" \
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
                        logI "Update $string"
                        gitAdd '.' || logE "gitAdd('.') return code:$?"
                        gitCommitSigned "${string}" || logE "gitCommit() return code:$?"
                        if isBranchBehind ; then
                            gitFetch || logE "gitFetch() return code:$?"
                            gitPull  || logE "gitPull() return code:$?"
                        fi
                        gitPush || logE "gitPush() returned code:$?"
                    fi
                done
            else
                counter=$sleepNOCONN
            fi
        fi
        logNLF "Wait ${counter}s"
        sleep 1
        counter=$((counter-1))
    done

    # Reset Libs
    logEnd
    logStop

    return 0
}

# Load Libs
for ((index=0 ; index < $listLEN ; index++)) ; do
    if [ -f "${libPATH}/lib${libLIST[$index]}.sh" ] && [[ "lib${libLIST[$index]}.sh" != "$(basename "$0")" ]] ; then
        source "${libPATH}/lib${libLIST[$index]}.sh"
        if [ $? -eq 0 ] ; then
            libLOADED+=(${libLIST[$index]})
        else
            logFail "Load lib${libLIST[$index]}.sh"
        fi
    else
        logFail "File lib${libLIST[$index]}.sh not found."
    fi
done

# Call main()
main "$@"

# Call _exit()
_exit $?
