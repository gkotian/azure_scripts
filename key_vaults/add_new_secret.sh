#!/bin/bash

set -euo pipefail

function FileEndsWithNewline() {
    [[ $(tail -c1 "$1" | wc -l) -gt 0 ]]
}

DEFAULT_SECRET_FILE=/tmp/secret
read -p "Enter the path of the file containing the secret (press 'Enter' to use '${DEFAULT_SECRET_FILE}'): " SECRET_FILE
if [ -z "${SECRET_FILE}" ]; then
    SECRET_FILE=${DEFAULT_SECRET_FILE}
fi

if [ ! -f ${SECRET_FILE} ]; then
    echo "File '${SECRET_FILE}' does not exist. Aborting."
    exit 1
fi

if FileEndsWithNewline ${SECRET_FILE}; then
    echo "WARNING: '${SECRET_FILE}' ends with a newline character."
    echo "If you answer the question below in the affirmative, the newline character will be part of the secret value (which would be VERY unusual)."
    read -p "Should the secret really contain a newline at the end? [y/N]: " YES_OR_NO
    if [ -z "${YES_OR_NO}" ] || [[ "${YES_OR_NO}" != [yY] ]]; then
        truncate -s -1 ${SECRET_FILE}
    fi
fi

read -p "Enter the name of the key vault: " KEY_VAULT_NAME
read -p "Enter the name of the secret to be added: " SECRET_NAME
read -p "Enter the content-type (optional): " CONTENT_TYPE

az keyvault secret set \
    --vault-name=${KEY_VAULT_NAME} \
    --file=${SECRET_FILE} \
    --name=${SECRET_NAME} \
    --content-type=${CONTENT_TYPE}

read -p "Delete secret file '${SECRET_FILE}'? (Y/n): " YES_OR_NO
if [ ! -z "${YES_OR_NO}" ]; then
    [[ "${YES_OR_NO}" != [yY] ]] && echo "Secret file retained." && exit 0
fi

rm -f ${SECRET_FILE}
echo "Secret file deleted."
