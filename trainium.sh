#!/bin/bash
# AWS Trainium Instance Management Scripts
# This collection of scripts helps manage Trainium instances for the workshop

# Configuration file path
CONFIG_FILE="$HOME/.aws/trainium-workshop.conf"

# Default values - these will be overridden by config file if it exists
DEFAULT_REGION="us-west-2"
DEFAULT_INSTANCE_TYPE="trn1.2xlarge"
DEFAULT_SECURITY_GROUP_NAME="trainium-workshop-sg"
DEFAULT_KEY_NAME="trainium-workshop-key"

# Set initial values to defaults
REGION="$DEFAULT_REGION"
INSTANCE_TYPE="$DEFAULT_INSTANCE_TYPE"
SECURITY_GROUP_NAME="$DEFAULT_SECURITY_GROUP_NAME"
KEY_NAME="$DEFAULT_KEY_NAME"

# Create directories if they don't exist
mkdir -p "$HOME/.aws"
mkdir -p "$HOME/.ssh"

# Function to display usage information
usage() {
    echo "AWS Trainium Instance Management"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  setup         Create security group, key pair, and config file"
    echo "  start         Launch a new Trainium instance"
    echo "  stop          Stop a running Trainium instance"
    echo "  terminate     Terminate a Trainium instance"
    echo "  status        Check status of Trainium instance(s)"
    echo "  connect       SSH to the Trainium instance"
    echo "  help          Display this help message"
    echo ""
    echo "Options:"
    echo "  --region      AWS region (default: us-west-2)"
    echo "  --type        Instance type (default: trn1.2xlarge)"
    echo "  --ami         Specific AMI ID (optional)"
    echo "  --id          Instance ID (for stop/terminate/status commands)"
    echo ""
    echo "Example:"
    echo "  $0 setup"
    echo "  $0 start"
    echo "  $0 stop"
    echo "  $0 terminate"
    echo "  $0 status"
    echo "  $0 connect"
    echo "  $0 start --region us-east-1 --type trn1.32xlarge"
    echo ""
}

# Function to load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        echo "Configuration loaded from $CONFIG_FILE"
    else
        echo "No configuration file found at $CONFIG_FILE"
        echo "Using default values for configuration. Will create config file with defaults."
        # Create a config file with default values
        {
            echo "# AWS Trainium Workshop Configuration"
            echo "# Created on $(date)"
            echo "REGION=\"$DEFAULT_REGION\""
            echo "INSTANCE_TYPE=\"$DEFAULT_INSTANCE_TYPE\""
            echo "SECURITY_GROUP_NAME=\"$DEFAULT_SECURITY_GROUP_NAME\""
            echo "KEY_NAME=\"$DEFAULT_KEY_NAME\""
            echo "# The following values will be populated by the setup command"
            echo "SECURITY_GROUP_ID=\"\""
            echo "KEY_FILE=\"\""
            echo "INSTANCE_ID=\"\""
            echo "PUBLIC_IP=\"\""
            echo "AMI_ID=\"\""
        } > "$CONFIG_FILE"
        echo "Created configuration file with default values at $CONFIG_FILE"
    fi
}

# Function to save configuration to file
save_config() {
    {
        echo "# AWS Trainium Workshop Configuration"
        echo "# Created on $(date)"
        echo "REGION=\"$REGION\""
        echo "INSTANCE_TYPE=\"$INSTANCE_TYPE\""
        echo "SECURITY_GROUP_ID=\"$SECURITY_GROUP_ID\""
        echo "SECURITY_GROUP_NAME=\"$SECURITY_GROUP_NAME\""
        echo "KEY_NAME=\"$KEY_NAME\""
        echo "KEY_FILE=\"$KEY_FILE\""
        echo "INSTANCE_ID=\"$INSTANCE_ID\""
        echo "PUBLIC_IP=\"$PUBLIC_IP\""
        echo "AMI_ID=\"$AMI_ID\""
    } > "$CONFIG_FILE"
    
    echo "Configuration saved to $CONFIG_FILE"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        echo "AWS CLI not found. Please install AWS CLI first."
        echo "See: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    # Check if AWS CLI is configured
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "AWS CLI not configured. Please run 'aws configure' first."
        exit 1
    fi
}

# Function to check quota and availability of Trainium instances
check_trainium_availability() {
    echo "Checking Trainium availability in $REGION..."
    
    # Check if instance type is available in the region
    AVAILABILITY=$(aws ec2 describe-instance-type-offerings \
        --region "$REGION" \
        --location-type region \
        --filters "Name=instance-type,Values=$INSTANCE_TYPE" \
        --query "length(InstanceTypeOfferings)" \
        --output text)
    
    if [ "$AVAILABILITY" -eq 0 ]; then
        echo "Error: $INSTANCE_TYPE is not available in $REGION"
        echo "Available regions for Trainium instances typically include: us-east-1, us-west-2"
        exit 1
    fi
    
    echo "$INSTANCE_TYPE is available in $REGION"
}

# Function to set up workshop environment
setup_environment() {
    check_aws_cli
    
    echo "Setting up Trainium workshop environment in $REGION..."
    
    # Check Trainium availability
    check_trainium_availability
    
    # Create key pair if it doesn't exist
    echo "Creating key pair $KEY_NAME if it doesn't exist..."
    KEY_FILE="$HOME/.ssh/${KEY_NAME}.pem"
    
    if aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" &> /dev/null; then
        echo "Key pair $KEY_NAME already exists"
    else
        if aws ec2 create-key-pair \
            --region "$REGION" \
            --key-name "$KEY_NAME" \
            --query "KeyMaterial" \
            --output text > "$KEY_FILE"; then
            
            chmod 400 "$KEY_FILE"
            echo "Key pair created and saved to $KEY_FILE"
        else
            echo "Error creating key pair"
            exit 1
        fi
    fi
    
    # Create security group if it doesn't exist
    echo "Creating security group $SECURITY_GROUP_NAME if it doesn't exist..."
    
    if aws ec2 describe-security-groups --region "$REGION" --group-names "$SECURITY_GROUP_NAME" &> /dev/null; then
        echo "Security group $SECURITY_GROUP_NAME already exists"
        SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
            --region "$REGION" \
            --group-names "$SECURITY_GROUP_NAME" \
            --query "SecurityGroups[0].GroupId" \
            --output text)
    else
        if SECURITY_GROUP_ID=$(aws ec2 create-security-group \
            --region "$REGION" \
            --group-name "$SECURITY_GROUP_NAME" \
            --description "Security group for Trainium workshop" \
            --query "GroupId" \
            --output text); then
            
            echo "Security group created with ID: $SECURITY_GROUP_ID"
            
            # Get your public IP
            MY_IP=$(curl -s https://checkip.amazonaws.com)
            echo "Your public IP address is: $MY_IP (SSH access will be restricted to this IP only)"
            
            # Add SSH ingress rule restricted to your IP only
            aws ec2 authorize-security-group-ingress \
                --region "$REGION" \
                --group-id "$SECURITY_GROUP_ID" \
                --protocol tcp \
                --port 22 \
                --cidr "$MY_IP/32"
            
            echo "Added SSH ingress rule for IP $MY_IP/32 only (restricted access)"
            echo "Note: If your IP address changes, you'll need to update the security group rule."
        else
            echo "Error creating security group"
            exit 1
        fi
    fi
    
    # Find latest Neuron DLAMI
    echo "Finding latest Neuron DLAMI..."
    AMI_ID=$(aws ec2 describe-images \
        --region "$REGION" \
        --owners amazon \
        --filters "Name=name,Values=*Deep Learning Neuron AMI (Ubuntu 20.04)*" \
        --query "sort_by(Images, &CreationDate)[-1].ImageId" \
        --output text)
    
    if [ -z "$AMI_ID" ] || [ "$AMI_ID" = "None" ]; then
        echo "Error: Could not find Neuron DLAMI"
        exit 1
    fi
    
    echo "Found latest Neuron DLAMI: $AMI_ID"
    
    # Save configuration
    save_config
    
    echo "Setup complete! You can now run './trainium.sh start' to launch an instance."
}

# Function to start a Trainium instance
start_instance() {
    check_aws_cli
    load_config
    
    echo "Starting a new $INSTANCE_TYPE instance in $REGION..."
    
    # Launch instance
    if ! INSTANCE_DETAILS=$(aws ec2 run-instances \
        --region "$REGION" \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --count 1 \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SECURITY_GROUP_ID" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=TrainiumWorkshop}]" \
        --output json); then
        
        echo "Error launching instance"
        exit 1
    fi
    
    # Extract instance ID
    INSTANCE_ID=$(echo "$INSTANCE_DETAILS" | grep -o '"InstanceId": "[^"]*' | cut -d'"' -f4)
    
    echo "Launched instance with ID: $INSTANCE_ID"
    echo "Waiting for instance to reach running state..."
    
    # Wait for instance to be running
    aws ec2 wait instance-running \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID"
    
    # Get public IP
    PUBLIC_IP=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query "Reservations[0].Instances[0].PublicIpAddress" \
        --output text)
    
    echo "Instance is now running!"
    echo "Instance ID: $INSTANCE_ID"
    echo "Public IP: $PUBLIC_IP"
    echo "To connect: ssh -i $KEY_FILE ubuntu@$PUBLIC_IP"
    
    # Save configuration
    save_config
}

# Function to stop a Trainium instance
stop_instance() {
    check_aws_cli
    load_config
    
    if [ -z "$INSTANCE_ID" ]; then
        echo "No instance ID found in configuration."
        echo "Please specify an instance ID with --id or start an instance first."
        exit 1
    fi
    
    echo "Stopping instance $INSTANCE_ID in $REGION..."
    
    # Stop the instance
    if ! aws ec2 stop-instances \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID"; then
        
        echo "Error stopping instance"
        exit 1
    fi
    
    echo "Instance is being stopped. This may take a few minutes."
    echo "To start it again, run './trainium.sh start' with the same configuration."
}

# Function to terminate a Trainium instance
terminate_instance() {
    check_aws_cli
    load_config
    
    if [ -z "$INSTANCE_ID" ]; then
        echo "No instance ID found in configuration."
        echo "Please specify an instance ID with --id."
        exit 1
    fi
    
    echo "WARNING: This will permanently delete instance $INSTANCE_ID."
    echo -n "Are you sure you want to continue? (y/n): "
    read -r CONFIRM
    
    if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
        echo "Termination canceled."
        exit 0
    fi
    
    echo "Terminating instance $INSTANCE_ID in $REGION..."
    
    # Terminate the instance
    if ! aws ec2 terminate-instances \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID"; then
        
        echo "Error terminating instance"
        exit 1
    fi
    
    echo "Instance is being terminated. This may take a few minutes."
    
    # Remove instance ID from configuration
    INSTANCE_ID=""
    PUBLIC_IP=""
    save_config
}

# Function to check instance status
check_status() {
    check_aws_cli
    load_config
    
    if [ -z "$INSTANCE_ID" ]; then
        echo "No instance ID found in configuration."
        echo "Listing all Trainium instances in $REGION:"
        
        aws ec2 describe-instances \
            --region "$REGION" \
            --filters "Name=instance-type,Values=trn1*" \
            --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" \
            --output table
    else
        echo "Checking status of instance $INSTANCE_ID in $REGION..."
        
        aws ec2 describe-instances \
            --region "$REGION" \
            --instance-ids "$INSTANCE_ID" \
            --query "Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" \
            --output table
    fi
}

# Function to connect to instance via SSH
connect_instance() {
    load_config
    
    if [ -z "$INSTANCE_ID" ] || [ -z "$PUBLIC_IP" ]; then
        echo "No instance details found in configuration."
        exit 1
    fi
    
    # Check instance state
    STATE=$(aws ec2 describe-instances \
        --region "$REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query "Reservations[0].Instances[0].State.Name" \
        --output text)
    
    if [ "$STATE" != "running" ]; then
        echo "Instance is not running (current state: $STATE)"
        echo "Please start the instance first with './trainium.sh start'"
        exit 1
    fi
    
    echo "Connecting to instance $INSTANCE_ID at $PUBLIC_IP..."
    ssh -i "$KEY_FILE" ubuntu@"$PUBLIC_IP"
}

# Parse command-line arguments
COMMAND="$1"
shift

# Process options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --region)
            REGION="$2"
            shift 2
            ;;
        --type)
            INSTANCE_TYPE="$2"
            shift 2
            ;;
        --ami)
            AMI_ID="$2"
            shift 2
            ;;
        --id)
            INSTANCE_ID="$2"
            shift 2
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
    setup)
        setup_environment
        ;;
    start)
        start_instance
        ;;
    stop)
        stop_instance
        ;;
    terminate)
        terminate_instance
        ;;
    status)
        check_status
        ;;
    connect)
        connect_instance
        ;;
    help)
        usage
        ;;
    *)
        echo "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac

exit 0
