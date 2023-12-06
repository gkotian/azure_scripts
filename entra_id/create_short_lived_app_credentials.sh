#!/bin/bash

set -euo pipefail

case $# in
    0)
        read -p "Enter the application ID or name: " APP_ID_OR_NAME
        ;;
    1)
        APP_ID_OR_NAME=${1}
        ;;
    *)
        echo "Too many arguments."
        echo "Usage:"
        echo "    ➜ $0 [appID | appName]"
        exit 1
        ;;
esac

# If the given input looks like a UUID, then it is treated as the app ID, or
# else as the app name. The approach described in
# https://stackoverflow.com/a/38417281/793930 is used to determine whether the
# given input looks like a UUID.
if [[ ${APP_ID_OR_NAME//-/} =~ ^[[:xdigit:]]{32}$ ]]; then
    APP_ID=${APP_ID_OR_NAME}
    APP_NAME=$(az ad app show --id=${APP_ID} | jq --raw-output '.displayName')
    read -p "A short-lived secret will be created for '${APP_NAME}'. Continue? (Y/n): " YES_OR_NO
    if [ ! -z "${YES_OR_NO}" ]; then
        [[ "${YES_OR_NO}" != [yY] ]] && echo "Canceled." && exit 1
    fi
else
    APP_NAME=${APP_ID_OR_NAME}
    APP_ID=$(az ad app list --display-name=${APP_NAME} | jq --raw-output '.[0].appId')
fi

if [[ "${APP_NAME}" != Dev\.* ]]; then
    read -p "'${APP_NAME}' doesn't seem like a development app. Do you really want to create a short-lived secret for it? (y/N): " YES_OR_NO
    [ -z "${YES_OR_NO}" ] || [[ "${YES_OR_NO}" != [yY] ]] && echo "Canceled." && exit 1
fi

TMP_FILE=$(mktemp)

DEFAULT_VALID_UNTIL_DATE=$(date --date '+30 days' +%Y-%m-%d)

read -p "Enter the date until which the secret should be valid (leave blank to use '${DEFAULT_VALID_UNTIL_DATE}', i.e. 30 days from today): " VALID_UNTIL_DATE
if [ -z "${VALID_UNTIL_DATE}" ]; then
    VALID_UNTIL_DATE=${DEFAULT_VALID_UNTIL_DATE}
else
    # Confirm that the given date is valid.
    VERIFIED_DATE=$(date --iso-8601="date" --date "${VALID_UNTIL_DATE}")
    if [ "${VERIFIED_DATE}" != "${VALID_UNTIL_DATE}" ]; then
        echo "ERROR: invalid date '${VALID_UNTIL_DATE}'"
        exit 1
    fi

    # Confirm that the given date is either the current date or in the future.
    CURRENT_DATE=$(date --iso-8601="date")
    CURRENT_DATE_TS=$(date --date=${CURRENT_DATE} +%s)
    GIVEN_DATE_TS=$(date --date=${VALID_UNTIL_DATE} +%s)
    if [ "${GIVEN_DATE_TS}" -lt "${CURRENT_DATE_TS}" ]; then
        echo "ERROR: the valid until date cannot be older than ${CURRENT_DATE}."
        exit 1
    fi
fi

az ad app credential reset \
    --append \
    --display-name=until_${VALID_UNTIL_DATE} \
    --end-date=${VALID_UNTIL_DATE}T23:59:59Z \
    --id=${APP_ID} > ${TMP_FILE} 2>/dev/null

SHORT_LIVED_SECRET=$(jq --raw-output '.password' ${TMP_FILE})

# Print details in a form that is easy to share via a messaging application.
echo ""
echo "here are the local testing credentials for ${APP_NAME}:"
echo "    ClientId: ${APP_ID}"
echo "    ClientSecret (valid until ${VALID_UNTIL_DATE}): ${SHORT_LIVED_SECRET}"

# TODO: confirm if old expired secrets should be deleted, and if so, do it
# automatically
az ad app credential list \
    --id=${APP_ID} > ${TMP_FILE} 2>/dev/null
TMP_FILE2=$(mktemp)
jq --arg now "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")" '.[] | select(.endDateTime < $now) | {keyId, displayName}' ${TMP_FILE} > ${TMP_FILE2}
echo ""
echo "Old expired secrets:"
cat ${TMP_FILE2}
echo "Delete using: az ad app credential delete --id=${APP_ID} --key-id=<keyId>"
rm -f ${TMP_FILE2}

rm -f ${TMP_FILE}
