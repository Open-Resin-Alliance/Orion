#!/bin/bash

# Arguments
SCREEN_ROTATION=$1
BASE_USER=$2

# Path to the service file
SERVICE_FILE="/etc/systemd/system/orion.service"

# Read the service file
LINES=$(cat $SERVICE_FILE)

# Replace the ExecStart line
if [ -n "$SCREEN_ROTATION" ]; then
    LINES=$(echo "$LINES" | sed "s|flutter-pi\s*\(-r\s*[0-9]*\)*|flutter-pi -r $SCREEN_ROTATION|")
fi

# Write the updated lines back to the service file
echo "$LINES" | sudo tee $SERVICE_FILE > /dev/null

# Reload the systemd daemon and restart the service
sudo systemctl daemon-reload
sudo systemctl restart orion.service