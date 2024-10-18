#!/bin/bash

# Define URLs for downloading files
DROPBEAR_BIN_URL="https://raw.githubusercontent.com/MNLierman/System-Flashing/refs/heads/main/dropbear_arm_builder/dropbearmulti"
DROPBEAR_INIT_URL="https://raw.githubusercontent.com/MNLierman/System-Flashing/refs/heads/main/dropbear_arm_builder/dropbearserver.sh"

# Function to log messages
log() {
  local message="$1"
  echo "$message"
}

# Greet the user
log "This script will attempt to download and setup Dropbear SSH with init.d system startup."
log "The default username is bear and the password is grizzly."
log "If you are ready to get started, press any key, or Ctrl-C to cancel."
read -n 1 -s

# Download Dropbear binary and init script
log "Downloading Dropbear server and init script..."
wget -O /usr/sbin/dropbearmulti "$DROPBEAR_BIN_URL"
wget -O /etc/init.d/dropbearserver "$DROPBEAR_INIT_URL"

# Set executable permissions
log "Setting executable permissions..."
chmod +x /etc/init.d/dropbearserver /usr/sbin/dropbearmulti

# Create symbolic links for init.d startup
log "Creating symbolic links for init.d startup..."
ln -sv ../init.d/dropbearserver /etc/rc0.d/K77dropbear
ln -sv ../init.d/dropbearserver /etc/rcS.d/S77dropbear

# Start Dropbear service
log "Starting Dropbear service..."
/etc/init.d/dropbearserver start

log "Dropbear SSH setup completed successfully."
