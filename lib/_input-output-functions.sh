# _input-output-functions.sh
#
# NOTE:
# This is the first file to be sourced (because of _ in the name) which is why
# it contains some special stuff like EXIT_TASKS that I want to be available everywhere.

# Collect exit tasks in this array.
# Without the empty string as initial value ${EXIT_TASKS[@]} would be an unbound variable
# that would result an error exit if 'set -eu' is used:
EXIT_TASKS=("")

# Add $* as an exit task to be done at the end:
function AddExitTask () {
    # NOTE: We add the task at the beginning to make sure that they are executed in reverse order.
    # I use $* on purpose because I want to get one string from all args!
    EXIT_TASKS=( "$*" "${EXIT_TASKS[@]}" )
    Debug "Added '$*' as an exit task"
}

function QuietAddExitTask () {
    # NOTE: We add the task at the beginning to make sure that they are executed in reverse order.
    # I use $* on purpose because I want to get one string from all args!
    EXIT_TASKS=( "$*" "${EXIT_TASKS[@]}" )
}

# Remove $* from the exit tasks list:
function RemoveExitTask () {
    local removed="" exit_tasks=""
    for (( c=0 ; c<${#EXIT_TASKS[@]} ; c++ )) ; do
        if test "${EXIT_TASKS[c]}" = "$*" ; then
            # the ' ' protect from bash expansion, however unlikely to have a file named EXIT_TASKS in pwd...
            unset 'EXIT_TASKS[c]'
            removed=yes
            Debug "Removed '$*' from the list of exit tasks"
        fi
    done
    if ! test "$removed" = "yes" ; then
        exit_tasks="$( for task in "${EXIT_TASKS[@]}" ; do echo "$task" ; done )"
        Log "Could not remove exit task '$*' (not found). Exit Tasks: '$exit_tasks'"
    fi
}

# Do all exit tasks:
function DoExitTasks () {
    Log "Running exit tasks."
    # kill all running jobs
    JOBS=( $( jobs -p ) )
    # when "jobs -p" results nothing then JOBS is still an unbound variable so that
    # an empty default value is used to avoid 'set -eu' error exit if $JOBS is unset:
    if test -n ${JOBS:-""} ; then
        Log "The following jobs are still active:"
        jobs -l 1>&2
        kill -9 "${JOBS[@]}" 1>&2
        # allow system to clean up after killed jobs
        sleep 1
    fi
    for task in "${EXIT_TASKS[@]}" ; do
        Debug "Exit task '$task'"
        eval "$task"
    done
}


# Make sure nobody else can use trap:
#function trap () {
#    BugError "Forbidden usage of trap with '$@'. Use AddExitTask instead."
#}

# For actually intended user messages output to the original STDOUT
function Print () {
    echo -e "${MESSAGE_PREFIX}$*" 
}


# For actually intended user error messages output to the original STDERR
function PrintError () {
    echo "$(bold $(red ${MESSAGE_PREFIX}$*))"
}

# For messages that should only appear in the log file output to the current STDERR
# because (usually) the current STDERR is redirected to the log file:
function Log () {
    # Have a timestamp with nanoseconds precision in any case
    # so that any subsequent Log() calls get logged with precise timestamps:
    local timestamp=$( date +"%Y-%m-%d %H:%M:%S.%N " )
    if test $# -gt 0 ; then
        echo "${MESSAGE_PREFIX}${timestamp}$*" || true
    else
        echo "${MESSAGE_PREFIX}${timestamp}$( cat )" || true
    fi 1>&2
}

# For messages that should only appear in the log file when in debug mode:
function Debug () {
    test "$DEBUG" && Log "$@" || true
}

# For messages that should appear in the log file when in debug mode and
# that also appear on the user's terminal (in debug mode the verbose mode is set automatically):
function DebugPrint () {
    Debug "$@"
    test "$DEBUG" && Print "$@" || true
}

# For messages that should appear in the log file and also
# on the user's terminal
function LogPrint () {
    Log "$@"
    Print "$@"
}

# For messages that should appear in the log file and also
# on the user's terminal
function LogPrintError () {
    Log "$@"
    PrintError "$@"
}

# Error exit:
function Error () {
    LogPrintError "ERROR: $*"
    # Make sure Error exits the master process, even if called from child processes:
    kill -USR1 $MASTER_PID
}

# If return code is non-zero, bail out:
function StopIfError () {
    if (( $? != 0 )) ; then
        Error "$@"
    fi
}


# Exit if there is a bug
function BugError () {
    Error "
====================
BUG in '$@'
--------------------
Please report this issue at https://github.com/gdha/rear-automated-testing/issues
and include the relevant parts from $LOGFILE
===================="
}

# If return code is non-zero, there is a bug
function BugIfError () {
    if (( $? != 0 )) ; then
        BugError "$@"
    fi
}

# Show the user if there is an error:
function PrintIfError () {
    # If return code is non-zero, show that on the user's terminal
    if (( $? != 0 )) ; then
        PrintError "$@"
    fi
}

# Log if there is an error;
function LogIfError () {
    if (( $? != 0 )) ; then
        Log "$@"
    fi
}

# Log if there is an error and also show it to the user:
function LogPrintIfError () {
    # If return code is non-zero, show that on the user's terminal
    if (( $? != 0 )) ; then
        LogPrintError "$@"
    fi
}

# usage example of colored output: echo "some $(bold $(red hello world)) test"
function bold () {
    ansi 1 "$@";
}

function italic () {
     ansi 3 "$@";
}

function underline () {
     ansi 4 "$@";
}

function strikethrough () {
     ansi 9 "$@";
}

function red () {
     ansi 31 "$@";
}

function green () {
     ansi 32 "$@";
}

function ansi () {
     case $(uname -s) in
        Linux)  echo -e "\e[${1}m${*:2}\e[0m" ;;
        Darwin) echo -e "\033[${1}m${*:2}\033[0m" ;;
             *) echo "$2" ;;
     esac
}

