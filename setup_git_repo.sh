#!/bin/bash

# Set up a local git repository based on a specified upstream; and check
# out a specific commit.
#
# Exit 0 on success; exit 1 on failure

if [ -z "$3" -o ! -z "$4" ]
then
    echo "Usage: $(basename $0) <git-repo-url> <local-dir> <commit-ID>"
    exit 1
fi

REMOTE="$1"
LOCAL="$2"
COMMIT="$3"
OPWD=$(pwd)


if [ -e "${LOCAL}" ]
then
    if [ -d "${LOCAL}" ]
    then
        # Directory already exists; try to use it
        if ! cd "${LOCAL}"
        then
            echo "ERROR: Can't cd to existing ${LOCAL}"
            exit 1
        fi
        if ! git rev-parse --show-top-level > /dev/null 2>&1
        then
            echo "ERROR: Existing ${LOCAL} directory is not a git repo"
            cd "$OPWD"
            exit 1
        else
            # Directory is a git repo; refresh meta-data
            if ! git fetch -q
            then
                echo "ERROR: git fetch into existing ${LOCAL} repo failed"
                cd "$OPWD"
                exit 1
            else
                echo "Successful git fetch to existing ${LOCAL}"
            fi
        fi
    else
        echo "ERROR: ${LOCAL} exists but is not a directory"
        cd "$OPWD"
        exit 1
    fi
else
    # Doesn't already exist; clone the source
    if ! git clone ${REMOTE} ${LOCAL} --recursive
    then
        echo "ERROR: git clone into new ${LOCAL} failed"
        exit 1
    fi
    if ! cd ${LOCAL}
    then
        echo "ERROR: Can't cd to new ${LOCAL}"
        exit 1
    fi
fi

# If we reach this point, then we have an up-to-date repo in $LOCAL,
# and we're cd'd into that dir. Check out our target commit.
if ! git checkout ${COMMIT}
then
    echo "ERROR: Can't check out commit ${COMMIT} in ${LOCAL}"
    exit 1
fi

cd "$OPWD"

exit 0
