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

declare -r scriptFILENAME="$(basename "$0")"
declare -r scriptNAME="${scriptFILENAME%.*}"

## @brief   Version number.
declare -a -i -r VERSION=(3 2 1)

## @Var     List of index variables for configuration tables.
declare -i -r iFILE=0
declare -i -r iUSER_DIR=1
declare -i -r iDEV_DIR=2
declare -i -r iMONITOR_DIR=3
declare -i -r iICON_FAILURE=4
declare -i -r iICON_SUCCESS=5
declare -i -r iGIT_LIST=6
declare -i -r iSLEEP=7
declare -i -r iSLEEP_LOST_CONN=8
declare -i -r iLOG_TARGET=9
declare -i -r iLOG_LEVEL=10
declare -i -r iMAX=11

## @var tableTAG    Table of configuration tags.
declare -a -r tableTAG=(\
FILE USER_DIR DEV_DIR MONITOR_DIR ICON_FAILURE \
ICON_SUCCESS GIT_LIST SLEEP SLEEP_LOST_CONN LOG_TARGET \
LOG_LEVEL)

## @var tableDEFAULT    Table of default configuration values.
declare -a -r tableDEFAULT=(\
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

##
# @brief    Unset global varuables
# @param    none
# @return   0       Success
#           1..N    Error code.
function unsetVars()
{
    unset -v tableCONFIG
    unset -v err
    unset -v run
    unset -v key
    unset -v counter
    unset -v wait
    unset -v repositoryName
    unset -v userDIR
    unset -v devDIR
    unset -v monitorDIR
    unset -v gitLIST
    unset -v sleepTIME
    unset -v sleepTIME_LOST_CONN
    unset -v iconFAIL
    unset -v iconSUCCESS
    unset -v scriptFilename
    unset -v scriptName
    unset -v configFile
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
    local res repository added modified deleted copied renamed tfmodified untracked unmerged commits
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
            logE "${devDIR}/${repo} is NOT a Git Repository."
            break
        fi
        cd "${devDIR}/${repo}" || { err=2 ; logF "Could not move into dir ("${devDIR}/${repo}")" ; break ; }
        # get Repository name
        repository="$(gitRepositoryName)"
        # get current Branch name
        currentBranch=$(gitBranchName)
        # create AutoUpdate branch if it not exist
        if ! existBranch "${targetBranch}"
        then
            logD "Target branch ${targetBranch} not exist yet."
            if ! isConnected ; then { err=3 ; break ; } ; fi
            createBranch "${targetBranch}" || { err=4 ; logF "Could not create new branch ${targetBranch}" ; break ; }
        else
            logD "Branch ${targetBranch} already exist."
        fi
        # switch to Branch
        if ! isBranchCurrent "${targetBranch}"
        then
            logD "Target branch ${targetBranch} is not current yet."
            gitSwitch "${targetBranch}" || { err=5 ; logF "Could not switch to branch ${targetBranch}" ; break ; }
        fi
        if ! isBranchCurrent "${targetBranch}" ; then { err=6 ; logF "Could not create|switch to branch ${targetBranch}" ; break ; } ; fi
        # get remote data and update local branch
        if isConnected && isBranchBehind
        then
            uptodate=false
            errNo=0
            logD "Running fetch() and pull() on branch ${targetBranch}, it is behind the remote."
            for ((count=1 ; count <= 3; count++))
            do
                # git fetch
                gitFetch || { errNo=$((errNo|1)) ; logE "gitFetch()" ; }
                # git pull
                gitPull || { errNo=$((errNo|2)) ; logE "gitPull()" ; }
                if [ $errNo -eq 0 ]
                then
                    break
                else
                    if gitSetRemoteUpstream "${targetBranch}"
                    then
                        if gitPullRebase
                        then
                            :
                        else
                            err=7
                            logF "gitPullRebase()"
                            break
                        fi
                    else
                        logE "gitSetRemoteUpstream()"
                    fi
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
        untracked=$(gitCountUntracked)
        # check all counters for changes
        if [ $added      -gt 0 ] || \
           [ $modified   -gt 0 ] || \
           [ $deleted    -gt 0 ] || \
           [ $copied     -gt 0 ] || \
           [ $renamed    -gt 0 ] || \
           [ $tfmodified -gt 0 ] || \
           [ $unmerged   -gt 0 ] || \
           [ $untracked  -gt 0 ]
        then
            logD "Detected target branch ${targetBranch} changes."
            uptodate=false
            printf -v string "%s\t%s\t%s%s%s%s%s%s%s%s%s on %s at %s" \
            "${repository}" \
            "${targetBranch}" \
            "$([ $commits    -le 0 ] && echo -n '' || echo -n " 🡱:${commits}")" \
            "$([ $added      -eq 0 ] && echo -n '' || echo -n " A:${added}")" \
            "$([ $copied     -eq 0 ] && echo -n '' || echo -n " C:${copied}")" \
            "$([ $deleted    -eq 0 ] && echo -n '' || echo -n " D:${deleted}")" \
            "$([ $modified   -eq 0 ] && echo -n '' || echo -n " M:${modified}")" \
            "$([ $renamed    -eq 0 ] && echo -n '' || echo -n " R:${renamed}")" \
            "$([ $tfmodified -eq 0 ] && echo -n '' || echo -n " T:${tfmodified}")" \
            "$([ $unmerged   -eq 0 ] && echo -n '' || echo -n " U:${unmerged}")" \
            "$([ $untracked  -eq 0 ] && echo -n '' || echo -n " ?:${untracked}")" \
            "$(getDate)" \
            "$(getTime)"
            logI "$string"
            # git add .
            gitAdd '.' || { err=8 ; logF "gitAdd('.')" ; break ; }
            # git commit -m "message"
            gitCommitSigned "${string}" || { err=9 ; logF "gitCommit(\"${string}\") failed." ; break ; }
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
                        logE "gitPush()"
                        if gitSetRemoteUpstream "${targetBranch}"
                        then
                            :
                        else
                            logE "gitSetRemoteUpstream( ${targetBranch} )"
                            if gitPullRebase
                            then
                                :
                            else
                                err=10
                                logF "gitPullRebase()"
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
            logI "${repository}\t\t${targetBranch}\t 🗸"
        elif [ $err -eq 0 ]
        then
            # success message
            logS "${repository}\t\t${targetBranch}\t 🗸"
            notify-send -a "$scriptBASENAME" -u normal -t 5 --icon="${iconSUCCESS}" "Rep.:${repository} Branch:${targetBranch}"
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
        notify-send -a "$scriptBASENAME" -u normal -t 10 --icon="$iconFAIL" "Rep.:${repository} Branch:${targetBranch} Error:${err}"
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
                --) shift ; libSetup "$@" || _exit 1 ;;
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

    libSetup ${tableCONFIG[$iLOG_LEVEL]} -l ${tableCONFIG[$iLOG_TARGET]}

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
    return 0
}

source libShell.sh || exit 1
libInit -v -l 3    || _exit 1
logBegin           || _exit 1

source libConfig.sh || _exit 1

main "$@"
_exit $?
