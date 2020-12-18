#!/usr/bin/bash
# The logic for the message_id is handled in 
# https://github.com/coreos/ignition/pull/958
# In this script, we need to capture the journald 
# log with the particular message_id and query using 
#`jq` utility to check if a user config is provided.

# Change the output color to yellow
warn='\033[0;33m'
# No color
nc='\033[0m'

# See https://github.com/coreos/ignition/pull/958 for the MESSAGE_ID source.
# It will track the journal messages related to an Ignition config provided 
# by the user.
output=$(journalctl -o json-pretty MESSAGE_ID=57124006b5c94805b77ce473e92a8aeb | jq -s '.[] | select(.IGNITION_CONFIG_TYPE == "user")'| wc -l)

if [[ $output -gt  0 ]];then
    echo "Ignition: user provided config was applied" > /etc/issue.d/30_ignition_config_info.issue
else
    echo -e "${warn}Ignition: no config provided by user${nc}" > /etc/issue.d/30_ignition_config_info.issue
fi

# Ask all running agetty instances to reload and update their
# displayed prompts in case this script was run before agetty.
/usr/sbin/agetty --reload
