#!/bin/bash

# Renames a secret in a key vault. Key vaults do not support renaming
# natively, so this copies the secret to the new name and then deletes
# the old one. Note that version history, tags and expiry dates of the
# old secret are not carried over (content type is).

set -euo pipefail

if [ $# -ne 3 ]; then
    echo "Usage: $0 KEY_VAULT_NAME OLD_NAME NEW_NAME"
    exit 1
fi

KEY_VAULT_NAME=${1}
OLD_NAME=${2}
NEW_NAME=${3}

# We cannot pre-create the temporary file because
# `az keyvault secret download` will fail if the file already exists.
TMP_FILE=/tmp/secret

if [ -f "${TMP_FILE}" ]; then
    echo "File '${TMP_FILE}' already exists. Aborting."
    exit 1
fi

# Ensure the secret value does not linger in /tmp, even on failure.
trap "rm -f ${TMP_FILE}" EXIT

if ! az keyvault secret show --vault-name ${KEY_VAULT_NAME} \
        --name ${OLD_NAME} --output none 2>/dev/null; then
    echo "No secret named '${OLD_NAME}' found in key vault" \
        "'${KEY_VAULT_NAME}'. Aborting."
    exit 1
fi

if az keyvault secret show --vault-name ${KEY_VAULT_NAME} \
        --name ${NEW_NAME} --output none 2>/dev/null; then
    echo "A secret named '${NEW_NAME}' already exists. Aborting."
    exit 1
fi

CONTENT_TYPE=$(az keyvault secret show \
    --vault-name ${KEY_VAULT_NAME} \
    --name ${OLD_NAME} \
    --query contentType \
    --output tsv)

az keyvault secret download \
    --file ${TMP_FILE} \
    --vault-name ${KEY_VAULT_NAME} \
    --name ${OLD_NAME}

az keyvault secret set \
    --vault-name=${KEY_VAULT_NAME} \
    --file=${TMP_FILE} \
    --name=${NEW_NAME} \
    --content-type="${CONTENT_TYPE}"

az keyvault secret delete \
    --vault-name ${KEY_VAULT_NAME} \
    --name ${OLD_NAME} \
    --output none

echo "Renamed secret '${OLD_NAME}' to '${NEW_NAME}'. The old secret is" \
    "soft-deleted; it can still be recovered or purged until the" \
    "retention period expires."
