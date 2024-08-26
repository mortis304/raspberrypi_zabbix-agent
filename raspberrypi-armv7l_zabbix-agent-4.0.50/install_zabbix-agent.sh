#!/bin/bash

# Define the user and group
USER="zabbix"
GROUP="zabbix"

# Define log directory path
ZABBIX_LOG_DIR="/var/log/zabbix"

# Function to create user and group if they don't exist
create_user_group() {
    if ! id -u "$USER" >/dev/null 2>&1; then
        echo "Creating user and group $USER:$GROUP..."
        sudo groupadd "$GROUP"
        sudo useradd -r -g "$GROUP" -d "/usr/local/zabbix" -s /sbin/nologin "$USER"
    else
        echo "User and group $USER:$GROUP already exist."
    fi
}

# Function to set permissions for /var/log/zabbix
set_log_permissions() {
    echo "Setting permissions for $ZABBIX_LOG_DIR..."
    sudo mkdir -p "$ZABBIX_LOG_DIR"
    sudo chown -R "$USER:$GROUP" "$ZABBIX_LOG_DIR"
    sudo chmod -R 755 "$ZABBIX_LOG_DIR"
}

# Function to mirror files to the system
mirror_files() {
    SRC_DIR="./usr"  # Define the source directory relative to the install script

    echo "Starting recursive mirroring of files from $SRC_DIR..."

    # Check if the source directory exists
    if [ ! -d "$SRC_DIR" ]; then
        echo "Error: Source directory $SRC_DIR does not exist!" >&2
        exit 1
    fi

    # Recursively copy all files and directories from $SRC_DIR to the root /
    echo "Mirroring files from $SRC_DIR to the root directory..."
    if sudo cp -r "$SRC_DIR"/* /; then
        echo "Files successfully mirrored from $SRC_DIR to /"
    else
        echo "Error occurred while copying files from $SRC_DIR to /" >&2
        exit 1
    fi
}

# Function to create systemd service file
create_systemd_service() {
    echo "Creating Zabbix agent systemd service file..."
    cat <<EOL | sudo tee /etc/systemd/system/zabbix-agent.service > /dev/null
[Unit]
Description=Zabbix Agent
After=network.target

[Service]
Type=simple
User=$USER
Group=$GROUP
ExecStart=/usr/local/sbin/zabbix_agentd -c /usr/local/zabbix/conf/zabbix_agentd.conf
PIDFile=/run/zabbix/zabbix_agentd.pid
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd to recognize the new service
    sudo systemctl daemon-reload

    # Enable the service to start on boot
    sudo systemctl enable zabbix-agent.service

    # Start the service immediately
    sudo systemctl start zabbix-agent.service
}

# Main script
echo "Starting Zabbix Agent installation..."

create_user_group
mirror_files
set_log_permissions
create_systemd_service

echo "Installation complete. The Zabbix agent is now running and enabled to start at boot."

