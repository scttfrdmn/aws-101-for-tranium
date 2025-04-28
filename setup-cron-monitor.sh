#!/bin/bash
# Setup script for Trainium instance monitoring cron job

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/trainium-monitor.sh"
CONFIG_FILE="$HOME/.aws/trainium-workshop.conf"
CRON_INTERVAL=15  # Check every 15 minutes

# Function to display usage information
usage() {
    echo "Setup Trainium Instance Monitoring Cron Job"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  install        Install the monitoring cron job (default)"
    echo "  remove         Remove the monitoring cron job"
    echo ""
    echo "Options:"
    echo "  --interval     Set check interval in minutes (default: 15)"
    echo "  --help         Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 install --interval 30"
    echo "  $0 remove"
    echo ""
}

# Function to remove the cron job
remove_cron() {
    echo "Removing Trainium monitoring cron job..."
    
    # Check if crontab entry exists
    if crontab -l 2>/dev/null | grep -F "$MONITOR_SCRIPT" > /dev/null; then
        # Remove existing cron job
        (crontab -l 2>/dev/null | grep -v "$MONITOR_SCRIPT") | crontab -
        
        if crontab -l 2>/dev/null | grep -F "$MONITOR_SCRIPT" > /dev/null; then
            echo "Error: Failed to remove cron job."
            exit 1
        else
            echo "Cron job removed successfully!"
        fi
    else
        echo "No Trainium monitoring cron job found."
    fi
    
    echo "To manually set MONITOR_OVERRIDE to true instead of removing the cron job:"
    echo "  Edit $CONFIG_FILE and set MONITOR_OVERRIDE=\"true\""
    
    exit 0
}

# Function to install the cron job
install_cron() {
    # Ensure monitor script exists
    if [ ! -f "$MONITOR_SCRIPT" ]; then
        echo "Error: Monitoring script not found at $MONITOR_SCRIPT"
        echo "Please make sure the trainium-monitor.sh file is in the same directory as this script."
        exit 1
    fi

    # Make sure script is executable
    chmod +x "$MONITOR_SCRIPT"

    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Warning: Configuration file not found at $CONFIG_FILE"
        echo "You need to run the trainium.sh setup and start commands first."
        echo "Continue anyway? (y/n)"
        read -r CONTINUE
        if [[ $CONTINUE != "y" && $CONTINUE != "Y" ]]; then
            echo "Setup canceled."
            exit 0
        fi
    fi

    # Create cron job entry
    CRON_ENTRY="*/$CRON_INTERVAL * * * * $MONITOR_SCRIPT > /dev/null 2>&1"

    # Check if crontab entry already exists
    if crontab -l 2>/dev/null | grep -F "$MONITOR_SCRIPT" > /dev/null; then
        echo "Cron job for Trainium monitoring already exists."
        echo "Do you want to update it? (y/n)"
        read -r UPDATE
        if [[ $UPDATE != "y" && $UPDATE != "Y" ]]; then
            echo "Setup canceled."
            exit 0
        fi
        
        # Remove existing cron job
        (crontab -l 2>/dev/null | grep -v "$MONITOR_SCRIPT") | crontab -
    fi

    # Add new cron job
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -

    # Verify cron job was added
    if crontab -l | grep -F "$MONITOR_SCRIPT" > /dev/null; then
        echo "Cron job setup successfully!"
        echo "The script will run every $CRON_INTERVAL minutes to check your Trainium instance."
        echo "Monitoring logs will be saved to $HOME/.aws/trainium-monitor.log"
    else
        echo "Error: Failed to set up cron job."
        exit 1
    fi

    # Add the override flag to config file if it doesn't exist
    if [ -f "$CONFIG_FILE" ] && ! grep -q "MONITOR_OVERRIDE" "$CONFIG_FILE"; then
        echo "# Set to 'true' to disable automatic monitoring" >> "$CONFIG_FILE"
        echo "MONITOR_OVERRIDE=\"false\"" >> "$CONFIG_FILE"
        echo "Added MONITOR_OVERRIDE option to config file."
        echo "To disable monitoring, set MONITOR_OVERRIDE=\"true\" in $CONFIG_FILE"
    fi

    echo ""
    echo "Setup complete! Your Trainium instances will now be monitored automatically."
    echo "If a running instance is idle (CPU and Neuron load below 5%) and no users are logged in,"
    echo "it will be stopped automatically to save costs."
    echo ""
    echo "If users are logged in but the instance is idle, they will receive a warning message."
    echo ""
    echo "To disable monitoring, run: $0 remove"
    echo "Or temporarily disable by editing $CONFIG_FILE and setting MONITOR_OVERRIDE=\"true\""
}

# Default command
COMMAND="install"

# Process command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        install)
            COMMAND="install"
            shift
            ;;
        remove)
            COMMAND="remove"
            shift
            ;;
        --interval)
            CRON_INTERVAL="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Execute the appropriate command
case "$COMMAND" in
    install)
        install_cron
        ;;
    remove)
        remove_cron
        ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac

exit 0
