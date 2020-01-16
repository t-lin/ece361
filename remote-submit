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
checkLabNum ${LAB_NUM}
if [[ $? -ne 0 ]]; then
    exit 1
fi

# Open SSH connection
# If an old control path w/ SSH flags exist, skip opening a new session, since
# there's likely an existing SSH connection we can re-use.
unset NEW_CONNECTION
if [[ ! -n ${CTRL_PATH} && ! -n ${SSHFLAGS} ]]; then
    sshEECGOpenSess
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    NEW_CONNECTION=1
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
# Don't close session if we're re-using an old connection
if [[ -n ${NEW_CONNECTION} ]]; then
    sshEECGCloseSess
fi

