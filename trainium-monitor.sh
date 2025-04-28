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
    
    # Check CPU utilization using CloudWatch metrics
    CPU_UTIL=$(aws cloudwatch get-metric-statistics \
        --region "$REGION" \
        --namespace AWS/EC2 \
        --metric-name CPUUtilization \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --start-time "$(date -u -v-30M '+%Y-%m-%dT%H:%M:%SZ')" \
        --end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
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
    
    # Check if any users are logged in
    USER_COUNT=$(aws ec2-instance-connect send-serial-console-ssh-public-key \
        --region "$REGION" \
        --instance-id "$INSTANCE_ID" \
        --serial-port 0 \
        --ssh-public-key file://"$HOME/.ssh/${KEY_NAME}.pub" \
        --output text 2>/dev/null || echo "0")
    
    # If CPU utilization is low, take action
    if (( $(echo "$CPU_UTIL < 5.0" | bc -l) )); then
        log "Instance $INSTANCE_ID is idle (CPU < 5%)"
        
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
            # In a real implementation, this would send a message to logged-in users
            # For this workshop, we just log it
        fi
    else
        log "Instance $INSTANCE_ID is active (CPU >= 5%)"
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