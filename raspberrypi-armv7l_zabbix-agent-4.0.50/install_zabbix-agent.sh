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

# Function to mirror files to the /usr directory
mirror_files() {
    SRC_DIR="./usr"  # Define the source directory relative to the install script

    echo "Starting recursive mirroring of files from $SRC_DIR..."

    # Check if the source directory exists
    if [ ! -d "$SRC_DIR" ]; then
        echo "Error: Source directory $SRC_DIR does not exist!" >&2
        exit 1
    fi

    # Recursively copy all files and directories from $SRC_DIR to the /usr directory
    echo "Mirroring files from $SRC_DIR to /usr..."
    if sudo cp -r "$SRC_DIR"/* /usr/; then
        echo "Files successfully mirrored from $SRC_DIR to /usr"
    else
        echo "Error occurred while copying files from $SRC_DIR to /usr" >&2
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
}

# Function to check if Zabbix agent is running
check_service_status() {
    echo "Checking if the Zabbix agent service is running..."

    # Start the service
    sudo systemctl start zabbix-agent.service

    # Wait for a few seconds to give the service time to start
    sleep 5

    # Check the status of the service
    if sudo systemctl is-active --quiet zabbix-agent.service; then
        echo "Zabbix agent service is running."
    else
        echo "Zabbix agent service failed to start." >&2
        exit 1
    fi
}

# Main script
echo "Starting Zabbix Agent installation..."

create_user_group
mirror_files
set_log_permissions
create_systemd_service
check_service_status

echo "Installation complete. The Zabbix agent is running and enabled to start at boot."

