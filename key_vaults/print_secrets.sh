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
IFS=',' read -r -a KEY_VAULTS_ARRAY <<< "${KEY_VAULTS_CSV}"
RESOLVED_KEY_VAULTS=()
for KV in "${KEY_VAULTS_ARRAY[@]}"; do
    KV=$(echo "${KV}" | xargs)   # Trim whitespace
    [[ -z "${KV}" ]] && continue # Skip empty
    RESOLVED_KEY_VAULTS+=("$(resolve_key_vault "${KV}")") # Resolve abbreviations
done
RESOLVED_KEY_VAULTS=($(printf "%s\n" "${RESOLVED_KEY_VAULTS[@]}" | sort -u)) # Remove duplicates

read -p "Enter the secret(s) whose value(s) are to be printed (use commas to separate multiple secrets): " SECRETS_CSV
if [ -z "${SECRETS_CSV}" ]; then
    echo "No secrets specified. Aborting."
    exit 1
fi
IFS=',' read -r -a SECRETS_ARRAY <<< "${SECRETS_CSV}"
SECRETS_ARRAY=($(printf "%s\n" "${SECRETS_ARRAY[@]}" | xargs -n1 | sort -u)) # Trim whitespace and remove duplicates

PAST_SEARCHES_FILE="/var/tmp/print_secrets_past_executions.log"

for KEY_VAULT in "${RESOLVED_KEY_VAULTS[@]}"; do
    echo ""
    echo "${KEY_VAULT}:"

    for SECRET_NAME in "${SECRETS_ARRAY[@]}"; do
        SECRET_VALUE=$(az keyvault secret show --vault-name "${KEY_VAULT}" --name "${SECRET_NAME}" 2>/dev/null | jq --raw-output '.value' || echo "<<< NOT FOUND >>>")
        echo "    ${SECRET_NAME}: ${SECRET_VALUE}"
    done

    # Log the query
    echo "${KEY_VAULT} : ${SECRETS_CSV}" >> "${PAST_SEARCHES_FILE}"
done
