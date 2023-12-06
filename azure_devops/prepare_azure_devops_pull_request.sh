#!/bin/bash

set -euo pipefail

GIT_TOP=$(git rev-parse --show-toplevel)
if [ $? != "0" ]; then
    return 1
fi

PROJECT=$(basename $(dirname ${GIT_TOP}))

REPO=$(basename ${GIT_TOP})

BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)
if [ $? != "0" ]; then
    echo "ERROR: cannot determine the current branch"
    return 1
fi

read -p "Enter the organization host: " ORG_HOST

xdg-open "https://${ORG_HOST}/${PROJECT}/_git/${REPO}/pullrequestcreate?targetRef=master&sourceRef=${BRANCH}"
