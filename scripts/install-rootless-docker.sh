#!/bin/bash

if [[ "$EUID" -eq 0 ]] ; then
  echo "ERROR: Please do NOT run this script with with sudo!"
  exit 1
fi

echo "INFO: Updating packages..."
if (sudo apt-get update -y 2>&1) > >(sed 's/^/      /') ; then
  echo # Blank line
else
  echo "ERROR: Could not update packages!"
  exit 1
fi

echo "INFO: Upgrading packages..."
if (sudo apt-get upgrade -y 2>&1) > >(sed 's/^/      /') ; then
  echo # Blank line
else
  echo "ERROR: Could not upgrade packages!"
  exit 1
fi

echo "INFO: Installing dbus-user-session..."
if (sudo apt-get install -y dbus-user-session 2>&1) > >(sed 's/^/      /') ; then
  echo # Blank line
else
  echo "ERROR: Could not install dbus-user-session!"
  exit 1
fi

echo "INFO: Installing uidmap..."
if (sudo apt-get install uidmap -y 2>&1) > >(sed 's/^/      /') ; then
  echo # Blank line
else
  echo "ERROR: Could not install uidmap!"
  exit 1
fi

echo "INFO: Enabling login linger"
if (loginctl enable-linger "$(whoami)" 2>&1) > >(sed 's/^/      /') ; then
  echo # Blank line
else
  echo "ERROR: Could not enable linger!"
  exit 1
fi

echo "INFO: Running the docker rootless installation script..."
if (curl -fsSL https://get.docker.com/rootless | sh 2>&1) > >(sed 's/^/      /') ; then
  echo # Blank line
else
  echo "ERROR: Failed to run the docker rootless installation script!"
  exit 1
fi

PATH_MODIFICATION="export PATH=/home/'$USER'/bin:'$PATH'"
if (cat ~/.bashrc | grep "$PATH_MODIFICATION" > /dev/null 2>&1) > >(sed 's/^/      /') ; then
  echo "SKIP: Adding the user's bin to the path for non-interactive shells"
  echo # Blank line
else
  echo "INFO: Adding the user's bin to the path for non-interactive shells"
  if (echo -e "$PATH_MODIFICATION""\n$(cat ~/.bashrc)" > ~/.bashrc) ; then
    source ~/.bashrc
    echo # Blank line
  else
    echo "ERROR: Failed to add the user's bin to the path for non-interactive shells"
    exit 1
  fi
fi

echo "INFO: Enabling Docker to run on boot"
if (systemctl --user enable docker 2>&1) > >(sed 's/^/      /') ; then
  echo # Blank line
else
  echo "ERROR: Failed to enable Docker to run on boot"
  exit 1
fi

echo "INFO: Ensure the rootless context is used"
if (docker context use rootless 2>&1) > >(sed 's/^/      /') ; then
  echo # Blank line
else
  echo "ERROR: Failed to ensure the rootless context is used"
  exit 1
fi

