#!/usr/bin/env bash

################################################################################
# @brief        Git Monitor                                                    #
# @file         gitMonitor.sh                                                  #
# @author       Leandro - leandrohuff@programmer.net                           #
# @date         2025-09-12                                                     #
# @version      3.2.1                                                          #
# @copyright    CC01 1.0 Universal                                             #
# @details      The gitMonitor is a shell script program can running as        #
#               a daemon or bash script program.                               #
#               The purpose for this project is to automate the git updates    #
#               procedures to let local repositories up to date with online    #
#               github repositories.                                           #
################################################################################

declare scriptFILENAME="$(basename "$0")"
declare scriptNAME="${scriptFILENAME%.*}"
declare -a libLIST=(Config Conn EscCodes File Git Log Math Random Regex Shell String)
declare -a libLOADED=()

## @brief   Version number.
declare -a -i VERSION=(3 2 1)

## @Var     List of index variables for configuration tables.
declare -i iFILE=0
declare -i iUSER_DIR=1
declare -i iDEV_DIR=2
declare -i iMONITOR_DIR=3
declare -i iICON_FAILURE=4
declare -i iICON_SUCCESS=5
declare -i iGIT_LIST=6
declare -i iSLEEP=7
declare -i iSLEEP_LOST_CONN=8
declare -i iLOG_TARGET=9
declare -i iLOG_LEVEL=10
declare -i iMAX=11

## @var tableTAG    Table of configuration tags.
declare -a tableTAG=(\
FILE USER_DIR DEV_DIR MONITOR_DIR ICON_FAILURE \
ICON_SUCCESS GIT_LIST SLEEP SLEEP_LOST_CONN LOG_TARGET \
LOG_LEVEL)

## @var tableDEFAULT    Table of default configuration values.
declare -a tableDEFAULT=(\
$scriptNAME.cfg \
\$HOME \
dev \
gitMonitor \
icons/failure.png \
icons/success.png \
git.list \
1800 \
600 \
2 \
-v)

## @var
configFILE="${scriptNAME}.cfg"
currentDIR="${PWD}"
userDIR=''
devDIR=''
monitorDIR=''
gitLIST=''
sleepTIME=0
sleepTIME_LOST_CONN=0
iconFAIL=''
iconSUCCESS=''

## @var tableCONFIG     Table of user configuration values.
declare -a tableCONFIG=()

# Print failure messages on terminal.
function logFail() { echo -e "\033[31mfailure\033[0m: $*" ; }

# Print success messages on terminal.
function logOk() { echo -e "\033[37msuccess\033[0m: $*" ; }

##
# @brief    Unset global varuables
# @param    none
# @return   0       Success
#           1..N    Error code.
function unsetVars()
{
    unset -v scriptFILENAME
    unset -v scriptNAME
    unset -v libLIST
    unset -v libLOADED
    unset -v VERSION
    unset -v iFILE
    unset -v iUSER_DIR
    unset -v iDEV_DIR
    unset -v iMONITOR_DIR
    unset -v iICON_FAILURE
    unset -v iICON_SUCCESS
    unset -v iGIT_LIST
    unset -v iSLEEP
    unset -v iSLEEP_LOST_CONN
    unset -v iLOG_TARGET
    unset -v iLOG_LEVEL
    unset -v iMAX
    unset -v tableTAG
    unset -v tableDEFAULT
    unset -v configFILE
    unset -v currentDIR
    unset -v userDIR
    unset -v devDIR
    unset -v monitorDIR
    unset -v gitLIST
    unset -v sleepTIME
    unset -v sleepTIME_LOST_CONN
    unset -v iconFAIL
    unset -v iconSUCCESS
    unset -v tableCONFIG

    unset -f _help
    unset -f _exit
    unset -f unsetVars
    unset -f gitUpdate
    unset -f main
    return 0
}

##
# @brief    Exit from program and return an error code.
# @param    $1      Error code, assume 0 for empty parameter.
# @return   0       Success
#           1..N    Error code.
function _exit()
{
    local code=$( [ -n "$1" ] && echo $1 || echo 0 )
    logD "Exit code ($code)"
    logR
    logEnd
    libStop
    local len=${#libLOADED[@]}
    for ((index=0 ; index < $len ; index++))
    do
        $(lib${libLOADED[$index]}Exit)
        if [ $? -eq 0 ]
        then
            logOk "Unload lib${libLOADED[$index]}.sh"
        else
            logFail "Unload lib${libLOADED[$index]}.sh"
        fi
    done
    unsetVars
    exit $code
}

##
# @brief    Print a help message.
# @param    none
# @return   0       Success
#           1..N    Error code.
function _help()
{
printf "
Git repository monitor.
$(printLibVersion)
Version: ${WHITE}$(genVersionStr ${VERSION[@]})${NC}
Usage  : ${WHITE}$scriptBASENAME${NC} [-h | --help]
--------------------------------------------------------------------------------
Daemon Options:
-h | --help             Show this help information and return.
-c | --config <file>    Load configuration from file, default is (userConfig).
     --                 Send next parameters to libShell.
--------------------------------------------------------------------------------
libShell Options:
-h|--help               Show this help information.
-V|--version            Print version number.
-q|--quiet              Disable all messages (default at startup).
-d|--default            Set log to default level.
-v|--verbose            Set log to verbose level.
-g|--debug              Enable debug messages.
-t|--trace              Enable trace messages.
-l|--log <0|1|2|3>      Set log target:
                            0=Disabled (default, at startup)
                            1=Screen only
                            2=File only
                            3=Both (default, for empty value).
-T|--timeout <N>        Set timeout value, -N=disabled, 0=infinite, +N=timeout.
--------------------------------------------------------------------------------
Some configuration parameters are loaded from file ( ${tableDEFAULT[$iFILE]} )
--------------------------------------------------------------------------------
"
    return 0
}

##
# @brief    Update local repositories from a list file on a remote git host.
# @param    $1      Base directory from where all repositories are stored.
#           $2      Repository name.
# @return   0       Success
#           1..N    Error code.
function gitUpdate()
{
    local repo="$1"
    local currentBranch=''
    local targetBranch='AutoUpdate'
    local string=''
    local run=true
    local runPush=false
    local uptodate=true
    local res repository added modified deleted copied renamed tfmodified untracked unmerged commits ignored
    declare -i errNo=0
    declare -i err=0
    declare -i count
    # check true git repository
    while $run
    do
        run=false
        if ! isGitRepository "${devDIR}/${repo}"
        then
            err=1
            logE "Folder ${devDIR}/${repo} is NOT a Git Repository."
            break
        fi
        cd "${devDIR}/${repo}" || { err=$? ; logF "Move to dir ${devDIR}/${repo} return code:$err" ; break ; }
        # get Repository name
        repository="$(gitRepositoryName)"
        # get current Branch name
        currentBranch=$(gitBranchName)
        # check AutoUpdate branch if it exist
        if existBranch "${targetBranch}"
        then
            logD "Branch ${targetBranch} already exist."
        else
            logF "Target branch ${targetBranch} not exist yet, it should be created."
            break
        fi
        # switch to Branch
        if ! isBranchCurrent "${targetBranch}"
        then
            logD "Target branch ${targetBranch} is not current."
            gitSwitch "${targetBranch}" || { err=$? ; logF "Switch to branch ${targetBranch} return code:$err" ; break ; }
        fi
        if ! isBranchCurrent "${targetBranch}" ; then { err=$? ; logF "Switch to branch ${targetBranch} return code:$err" ; break ; } ; fi
        # get remote data and update local branch
        if isConnected && isBranchBehind
        then
            uptodate=false
            errNo=0
            logD "Running fetch() and pull() on branch ${targetBranch}, it is behind the remote."
            for ((count=1 ; count <= 3; count++))
            do
                # git fetch
                gitFetch || { errNo=$? ; logE "gitFetch() return code:$errNo" ; }
                # git pull
                gitPull || { errNo=$? ; logE "gitPull() return code:$errNo" ; }
                if [ $errNo -eq 0 ] ; then break
                else if gitSetRemoteUpstream "${targetBranch}" ; then break ; else err=$? ; logE "gitSetRemoteUpstream() return code:$err" ; fi
                fi
                errNo=0
            done
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
            logD "Detected target branch ${targetBranch} changes."
            uptodate=false
            printf -v string "🗘 %s\t\t %s%s%s%s%s%s%s%s%s%s%s on %s at %s" \
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
            logI "$string"
            # git add .
            gitAdd '.' || { err=$? ; logF "gitAdd('.') return code:$err" ; break ; }
            # git commit -m "message"
            gitCommitSigned "${string}" || { err=$? ; logF "gitCommit( ${string} ) return code: $err." ; break ; }
            runPush=true
        fi
        # push only if connected to internet
        if isConnected
        then
            # should run push command?
            if $runPush || isBranchAhead
            then
                logD "Running push() on branch ${targetBranch} to update remote."
                uptodate=false
                # try 3 times
                for ((count=1 ; count <= 3; count++))
                do
                    if gitPush
                    then
                        break
                    else
                        errNo=$?
                        logE "gitPush() return code:$errNo"
                        if gitSetRemoteUpstream "${targetBranch}"
                        then
                            :
                        else
                            errNo=$?
                            logE "gitSetRemoteUpstream( ${targetBranch} ) return code:$errNo"
                            if gitPullRebase
                            then
                                :
                            else
                                err=$?
                                logF "gitPullRebase() return code:$err"
                                break
                            fi
                        fi
                    fi
                done
            fi
        fi
        # up to date message
        if $uptodate
        then
            logI "🗘 ${repository}\t\t ${targetBranch} 🗸"
        elif [ $err -eq 0 ]
        then
            # success message
            logS "🗘 ${repository}\t\t ${targetBranch} 🗸"
            notify-send -a "$scriptBASENAME" -u normal -t 5 --icon="${iconSUCCESS}" "🗘 ${repository}   ${targetBranch} 🗸"
        fi
    done
    if ! isBranchCurrent "${currentBranch}"
    then
        gitSwitch "${currentBranch}" || logE "Could not switch back to branch ${currentBranch}"
    fi
    # move back to directory.
    cd "${currentDIR}" || logF "Change back to ( ${currentDIR} ) directory."
    # any error send a notify message
    if [ $err -ne 0 ]
    then
        logE "${string}"
        notify-send -a "$scriptBASENAME" -u normal -t 10 --icon="$iconFAIL" "🗘 ${repository}   ${targetBranch} code:${err}"
    fi
    # return an error code.
    return $err
}

##
# @brief    Main application program function.
# @param    $@      All command line parameters.
# @return   0       Success
#           1..N    Error code.
function main()
{
    local err=0
    local run=true
    declare configFILE="${tableDEFAULT[$iFILE]}"

    # Setup Libs
    logInit -l 1 -g -v
    logSetup -l 3
    logBegin
    libShellSetup -t 5

    if [ $# -gt 0 ]
    then
        while [ -n "$1" ]
        do
            case "$1" in
                -h | --help) _help ; _exit 0 ;;
                -c | --config)
                    if isArgValue "$2"
                    then
                        shift
                        if [ -f "$1" ]
                        then
                            configFILE="$1"
                        else
                            logF "Config file ( $1 ) not found."
                            _exit 1
                        fi
                    else
                        logF "Missing config file on parameter -c | --config <file>"
                        _exit 1
                    fi
                    ;;
                --) shift ; logSetup "$@" || _exit 1 ;;
                *) logF "Unknown option ( $1 )." ; _exit 1 ;;
            esac
            shift
        done
    fi

    tableCONFIG=($(loadConfigFromFile "${configFILE}" $iMAX "${tableTAG[@]}" "${tableDEFAULT[@]}"))
    [ -n "${configFILE}" ] && saveConfigToFile "${configFILE}" $iMAX "${tableTAG[@]}" "${tableCONFIG[@]}" || logF "Empty file to save user configuration."

    userDIR=$(eval echo "${tableCONFIG[$iUSER_DIR]}")
    devDIR="${userDIR}/${tableCONFIG[$iDEV_DIR]}"
    monitorDIR="${devDIR}/${tableCONFIG[$iMONITOR_DIR]}"
    gitLIST="${monitorDIR}/${tableCONFIG[$iGIT_LIST]}"
    sleepTIME=${tableCONFIG[$iSLEEP]}
    sleepTIME_LOST_CONN=${tableCONFIG[$iSLEEP_LOST_CONN]}
    iconFAIL="${monitorDIR}/${tableCONFIG[$iICON_FAILURE]}"
    iconSUCCESS="${monitorDIR}/${tableCONFIG[$iICON_SUCCESS]}"

    logSetup ${tableCONFIG[$iLOG_LEVEL]} -l ${tableCONFIG[$iLOG_TARGET]}

    logD "-----------------------------------------------"
    logD "Variables:"
    logD "-----------------------------------------------"
    logD "Script    File: $scriptFILENAME"
    logD "Script    Name: $scriptNAME"
    logD "Current    Dir: $currentDIR"
    logD "User       Dir: $userDIR"
    logD "Dev        Dir: $devDIR"
    logD "Monitor    Dir: $monitorDIR"
    logD "Git List  File: $gitLIST"
    logD "Wait      Time: ${sleepTIME}s|$((sleepTIME/60))mins"
    logD "Wait Lost Conn: ${sleepTIME_LOST_CONN}s|$((sleepTIME_LOST_CONN/60))mins"
    logD "Temp       Dir: $libTMP"
    logD "Log    to File: $logFILE"
    logD "Icon      Fail: $iconFAIL"
    logD "Icon   Success: $iconSUCCESS"
    logD "-----------------------------------------------"

    local wait=$sleepTIME
    local repositoryName=''

    [ -d "${userDIR}"     ] || { logF "Directory ${userDIR} not found."    ; _exit 1 ; }
    [ -d "${devDIR}"      ] || { logF "Directory ${devDIR} not found."     ; _exit 1 ; }
    [ -d "${monitorDIR}"  ] || { logF "Directory ${monitorDIR} not found." ; _exit 1 ; }
    [ -f "${gitLIST}"     ] || { logF "File ${gitLIST} not found."         ; _exit 1 ; }
    [ -f "${iconFAIL}"    ] || { logF "File ${iconFAIL} not found."        ; _exit 1 ; }
    [ -f "${iconSUCCESS}" ] || { logF "File ${iconSUCCESS} not found."     ; _exit 1 ; }

    local counter=0
    local key=''
    logI "Press [q] or [Q] to exit from program."
    while [ $run ]
    do
        if key=$(getChar) && [[ "$key" == 'q' || "$key" == 'Q' ]]
        then
            echo
            run=false
            break
        fi
        if [ $counter -le 0 ]
        then
            if isConnected
            then
                wait=$sleepTIME
            else
                wait=$sleepTIME_LOST_CONN
                logW "Internet connection not available"
            fi
            while read -e -r line ; do
                if ! [ -n "${line}" ] || [[ "${line:0:1}" == "#" ]] ; then continue ; fi
                repositoryName="${line}"
                logD "repository: ${repositoryName}"
                gitUpdate "${repositoryName}"
            done < "$gitLIST"
            logR
            counter=$wait
        fi
        logNLF "Waiting for ${counter}s|$((counter/60))mins"
        sleep 1
        counter=$((counter-1))
    done

    # Reset Libs
    logEnd
    logStop

    return 0
}

# Load Libs
len=${#libLIST[@]}
path="/var/home/$USER/dev/libShell"
for ((index=0 ; index < $len ; index++))
do
    if [ -f "${path}/lib${libLIST[$index]}.sh" ] && [[ "lib${libLIST[$index]}.sh" != "$(basename "$0")" ]]
    then
        source "${path}/lib${libLIST[$index]}.sh"
        if [ $? -eq 0 ]
        then
            libLOADED+=(${libLIST[$index]})
            logOk "Load lib${libLIST[$index]}.sh"
        else
            logFail "Load lib${libLIST[$index]}.sh"
        fi
    else
        logFail "File lib${libLIST[$index]}.sh not found."
    fi
done

main "$@"
_exit $?
