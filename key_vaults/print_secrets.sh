#!/bin/bash

set -euo pipefail

# Function to resolve key vault abbreviation to full name
resolve_key_vault() {
    local KEY_VAULT="$1"
    KEY_VAULT=$(echo "${KEY_VAULT}" | xargs)  # Trim whitespace
    case ${KEY_VAULT} in
        a)  echo "long-key-vault-name" ;;
        *)  echo "${KEY_VAULT}" ;;  # Return as-is if not an abbreviation
    esac
}

echo "Supported key vault abbreviations:"
echo "    a --> long-key-vault-name"
echo ""

read -p "Enter the key vault(s) (use commas to separate multiple key vaults): " KEY_VAULTS_CSV
if [ -z "${KEY_VAULTS_CSV}" ]; then
    echo "No key vault specified. Aborting."
    exit 1
fi

read -p "Enter the secret(s) whose value(s) are to be printed (use commas to separate multiple secrets): " SECRETS_CSV
if [ -z "${SECRETS_CSV}" ]; then
    echo "No secrets specified. Aborting."
    exit 1
fi

IFS=',' read -r -a KEY_VAULTS_ARRAY <<< "${KEY_VAULTS_CSV}"
IFS=',' read -r -a SECRETS_ARRAY <<< "${SECRETS_CSV}"

PAST_SEARCHES_FILE="/var/tmp/print_secrets_past_executions.log"

for KEY_VAULT in "${KEY_VAULTS_ARRAY[@]}"; do
    KEY_VAULT=$(echo "${KEY_VAULT}" | xargs)  # Trim whitespace
    if [ -z "${KEY_VAULT}" ]; then
        continue
    fi

    KEY_VAULT=$(resolve_key_vault "${KEY_VAULT}")

    echo ""
    echo "${KEY_VAULT}:"

    for SECRET_NAME in "${SECRETS_ARRAY[@]}"; do
        SECRET_NAME=$(echo "${SECRET_NAME}" | xargs)  # Trim whitespace
        if [ -z "${SECRET_NAME}" ]; then
            continue
        fi

        SECRET_VALUE=$(az keyvault secret show --vault-name "${KEY_VAULT}" --name "${SECRET_NAME}" 2>/dev/null | jq --raw-output '.value' || echo "<<< NOT FOUND >>>")
        echo "    ${SECRET_NAME}: ${SECRET_VALUE}"
    done

    # Log the query
    echo "${KEY_VAULT} : ${SECRETS_CSV}" >> "${PAST_SEARCHES_FILE}"
done
