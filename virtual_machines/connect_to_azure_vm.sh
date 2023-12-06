#!/bin/sh

read -p "Enter the resource group: " RESOURCE_GROUP
if [ -z "${RESOURCE_GROUP}" ]; then
    echo "No resource group specified. Aborting."
    exit 1
fi

read -p "Enter the name of the virtual machine: " VM_NAME
if [ -z "${VM_NAME}" ]; then
    echo "No virtual machine name specified. Aborting."
    exit 1
fi

read -p "Enter the remmina profile to use: " REMMINA_PROFILE_FILE
if [ ! -f "${REMMINA_PROFILE_FILE}" ] then
    echo "Invalid remmina profile file. Aborting."
    exit 1
fi

VM_STATE=$(az vm show --show-details --resource-group=${RESOURCE_GROUP} --name=${VM_NAME} | jq --raw-output '.powerState')
if [ "${VM_STATE}" != "VM running" ]; then
    yad --no-buttons --on-top \
        --width=400 \
        --height=250 \
        --picture --filename=/home/gautam/play/gautam_linux/misc/images/two_minutes_countdown.gif \
        --text="It seems like the Azure windows VM is not running.\nStarting it now, please wait..." & YAD_PID=$!

    az vm start --resource-group=${RESOURCE_GROUP} --name=${VM_NAME}

    kill -TERM ${YAD_PID}
fi

remmina --connect=${REMMINA_PROFILE_FILE}
