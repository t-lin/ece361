#!/bin/bash
# NOTE: This script has less error checking than it should... Assumes the
#       caller has done appropriate checks (designed to integrate w/ others).
#       Generally a bad assumption.

SCRIPT_DIR=$(cd $(dirname "$0") && pwd)
source ${SCRIPT_DIR}/echoHelpers
unset ERR

if [[ $# -lt 3 ]]; then
    bold_blue "Usage format:"
    blue "\tTo submit: remote-submit.sh <remote submit cmd> <lab num> <file1> [<file2> ...]"
    blue "\tTo list submissions: remote-submit.sh <remote submit cmd> -l <lab num>"
    exit 1
else
    # Add explicit path to submit command since it's not sourced during SSH
    # Currently all submit scripts are in /local/bin (both EECG and ECF),
    # so hopefully they don't change it...
    SUBMIT_CMD=/local/bin/$1

    if [[ "$2" == "-l" ]]; then
        # echo "Listing submissions"
        LAB_NUM=$3
    else
        # echo "Submitting files"
        LAB_NUM=$2
        SUBMISSIONS=${@:3:$#}
    fi
fi

# Sanity check of lab number
NUM_REGEX='^[0-9]+$'
if [[ ! ${LAB_NUM} =~ ${NUM_REGEX} ]]; then
    bold_red "ERROR: Lab number must be a positive integer"
    exit 1
fi

# Checks if 'ERR' variable exists and has been set, and exit if so.
function checkErr() {
    if [[ $ERR ]]; then
        exit 1
    fi
}

# Find available UG EECG host to SSH into.
#   - Checks if entry exist in DNS
#   - If entry exists, see if port 22 is up
# Hoping this function "future-proofs" the process since EECG may
# change the station names at any time or shut some down.
function findAvailEECGHost() {
    bold_blue "Finding available UG EECG host..."

    # Count backwards from 254 since, at the time of script creation, more
    # we know that more hosts are in the ug200+ range.
    for i in `seq 254 -1 1`; do
        EECG_HOST=`dig ug${i}.eecg.utoronto.ca +short`
        if [[ -n ${EECG_HOST} ]]; then
            # Using 'nc' here to test since most systems have it
            nc -z -w1 ${EECG_HOST} 22
            if [[ $? -eq 0 ]]; then
                return
            fi
        fi
    done

    bold_red "ERROR: Unable to find available EECG host to connect to"
    ERR=1
}

findAvailEECGHost
checkErr

# Open SSH connection
bold_blue "Connecting to UG EECG host..."
read -p "UG EECG username: " UTORID

# TODO: Remove below, but must first ensure VM has global ssh_config with control master
mkdir -p /tmp/ece361-ssh-ctrl
SSHFLAGS+=" -o ControlPath=/tmp/ece361-ssh-ctrl/%r@%h:%p -o ControlMaster=auto -o ControlPersist=3m"
SSHFLAGS+=" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

if [[ "$2" == "-l" ]]; then
    # echo "Listing submissions"
    ssh ${SSHFLAGS} ${UTORID}@${EECG_HOST} ${SUBMIT_CMD} -l ${LAB_NUM}
else
    # Create temporary directory in remote host, copy files to that directory,
    # submit the files, then delete the remote directory
    REMOTE_TMP_DIR=`ssh ${SSHFLAGS} ${UTORID}@${EECG_HOST} mktemp -d`
    ssh ${SSHFLAGS} ${UTORID}@${EECG_HOST} chmod og-rwx ${REMOTE_TMP_DIR}
    scp ${SSHFLAGS} ${SUBMISSIONS} ${UTORID}@${EECG_HOST}:${REMOTE_TMP_DIR}
    ssh ${SSHFLAGS} ${UTORID}@${EECG_HOST} "cd ${REMOTE_TMP_DIR} && ${SUBMIT_CMD} ${LAB_NUM} ${SUBMISSIONS}"
    ssh ${SSHFLAGS} ${UTORID}@${EECG_HOST} rm -rf ${REMOTE_TMP_DIR}
fi

