#!/bin/bash

while [[ "$#" -ge 1 ]] ; do
  LAST_ARG="$1"  # Capture this in case it is not a flag

  # Collect args formatted as "--flag" or "--flag=arg"
  if [[ "$1" =~ --([a-z-]+)(=(.+))? ]] ; then
    FLAG="${BASH_REMATCH[1]}"
    VALUE="${BASH_REMATCH[3]}"

    if [[ "$FLAG" == "config" ]] ; then
      USER_CONFIG="$VALUE"
    elif [[ "$FLAG" == "skip-install" ]] ; then
      SKIP_INSTALL=true
    elif [[ "$FLAG" == "skip-flash" ]] ; then
      SKIP_FLASH=true
    fi

    LAST_ARG=""  # Mark as consumed
  fi

  shift
done

# The file must be provided as the last arg and only when we are flashing
if [[ -z "$SKIP_FLASH" ]] ; then
  if [[ -z "$LAST_ARG" ]] ; then
      echo "ERROR: A file must be provided to this program as the last arg!"
      exit 1
    elif [[ ! -f "$LAST_ARG" ]]; then
      echo "ERROR: The file \"$LAST_ARG\" does not exist!"
      exit 1
    fi
fi


echo "INFO: Verifying installation of arduino-cli..."
if ! which arduino-cli >> /dev/null ; then

  echo "INFO: Installing arduino-cli"
  if (curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh 2>&1) > >(sed 's/^/      /') ; then
    echo # Blank line
  else
    echo "ERROR: Could not install arduino-cli!"
    exit 1
  fi

  echo "INFO: Creating a config file for the arduino-cli"
  if (arduino-cli config init 2>&1) > >(sed 's/^/      /') ; then
    echo # Blank line
  else
    echo "ERROR: Could not create config file for the arduino-cli!"
    exit 1
  fi

  echo "INFO: Updating arduino-cli lib index"
  if (arduino-cli core update-index 2>&1) > >(sed 's/^/      /') ; then
    echo # Blank line
  else
    echo "ERROR: Could not update arduino-cli lib index!"
    exit 1
  fi

  echo "INFO: Installing NeoPixelBus by Makuna"
  if (arduino-cli lib install "NeoPixelBus by Makuna" 2>&1) > >(sed 's/^/      /') ; then
    echo # Blank line
  else
    echo "ERROR: Could not install NeoPixelBus by Makuna!"
    exit 1
  fi
fi


if [[ "$SKIP_FLASH" != true ]] ; then
  if [[ -n "$USER_CONFIG" ]]; then
    echo "INFO: Using user-provided config"

    VALID_CONFIG_NEEDLE="^(\/dev\/\w+)\|(\w+\:\w+\:\w+)\|(\w+\:\w+)$"
    readarray -d'|' -t SELECTED_BOARD_CONFIG <<< "$( echo "$USER_CONFIG" | \
      sed -En "s/${VALID_CONFIG_NEEDLE}/\1|\2|\3|/p"
    )"

    SELECTED_PORT="${SELECTED_BOARD_CONFIG[0]}"
    SELECTED_FQBN="${SELECTED_BOARD_CONFIG[1]}"
    SELECTED_CORE="${SELECTED_BOARD_CONFIG[2]}"
  else
    echo "INFO: Scanning for boards..."
    if BOARDS="$( (arduino-cli board list 2>&1) | tee >(sed 's/^/      /' > /dev/tty) )" ; then
      VALID_BOARD_NEEDLE="^.*(\/dev\/\w+).*? (\w+\:\w+\:\w+).*? (\w+\:\w+).*$"
      VALID_BOARD_COUNT="$( echo "$BOARDS" | grep -Ec "${VALID_BOARD_NEEDLE}" )"

      # If there were no boards with valid data
      if [[ ${VALID_BOARD_COUNT} -eq 0 ]] ; then
        echo "ERROR: No boards found!"
        exit 1

      # if there is only one board with valid data
      elif [[ ${VALID_BOARD_COUNT} -eq 1 ]] ; then
        BOARD_ID=1

      # If there are multiple boards with valid data
      else
        echo "WARN: Multiple Boards Found!"

        # Print a numbered list of boards
        echo "$BOARDS" | sed -En "s/${VALID_BOARD_NEEDLE}/\2 @ \1/p" | nl -s ') '

        echo # Blank line

        BOARD_ID=""
        while [[ $BOARD_ID -lt 1 || $BOARD_ID -gt ${VALID_BOARD_COUNT} ]] ; do
          read -p "Select a board to use: " -r BOARD_ID
        done

        echo # Blank line
      fi

      # Convert the selected board to an array and save the values we need to vars
      readarray -d'|' -t SELECTED_BOARD_CONFIG <<< "$( echo "$BOARDS" | \
        sed -En "s/${VALID_BOARD_NEEDLE}/\1|\2|\3|/p" | \
        sed -n "${BOARD_ID}p"
      )"

      SELECTED_PORT="${SELECTED_BOARD_CONFIG[0]}"
      SELECTED_FQBN="${SELECTED_BOARD_CONFIG[1]}"
      SELECTED_CORE="${SELECTED_BOARD_CONFIG[2]}"

    else
      echo "ERROR: Could not scan for boards!"
      exit 1
    fi
  fi
fi

if [[ "$SKIP_INSTALL" != true ]] ; then
  echo "INFO: Installing the platform for the board..."
  if (arduino-cli core install "${SELECTED_CORE}" 2>&1) > >(sed 's/^/      /') ; then
    echo # Blank Line
  else
    echo "ERROR: Could not install the platform for the board!"
    exit 1
  fi
else
  echo "SKIP: Installing the platform for the board"
fi

if [[ "$SKIP_FLASH" != true ]] ; then
  echo "INFO: Compiling your code for the board..."
  if (arduino-cli compile --fqbn "${SELECTED_FQBN}" "$1" 2>&1) > >(sed 's/^/      /') ; then
    echo # Blank Line
  else
    echo "ERROR: Could not compile code for the board!"
    exit 1
  fi

  echo "INFO: Uploading your code to the board..."
  if (arduino-cli upload -v -p "${SELECTED_PORT}" --fqbn "${SELECTED_FQBN}" "$1" 2>&1) > >(sed 's/^/      /') ; then
    echo # Blank Line
  else
    echo "ERROR: Could not upload code to the board!"
    exit 1
  fi

  echo "INFO: Success! Next time you can run:"
  echo # Blank Line
  echo "bash $0 --skip-install --config='$SELECTED_PORT|$SELECTED_FQBN|$SELECTED_CORE' $1"
  echo # Blank Line
else
  echo "SKIP: Compiling your code for the board"
  echo "SKIP: Uploading your code to the board"
fi

echo # Blank Line