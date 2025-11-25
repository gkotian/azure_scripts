#!/bin/bash

set -euo pipefail

read -p "Enter the name of the key vault: " KEY_VAULT
if [ -z "${KEY_VAULT}" ]; then
    echo "No key vault specified. Aborting."
    exit 1
fi

read -p "Enter the secret(s) whose value(s) are to be printed (use commas to separate multiple secrets): " SECRETS_CSV
if [ -z "${SECRETS_CSV}" ]; then
    echo "No secrets specified. Aborting."
    exit 1
fi

IFS=',' read -r -a SECRETS <<< "${SECRETS_CSV}"

echo ""
for S in ${SECRETS[@]}
do
    echo "    ${S}: `az keyvault secret show --vault-name ${KEY_VAULT} --name ${S} | jq --raw-output '.value'`"
done

# Save a record of past searches
PAST_SEARCHES_FILE="/var/tmp/print_secrets_past_executions.log"
echo "${KEY_VAULT} : ${SECRETS_CSV}" >> ${PAST_SEARCHES_FILE}
