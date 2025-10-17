#!/usr/bin/env bash

function logFail() { echo -e "\033[91mfailure:\033[0m $*" ; }

if [ -f libShell.sh ]
then
	source libShell.sh || { logFail "Load libShell.sh" ; exit 1 ; }
else
	logFail "libShell.sh not found."
	exit 1
fi

libInit -v || { logFail "Call function libInit() -v" ; exit 1 ; }

# global variables
declare -a -i -r VERSION=(2 0 0)
declare -r SCRIPTNAME='gitRepositoryMonitor.sh'
declare DAEMONAPP=$(getFileName $SCRIPTNAME)
declare DAEMONAME=$(getName $DAEMONAPP)
declare -r SYSDIR='/etc/systemd/system'
declare -r BINDIR='/usr/local/bin'
declare USERDIR="$HOME"
declare WORKDIR="$HOME/dev"
declare -i RELOAD=0

# unset all global vartiables and functions
function unsetVars()
{
	unset -v DAEMONAPP
	unset -v DAEMONAME
	unset -v WORKDIR
	unset -v USERDIR
	unset -v RELOAD
	return 0
}

function _exit()
{
	code=$([ -n "$1" ] && echo $1 || echo 0)
	logEnd
	libStop
	unsetVars
	exit $code
}

# print help message and information to terminal
function _help()
{
cat << EOT
Shell script program to install $DAEMONAPP as a daemon service.
Version: $$genVersionStr ${VERSION[@]})
Usage  : $SCRIPTNAME [-h] or $SCRIPTNAME [option] <value>
 -h | --help                    Show this help information.
Options:
 -b | --bindir  <directory>     Set binary directory destine.
 -s | --sysdir  <directory>     Set service directory destine.
 -n | --appname <name>          Set daemon application name+ext
 -w | --workdir <directory>     Set work directory.
 -r | --reload                  Enable reload daemon service at the end.
EOT
    return 0
}

# prepare the program as a daemon and install it as daemon on systemd
# daemoname.service will be copyied to /etc/systemd/system/ directory.
# scriptname.sh will be copyied to /usr/local/bin/ directory.
# enable, start, and get status of daemon using systemctl system application.
function _install()
{
    local err=0
    local SERVICEFILE="$DAEMONAME.service"
    local SCRIPTFILE="$DAEMONAPP"

cat << EOT > /tmp/$DAEMONAME.service
[Unit]
Description=Git (Status/Commit/Push) Monitor
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $BINDIR/$SCRIPTFILE -d
WorkingDirectory=$USERDIR
User=$USER
Group=$USER
Restart=on-failure
RestartSec=60
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOT

    if [ $? -eq 0 ] ; then
        logS "Create file /tmp/$SERVICEFILE"
        sudo cp /tmp/$SERVICEFILE $SYSDIR/
        if [ $? -ne 0 ] ; then
            err=$((err+1))
            logE "Copy file /tmp/$SERVICEFILE to $SYSDIR/"
        else
            logS "Copy file /tmp/$SERVICEFILE to $SYSDIR/"
        fi
        rm -f /tmp/$SERVICEFILE
    else
        err=$((err+2))
        logE "Create file /tmp/$SERVICEFILE"
    fi

    sudo cp ./$SCRIPTFILE $BINDIR/

    if [ $? -ne 0 ] ; then
        err=$((err+4))
        logE "Copy $SCRIPTFILE file to $BINDIR/ directory."
    else
        logS "Copy $SCRIPTFILE file to $BINDIR/ directory."
    fi

    return $err
}

# main application function, it have an infinite looping to
# check local git repositories and proceed to update it if needed.
function main()
{
    local err=0

    while [ -n "$1" ] ; do
        case "$1" in
        -h | --help)	_help
                    	return $?
                    	;;
        -b | --bindir)	shift
                    	BINDIR="$1"
                    	;;
        -s | --sysdir)	shift
                    	SYSDIR="$1"
                    	;;
        -n | --appname)	shift
                        SCRIPTNAME="$1"
                        DAEMONAME=${SCRIPTNAME%.*}
                        ;;
        -w | --workdir)	shift
                        WORKDIR="$1"
                        ;;
        -r | --reload)	RELOAD=1 ;;
        --) shift
        	libInit "$@" && break || { logF "Call function libInit $@" ; return 1 ; }
         	;;
        *)	logF "Unknown parameter $1"
			return 1
            ;;
        esac
        shift
    done

	logBegin

	logD "bindir: $BINDIR"
	logD "sysdir: $SYSDIR"
	logD "script name: $SCRIPTNAME"
	logD "daemo name: $DAEMONAME"
	logD "work dir: $WORKDIR"
	logD "reload: $RELOAD"

	askToContinue 10 || { logW "Finishing install by user or timeout." ; return 0 ; }

    _install

    if [ $? -eq 0 ] ; then
        logS "Install $DAEMONAME daemon service."
        if [ $RELOAD -ne 0 ] ; then
            sudo systemctl stop "$DAEMONAME.service" || err=$((err+2))
            sleep 0.5
            sudo systemctl disable "$DAEMONAME.service" || err=$((err+4))
            sleep 0.5
            sudo systemctl daemon-reload || err=$((err+8))
            sleep 0.5
            sudo systemctl enable "$DAEMONAME.service" || err=$((err+16))
            sleep 0.5
            sudo systemctl start "$DAEMONAME.service" || err=$((err+32))
            if [ $err -eq 0 ] ; then
                logS "Run all systemctl command line."
            else
                logE "systemctl command returned one or more error codes."
            fi
        else
            logW "Flag auto-reload was not set from command line."
        fi
    else
        logE "Install daemon $DAEMONAPP and/or $DAEMONAME.service failure."
        err=$((err+64))
    fi
    return $err
}

# shell script entry point, call main() function and
# pass all command line parameter "$@" to it.
main "$@"
_exit $?
