#!/bin/bash
# Trainium instance monitoring script
# This script checks and stops idle Trainium instances

CONFIG_FILE="$HOME/.aws/trainium-workshop.conf"
LOG_FILE="$HOME/.aws/trainium-monitor.log"
DEFAULT_REGION="us-west-2"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Function to load configuration
load_config() {
    # Set default region
    REGION="$DEFAULT_REGION"
    MONITOR_OVERRIDE="false"
    
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        log "Configuration loaded from $CONFIG_FILE"
    else
        log "No configuration file found at $CONFIG_FILE, using defaults"
    fi
}

# Check for monitoring override
check_override() {
    if [ "$MONITOR_OVERRIDE" = "true" ]; then
        log "Monitoring is disabled via MONITOR_OVERRIDE in config file"
        exit 0
    fi
}

# Function to check instance status
check_instances() {
    log "Checking for running Trainium instances in $REGION..."
    
    # Get all running Trainium instances
    INSTANCES=$(aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=instance-type,Values=trn1*,trn2*" "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,IP:PublicIpAddress}" \
        --output json)
    
    # Check if there are any running instances
    INSTANCE_COUNT=$(echo "$INSTANCES" | grep -c "ID")
    
    if [ "$INSTANCE_COUNT" -eq 0 ]; then
        log "No running Trainium instances found."
        exit 0
    fi
    
    log "Found $INSTANCE_COUNT running Trainium instance(s)"
    
    # Process each instance
    echo "$INSTANCES" | grep -o '"ID": "[^"]*' | cut -d'"' -f4 | while read -r INSTANCE_ID; do
        check_instance_usage "$INSTANCE_ID"
    done
}

# Function to check SSH connection
check_ssh_connection() {
    local INSTANCE_IP=$1
    local KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"
    
    # Check if key file exists
    if [ ! -f "$KEY_FILE" ]; then
        log "SSH key file $KEY_FILE not found"
        return 1
    fi
    
    # Test SSH connection with timeout
    if timeout 5 ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -i "$KEY_FILE" ubuntu@"$INSTANCE_IP" 'exit' >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check Trainium device activity
check_trainium_activity() {
    local INSTANCE_IP=$1
    local KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"
    
    # Skip if we can't connect via SSH
    if ! check_ssh_connection "$INSTANCE_IP"; then
        log "Cannot connect to instance at $INSTANCE_IP to check Trainium activity"
        return 0  # Return 0 activity
    fi
    
    # Run command to check Trainium usage
    # Using neuron-top in non-interactive mode with a timeout
    NEURON_ACTIVITY=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -i "$KEY_FILE" ubuntu@"$INSTANCE_IP" \
        "source /etc/profile && source activate aws_neuron_pytorch_p310 && timeout 5 neuron-top -n 1 | grep -E 'NeuronCore.*Utilization' | awk '{sum+=\$5} END {print sum/NR}'" 2>/dev/null || echo "0")
    
    # If we got no result or error, default to 0
    if [ -z "$NEURON_ACTIVITY" ] || ! [[ "$NEURON_ACTIVITY" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        NEURON_ACTIVITY=0
    fi
    
    # Return the activity as a float
    echo "$NEURON_ACTIVITY"
}

# Function to check if users are logged in
check_users_logged_in() {
    local INSTANCE_IP=$1
    local KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"
    
    # Skip if we can't connect via SSH
    if ! check_ssh_connection "$INSTANCE_IP"; then
        log "Cannot connect to instance at $INSTANCE_IP to check logged in users"
        return 0  # Assume no users
    fi
    
    # Check number of active user sessions
    USER_COUNT=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 -i "$KEY_FILE" ubuntu@"$INSTANCE_IP" \
        "who | wc -l" 2>/dev/null || echo "0")
    
    # If we got no result or error, default to 0
    if [ -z "$USER_COUNT" ] || ! [[ "$USER_COUNT" =~ ^[0-9]+$ ]]; then
        USER_COUNT=0
    fi
    
    echo "$USER_COUNT"
}

# Function to check instance usage
check_instance_usage() {
    local INSTANCE_ID=$1
    
    log "Checking usage for instance $INSTANCE_ID..."
    
    # Get instance info
    INSTANCE_IP=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query "Reservations[0].Instances[0].PublicIpAddress" \
        --output text)
    
    if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" = "None" ]; then
        log "Instance $INSTANCE_ID does not have a public IP address"
        return
    fi
    
    # Check CPU utilization using CloudWatch metrics
    # Get timestamps in a cross-platform compatible way
    END_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    # Get time 30 minutes ago (compatible with both macOS and Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS date command
        START_TIME=$(date -u -v-30M '+%Y-%m-%dT%H:%M:%SZ')
    else
        # Linux date command
        START_TIME=$(date -u -d '30 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')
    fi
    
    CPU_UTIL=$(aws cloudwatch get-metric-statistics \
        --region "$REGION" \
        --namespace AWS/EC2 \
        --metric-name CPUUtilization \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --start-time "$START_TIME" \
        --end-time "$END_TIME" \
        --period 300 \
        --statistics Average \
        --query "Datapoints[0].Average" \
        --output text)
    
    if [ -z "$CPU_UTIL" ] || [ "$CPU_UTIL" = "None" ]; then
        CPU_UTIL=0
    fi
    
    # Round to 2 decimal places
    CPU_UTIL=$(printf "%.2f" "$CPU_UTIL")
    
    log "Instance $INSTANCE_ID CPU utilization: $CPU_UTIL%"
    
    # Check Trainium device activity
    TRAINIUM_UTIL=$(check_trainium_activity "$INSTANCE_IP")
    TRAINIUM_UTIL=$(printf "%.2f" "$TRAINIUM_UTIL")
    
    log "Instance $INSTANCE_ID Trainium utilization: $TRAINIUM_UTIL%"
    
    # Check if any users are logged in
    USER_COUNT=$(check_users_logged_in "$INSTANCE_IP")
    
    log "Instance $INSTANCE_ID has $USER_COUNT active user sessions"
    
    # If both CPU and Trainium utilization are low, take action
    if (( $(echo "$CPU_UTIL < 5.0" | bc -l) )) && (( $(echo "$TRAINIUM_UTIL < 5.0" | bc -l) )); then
        log "Instance $INSTANCE_ID is idle (CPU < 5% and Trainium < 5%)"
        
        if [ "$USER_COUNT" -eq 0 ]; then
            # No users logged in, stop the instance
            log "No users logged in. Stopping instance $INSTANCE_ID..."
            aws ec2 stop-instances \
                --region "$REGION" \
                --instance-ids "$INSTANCE_ID"
            
            log "Instance $INSTANCE_ID is being stopped. To restart it, run: ./trainium.sh start"
        else
            # Users are logged in, send warning
            log "Users are logged in. Sending warning..."
            # Send message to all terminals
            ssh -o StrictHostKeyChecking=no -o BatchMode=yes -i "$HOME/.ssh/${KEY_NAME}.pem" ubuntu@"$INSTANCE_IP" \
                "echo -e '\n\n*** WARNING: This instance appears to be idle. It will be automatically stopped if idle for 30 more minutes. ***\n' | wall" || true
        fi
    else
        log "Instance $INSTANCE_ID is active (CPU: $CPU_UTIL%, Trainium: $TRAINIUM_UTIL%)"
    fi
}

# Main function
main() {
    log "Starting Trainium instance monitoring..."
    
    # Load configuration
    load_config
    
    # Check for override
    check_override
    
    # Check instances
    check_instances
    
    log "Monitoring complete."
}

# Run the main function
main