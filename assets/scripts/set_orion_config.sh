#!/bin/bash

# Arguments
SCREEN_ROTATION=$1
BASE_USER=$2

# Path to the service file
SERVICE_FILE="/etc/systemd/system/orion.service"

# Read the service file
LINES=$(cat $SERVICE_FILE)

# Replace the ExecStart line
LINES=$(echo "$LINES" | sed "s|^ExecStart=.*|ExecStart=flutter-pi ${SCREEN_ROTATION:+-r $SCREEN_ROTATION} --release /home/$BASE_USER/orion|")

# Write the updated lines back to the service file
echo "$LINES" | sudo tee $SERVICE_FILE > /dev/null

# Reload the systemd daemon and restart the service
sudo systemctl daemon-reload
sudo systemctl restart orion.service