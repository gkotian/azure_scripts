#!/bin/bash

# Copies secrets from one key vault to another.

set -euo pipefail

SECRETS_TO_COPY=(
    SecretOne
    SecretTwo
    SecretThree
)
SOURCE_KEY_VAULT=srckeyvault
TARGET_KEY_VAULT=dstkeyvault

# We cannot pre-create a temporary file and use that for all the secrets because
# `az keyvault secret download` will fail if the file already exists.
TMP_FILE=/tmp/secret

if [ -f "${TMP_FILE}" ]; then
    echo "File '${TMP_FILE}' already exists. Aborting."
    exit 1
fi

for S in ${SECRETS_TO_COPY[@]}; do
    az keyvault secret download \
        --file ${TMP_FILE} \
        --vault-name ${SOURCE_KEY_VAULT} \
        --name ${S}

    read -p "Enter the content-type of '${S}' (optional): " CONTENT_TYPE

    az keyvault secret set \
        --vault-name=${TARGET_KEY_VAULT} \
        --file=${TMP_FILE} \
        --name=${S} \
        --content-type=${CONTENT_TYPE}

    rm -f ${TMP_FILE}
done
