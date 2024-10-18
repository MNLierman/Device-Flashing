#!/bin/bash

# Define URLs for downloading files
DROPBEAR_BIN_URL="https://raw.githubusercontent.com/MNLierman/System-Flashing/main/dropbear_arm_builder/dropbearmulti"
DROPBEAR_INIT_URL="https://raw.githubusercontent.com/MNLierman/System-Flashing/main/dropbear_arm_builder/dropbearserver.sh"

# Comprehensive mode and verbose mode variables
COMPREHENSIVE_MODE=0
VERBOSE=0
ADD_ROOT_USER=0

# Variables used by the script
TMPINSTALLATION=0
RUNLOCATION=0 # 0 not set, 1 if dropbear can be run from /usr/sbin, 2 if dropbear can only be run from /tmp

# Function to log messages
log() {
  local message="$1"
  echo "$message"
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$message" >> /tmp/get-dropbear.log
  fi
}

# Function to check write permissions
check_write_permissions() {
  local dir="$1"
  if [ -w "$dir" ]; then
    [ "$VERBOSE" -eq 1 ] && log "Directory $dir is writable."
    return 0
  else
    [ "$VERBOSE" -eq 1 ] && log "Directory $dir is not writable."
    return 1
  fi
}

# Function to remount root filesystem
remount_rootfs() {
  log "Attempting to remount root filesystem with noatime and nodiratime..."
  mount -o remount,rw,noatime,nodiratime /
  if check_write_permissions "/"; then
    log "Successfully remounted root filesystem with write permissions."
    return 0
  else
    log "Failed to remount root filesystem with write permissions."
    return 1
  fi
}

# Function to add a new root user
add_root_user() {
  local username="bear"
  local password="grizzly"
  log "Adding new root user: $username"
  useradd -m -G root,sudo -s /bin/bash "$username"
  echo "$username:$password" | chpasswd
  log "User $username added to root and sudo groups with password $password."

  # Ensure passwordless sudo
  if [ -f /etc/sudoers ]; then
    log "Configuring passwordless sudo for $username"
    echo "$username ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    log "Passwordless sudo configured for $username"
  else
    log "ERROR: /etc/sudoers file not found!"
  fi
}

# Function to install Dropbear at root filesystem
install_at_rootfs() {
  # Download Dropbear binary and init script
  log "Downloading Dropbear server and init script..."
  wget -O /usr/sbin/dropbearmulti "$DROPBEAR_BIN_URL"
  wget -O /etc/init.d/dropbearserver "$DROPBEAR_INIT_URL"
  
  if [ ! -f /usr/sbin/dropbearmulti ]; then
    # Download to /usr/sbin failed! Let the user know and prompt to go back to the beginning
    if [ "$RWFALLBACK" -eq 1 ]; then
      log "Fatal Error: Aw snap! Root filesystem appeared writable but installation to /usr/sbin failed. You may not actually have rw permissions, and may need to force alternative installation. Press any key to go back, or press Ctrl-C to cancel."
    else
      log "Fatal Error: Aw snap! It appears that installation to /usr/sbin failed. You may not have rw permissions, and since fallback mode is off, the script cannot attempt other options. Press any key to go back, or press Ctrl-C to cancel."
    fi
    read -n 1 -s
    BEGNNING_WELCOME_PROMPT
    exit -1
  fi
  
  # Create symlink alias for dropbearserver called dbear
  log "Creating symlink alias for dropbearserver called dbear..."
  ln -sv /etc/init.d/dropbearserver /usr/sbin/dbear

  # Create symlinks for init.d startup
  log "Creating symbolic links for init.d startup..."
  ln -sv /etc/init.d/dropbearserver /etc/rc0.d/K77dropbear
  ln -sv /etc/init.d/dropbearserver /etc/rcS.d/S77dropbear

  # Set executable permissions
  log "Setting executable permissions..."
  chmod +x /etc/init.d/dropbearserver /usr/sbin/dropbearmulti
}



# This is where the script starts and prompts the user what options they want to enable.
BEGNNING_WELCOME_PROMPT() {
  # Greet the user
  echo "This script will attempt to download and setup Dropbear SSH with init.d system startup."
  echo "The default username is bear and the password is grizzly."
  echo "If you are ready to get started, press any key, or you can include any of the options below."
  echo ""
  echo "F:   Start with rw fail detection, which will install in /tmp if there are no rw permissions"
  echo "R:   Attempt to add new root user - default username bear, password grizzly"
  echo "V:   Enable verbose output and logging"

  read -n 1 -s key

  if [[ "$key" == *"F"* ]] || [[ "$key" == *"f"* ]]; then
    RWFALLBACK=1
  fi
  if [[ "$key" == *"V"* ]] || [[ "$key" == *"v"* ]]; then
    VERBOSE=1
  fi
  if [[ "$key" == *"R"* ]] || [[ "$key" == *"r"* ]]; then
    ADD_ROOT_USER=1
  fi

  # Add root user if requested
  if [ "$ADD_ROOT_USER" -eq 1 ]; then
    add_root_user
  fi

  # In fallback mode, we check for rw permissions, attempt to remount /, and failing those we install to /tmp and bind aliases.
  if [ "$RWFALLBACK" -eq 1 ] || [ "$FORCEATL" -eq 1 ]; then
    if ! check_write_permissions "/" || [ "$FORCEATL" -eq 1 ]; then
      if ! remount_rootfs; then
        if check_write_permissions "/tmp" || [ "$FORCEATL" -eq 1 ]; then
          log "Setting up Dropbear in /tmp directory..."
          mkdir -p /tmp/dropbear
          [ "$VERBOSE" -eq 1 ] && log "Downloading $DROPBEAR_BIN_URL."
          wget -O /tmp/dropbear/dropbearmulti "$DROPBEAR_BIN_URL"
          [ "$VERBOSE" -eq 1 ] && log "Downloading $DROPBEAR_INIT_URL."
          wget -O /tmp/dropbear/dropbearserver "$DROPBEAR_INIT_URL"
          [ "$VERBOSE" -eq 1 ] && log "Wget finished, setting execute permissions."
          chmod +x /tmp/dropbear/dropbearmulti /tmp/dropbear/dropbearserver
          [ "$VERBOSE" -eq 1 ] && log "Binding files from /tmp to rootfs."
          
          mount --bind /tmp/dropbear/dropbearmulti /usr/sbin/dropbearmulti
          mount --bind /tmp/dropbear/dropbearserver /etc/init.d/dropbearserver
          mount --bind /tmp/dropbear/dropbearserver /usr/sbin/dbear
          
          # Check if bind worked
          if [ -f /usr/sbin/dropbearmulti ]; then 
            RUNLOCATION=1
            # Create binds for init.d startup
            log "Creating symbolic links for init.d startup..."
            mount --bind /etc/init.d/dropbearserver /etc/rc0.d/K77dropbear
            mount --bind /etc/init.d/dropbearserver /etc/rcS.d/S77dropbear
          else
            RUNLOCATION=2
          fi
          
          # Add aliases
          mount --bind /tmp/dropbear/dropbearserver /tmp/dropbear/dbear
          mount --bind /tmp/dropbear/dropbearserver /tmp/dbear
          
          # Check for /jffs and setup init-start script if available
          if [ ! -f /etc/init.d/dropbearserver && -d /jffs/scripts ]; then
            log "Setting up Dropbear to start on boot using /jffs/scripts/init-start"
            echo "/tmp/dropbear/dropbearserver start" >> /jffs/scripts/init-start
            chmod +x /jffs/scripts/init-start
		  elif [ ! -f /etc/init.d/dropbearserver]
            log "Failed to find an autostart location for dropbear. You will need to run it manually when the system starts up."
          fi

          TMPINSTALLATION=1
        else
          log "FATAL ERROR: No write permissions available! Cannot continue."
          read -n 1 -s
          exit 1
        fi
      fi
    else
      log "Rootfs appears to be writable."
      # So attempt it
      install_at_rootfs
    fi
  fi
}

# Start the script by calling the welcome prompt
BEGNNING_WELCOME_PROMPT

# Check where we can run dropbear from, link startup and let the user know
if [ -f /usr/sbin/dropbearmulti ]; then RUNLOCATION=1; else RUNLOCATION=2; fi

# Start Dropbear service
if [ "$TMPINSTALLATION" -eq 1 ]; then
  log "Starting Dropbear service from /tmp..."
  /tmp/dropbear/dropbearserver start
  log "Dropbear SSH setup completed and dropbear has been started. Just a reminder, Dropbear is located at /tmp/dropbear with an alias at /tmp/dbear."
  if [ "$RUNLOCATION" -eq 1 ]; then
    log "You can run dropbear by typing dbear or dropbearmulti from the CLI, as aliases were linked to /usr/sbin/. Have fun!"
  fi
else
  log "Starting Dropbear service from /etc/init.d..."
  /etc/init.d/dropbearserver start
  log "Dropbear SSH setup completed successfully. Just a reminder, Dropbear is located at /usr/sbin and can be run by typing dbear or dropbearmulti. Have fun!"
fi
