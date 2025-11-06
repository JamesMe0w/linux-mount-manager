#!/bin/bash
# WARNING! BE VERY CAREFUL WITH MOUNTS, HAS THE POTENTIAL TO CORRUPT BOOT ORDER

# === Settings ===
TEMPLATE="./mount.sh.template"
LOCAL_OUTPUT="./mount.sh"
DEPLOY=True
DEPLOYMENT_TARGET="/usr/local/bin/mount.sh"
LOCAL_SERVICE_FILE_TEMPLATE="./mount.service.template"
LOCAL_SERVICE_FILE="./mount.service"
DEPLOYMENT_SERVICE_FILE="/etc/systemd/system/mount.service"

declare -A REPLACE_VARS=(
    [BASE]="/home/user"
    [RAID1_DEVICE]="/dev/md128"
    [RAID1_MOUNT]="/mnt/raid128_data"
    [RAID1_FOLDERS]="folder1,folder2,folder3"
    [RAID2_DEVICE]=""
    [RAID2_MOUNT]=""
    [RAID2_FOLDERS]=""
)
# ================

# Copy template to target
cp "$TEMPLATE" "$LOCAL_OUTPUT"

# Loop over array to replace placeholders
for key in "${!REPLACE_VARS[@]}"; do
    sed -i "s|{{${key}}}|${REPLACE_VARS[$key]}|g" "$LOCAL_OUTPUT"
done

sed -i '/^ *"::/d' "$LOCAL_OUTPUT"
sed -i '/^ *" *:.*"/d' "$LOCAL_OUTPUT"
echo "Local mount bash script generated successfully at local $LOCAL_OUTPUT"

if [[ "${DEPLOY,,}" == "true" ]]; then
    echo "Deployment enabled! Deploying mount bash script and its service."

    SERVICE_NAME=$(basename "$DEPLOYMENT_SERVICE_FILE")
    # Remove existing service
    sudo systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    sudo systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    sudo rm -f "$DEPLOYMENT_SERVICE_FILE"
    sudo systemctl daemon-reload
    echo "Removed existing deployed service!"

    # Remove existing mount script
    sudo rm -f "$DEPLOYMENT_TARGET"
    echo "Removed existing deployed mount script!"

    # Deploy completed mount script
    sudo cp "$LOCAL_OUTPUT" "$DEPLOYMENT_TARGET"
    sudo chmod +x "$DEPLOYMENT_TARGET"
    echo "Mount script deployed!"

    # Create service from template
    cp "$LOCAL_SERVICE_FILE_TEMPLATE" "$LOCAL_SERVICE_FILE"
    sed -i "s|{{DEPLOYMENT_TARGET}}|${DEPLOYMENT_TARGET}|g" "$LOCAL_SERVICE_FILE"
    echo "Service file created from $LOCAL_SERVICE_FILE_TEMPLATE at local $LOCAL_SERVICE_FILE"

    # Deploy completed service
    sudo cp "$LOCAL_SERVICE_FILE" "$DEPLOYMENT_SERVICE_FILE"
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl daemon-reload
    echo "Service deployed!"

    if ! systemctl is-active --quiet "$SERVICE_NAME"; then
        echo "Running service once to enact mount changes."
        sudo systemctl start "$SERVICE_NAME"
        sudo systemctl status "$SERVICE_NAME" --no-pager
    fi
else
    echo "Deployment disabled."
fi

echo "Script complete!"