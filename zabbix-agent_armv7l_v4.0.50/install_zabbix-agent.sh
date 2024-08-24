#!/bin/bash

# Define the user and group
USER="zabbix"
GROUP="zabbix"

# Define installation paths
ZABBIX_DIR="/usr/local/zabbix"
ZABBIX_CONF_DIR="$ZABBIX_DIR/conf"
ZABBIX_SBIN_DIR="/usr/local/sbin"
ZABBIX_LIB_DIR="/usr/lib/zabbix"
ZABBIX_LOG_DIR="/var/log/zabbix"

# Function to create user and group if they don't exist
create_user_group() {
    if ! id -u "$USER" >/dev/null 2>&1; then
        echo "Creating user and group $USER:$GROUP..."
        sudo groupadd "$GROUP"
        sudo useradd -r -g "$GROUP" -d "$ZABBIX_DIR" -s /sbin/nologin "$USER"
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

# Function to mirror files to the system and set correct permissions
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

    # Set ownership to zabbix:zabbix for all copied files and directories
    echo "Setting ownership to $USER:$GROUP for all copied files..."
    sudo chown -R "$USER:$GROUP" "$ZABBIX_CONF_DIR" "$ZABBIX_SBIN_DIR" "$ZABBIX_LIB_DIR" 2>/dev/null

    # Set appropriate permissions
    echo "Setting permissions for directories to 755 and files to 644..."
    sudo find "$ZABBIX_CONF_DIR" "$ZABBIX_SBIN_DIR" "$ZABBIX_LIB_DIR" -type d -exec chmod 755 {} \; 2>/dev/null
    sudo find "$ZABBIX_CONF_DIR" "$ZABBIX_SBIN_DIR" "$ZABBIX_LIB_DIR" -type f -exec chmod 644 {} \; 2>/dev/null

    echo "File installation and setup completed successfully."
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
ExecStart=$ZABBIX_SBIN_DIR/zabbix_agentd -c $ZABBIX_CONF_DIR/zabbix_agentd.conf
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

# Function to add Zabbix Agent to sudoers for specific script execution
add_to_sudoers() {
    echo "Adding Zabbix Agent to sudoers for running check_raspberry.sh without a password..."

    # Create sudoers file for zabbix to run check_raspberry.sh without a password
    sudo tee /etc/sudoers.d/zabbix_agent_check_raspberry > /dev/null <<EOL
# Allow Zabbix user to run check_raspberry.sh script without a password
zabbix ALL=(ALL) NOPASSWD: /usr/local/sbin/check_raspberry
EOL

    # Set appropriate permissions on the sudoers file
    sudo chmod 0440 /etc/sudoers.d/zabbix_agent_check_raspberry

    # Verify the sudoers file syntax
    if sudo visudo -c -f /etc/sudoers.d/zabbix_agent_check_raspberry; then
        echo "Sudoers file syntax is valid."
    else
        echo "Error in sudoers file syntax. Reverting changes."
        sudo rm -f /etc/sudoers.d/zabbix_agent_check_raspberry
        exit 1
    fi
}

# Main script
echo "Starting Zabbix Agent installation..."

create_user_group
mirror_files
set_log_permissions
create_systemd_service
add_to_sudoers

echo "Installation complete. The Zabbix agent is now running and enabled to start at boot."

