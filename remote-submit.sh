#!/bin/bash
# NOTE: This script has less error checking than it should... Assumes the
#       caller has done appropriate checks (e.g. ensuring the files exist).
#       Generally a bad assumption.

SCRIPT_DIR=$(cd $(dirname "$0") && pwd)
SUBMIT_CMD=$(basename $0) # Works w/ symbolic links
source /usr/local/ece361-wrapper-prints
source /usr/local/ece361-lib
unset ERR
unset LISTING

if [[ $# -lt 2 ]]; then
    bold_blue "Usage format:"
    blue "\tTo submit: ${SUBMIT_CMD} <lab num> <file1> [<file2> ...]"
    blue "\tTo list submissions: ${SUBMIT_CMD} -l <lab num>"
    exit 1
else
    # Add explicit path to submit command since it's not in the SSH session's PATH
    # Currently all submit scripts are in /local/bin (both EECG and ECF),
    # so hopefully they don't change it...
    SUBMIT_CMD=/local/bin/${SUBMIT_CMD}

    if [[ "$1" == "-l" ]]; then
        # echo "Listing submissions"
        LAB_NUM=$2
        LISTING=1
    else
        # echo "Submitting files"
        LAB_NUM=$1
        SUBMISSIONS=${@:2:$#}
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

# Open SSH connection
sshEECGOpenSess
if [[ $? -ne 0 ]]; then
    exit 1
fi

if [[ $LISTING ]]; then
    sshEECGRunCmd ${SUBMIT_CMD} -l ${LAB_NUM}
else
    REMOTE_TMP_DIR=`sshEECGRunCmd mktemp -d`
    sshEECGRunCmd chmod og-rwx ${REMOTE_TMP_DIR}
    scp ${SSHFLAGS} ${SUBMISSIONS} ${UTORID}@${EECG_HOST}:${REMOTE_TMP_DIR}
    sshEECGRunCmd "cd ${REMOTE_TMP_DIR} && ${SUBMIT_CMD} ${LAB_NUM} ${SUBMISSIONS}"
    sshEECGRunCmd rm -rf ${REMOTE_TMP_DIR}
fi

# Clean-up SSH control master
sshEECGCloseSess

