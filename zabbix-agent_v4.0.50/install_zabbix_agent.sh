#!/bin/bash

# Installation script for Zabbix Agent

# Ensure the script is run as root
if [[ "$(id -u)" -ne 0 ]]; then
   echo "This script must be run as root" >&2
   exit 1
fi

# Define the source directory
SOURCE_DIR="."

# Check if source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Source directory does not exist: $SOURCE_DIR" >&2
    exit 1
fi

# Copy files to their respective locations
echo "Copying files..."
cp -r $SOURCE_DIR/etc/* /etc/
cp -r $SOURCE_DIR/usr/* /usr/

# Create Zabbix Agent user
echo "Creating Zabbix user and group..."
groupadd -f zabbix
useradd -r -g zabbix -s /bin/false zabbix 2>/dev/null || true
usermod -aG video zabbix

# Create log folder
echo "Creating log folder..."
mkdir -p /var/log/zabbix
chown -R zabbix:zabbix /var/log/zabbix/

# Add Zabbix Agent to sudoers for specific script execution without a password
echo "Adding Zabbix Agent to sudoers..."
{
    echo "# Allow Zabbix user to run check_raspberry.sh script without a password"
    echo "zabbix ALL=(ALL) NOPASSWD: /usr/local/sbin/check_raspberry.sh"
} >/etc/sudoers.d/zabbix_agent_check_raspberry
chmod 0440 /etc/sudoers.d/zabbix_agent_check_raspberry
# Verify the syntax (optional but recommended)
visudo -c -f /etc/sudoers.d/zabbix_agent_check_raspberry || {
    echo "Error in sudoers file syntax. Reverting changes."
    rm -f /etc/sudoers.d/zabbix_agent_check_raspberry
    exit 1
}

# Reload systemd daemon to recognize the new service
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable and start Zabbix Agent service
echo "Enabling and starting Zabbix Agent service..."
systemctl enable zabbix-agent.service
systemctl start zabbix-agent.service

echo "Zabbix Agent installation completed."