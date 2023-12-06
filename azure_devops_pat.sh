#!/bin/bash

set -euo pipefail

RESOURCE=https://management.core.windows.net/

function listAllPATs() {
    local AZURE_DEVOPS_PAT_REST_API_URL=${1}

    az rest \
        --method=GET \
        --uri=${AZURE_DEVOPS_PAT_REST_API_URL} \
        --resource=${RESOURCE} | jq
}

function createPAT() {
    local AZURE_DEVOPS_PAT_REST_API_URL=${1}

    local ALLOWED_SCOPES=(
        vso.code
        vso.packaging
    )

    read -p "Enter the desired name of the PAT: " PAT_NAME
    # TODO: validate that there isn't already a PAT with the same name.

    read -p "Enter the desired scope of the PAT: " PAT_SCOPE
    if [[ ! " ${ALLOWED_SCOPES[*]} " =~ " ${PAT_SCOPE} " ]]; then
        echo "Scope '${PAT_SCOPE}' is not allowed. Aborting."
        exit 1
    fi

    read -p "[optional] Enter the date until which the PAT should be valid (will be set to 30 days from now if left empty): " PAT_VALID_UNTIL_DATE
    if [ -z "${PAT_VALID_UNTIL_DATE}" ]; then
        PAT_VALID_UNTIL_DATE=$(date --date '+30 days' +%Y-%m-%d)
    else
        echo "Note that the user-provided date is currently not checked for validity."
    fi

    REQUEST_BODY=$(jq --null-input --compact-output \
        --arg PAT_NAME "${PAT_NAME}" \
        --arg PAT_SCOPE "${PAT_SCOPE}" \
        --arg PAT_VALID_UNTIL_TIME "${PAT_VALID_UNTIL_DATE}T23:59:59Z" \
        '{displayName:$PAT_NAME, scope:$PAT_SCOPE, validTo:$PAT_VALID_UNTIL_TIME}')

    az rest \
        --method=POST \
        --uri=${AZURE_DEVOPS_PAT_REST_API_URL} \
        --resource=${RESOURCE} \
        --headers=Content-Type=application/json \
        --body=${REQUEST_BODY}

    echo "Token created successfully."
    echo "Make sure to copy the 'token' field from the output above - it will not be available later on."
}

function deletePAT() {
    local AZURE_DEVOPS_PAT_REST_API_URL=${1}

    # Unfortunately, there doesn't seem to be any way to fetch a PAT by name. If
    # that were possible, it would be better to ask the user for the name of the
    # PAT to be deleted, then extract its authorization ID and use that to
    # delete the PAT.
    # A slightly less optimal way is to ask the user for the name of the PAT to
    # be deleted, get the full list of all the PATs, filter out the one we need
    # by its name, then extract its authorization ID and use that to delete the
    # PAT.
    # For now, I've gone with the simplest option of asking the user to provide
    # the authorization ID of the PAT.

    read -p "Enter the authorization ID of the PAT to be deleted: " PAT_AUTH_ID

    URL_WITH_PAT_AUTH_ID="${AZURE_DEVOPS_PAT_REST_API_URL}&authorizationId=${PAT_AUTH_ID}"

    az rest \
        --method=DELETE \
        --uri=${URL_WITH_PAT_AUTH_ID} \
        --resource=${RESOURCE}

    # Since 'az rest' doesn't produce any output when deleting, we need to let
    # the user know that the PAT was successfully deleted.
    echo "PAT deleted successfully"
}

if [ $# -ne 1 ]; then
    echo "Expected exactly one argument - the command, got $#. Aborting."
    exit 1
fi

COMMAND=${1}

read -p "Enter the PAT REST API URL: " AZURE_DEVOPS_PAT_REST_API_URL
if [ -z "${AZURE_DEVOPS_PAT_REST_API_URL}" ]; then
    echo "No PAT REST API URL specified. Aborting."
    exit 1
fi

if [ "${COMMAND}" = "--list" ]; then
    listAllPATs "${AZURE_DEVOPS_PAT_REST_API_URL}"
elif [ "${COMMAND}" = "--create" ]; then
    createPAT "${AZURE_DEVOPS_PAT_REST_API_URL}"
elif [ "${COMMAND}" = "--delete" ]; then
    deletePAT "${AZURE_DEVOPS_PAT_REST_API_URL}"
else
    echo "Unsupported command '${COMMAND}'. Aborting."
    exit 1
fi
