# AWS 101 for Trainium Development Workshop

## Introduction

This hands-on workshop helps you get started with AWS Trainium instances for machine learning development. AWS Trainium is a custom ML accelerator chip designed by AWS specifically for training deep learning models with high performance and cost efficiency. By the end of this one-hour session, you'll be able to set up a secure AWS environment, launch Trainium instances, and run basic ML workloads.

### What You'll Accomplish

By completing this workshop, you will:
- Create and secure an AWS environment for ML development
- Launch and connect to a Trainium instance
- Run your first ML workload on AWS Trainium
- Learn how to manage instances to control costs
- Set up a remote development environment

> **Note**: This guide is updated for April 2025 with the latest AWS Neuron SDK (version 2.22.0) and supports both Trn1 and the newer Trn2 instances.

## Prerequisites

- A laptop with internet connection
- An AWS account (new or existing) with appropriate permissions to create IAM users, EC2 instances, and security groups
- Basic familiarity with command line interfaces (Bash for Linux/macOS or PowerShell for Windows)
- Basic knowledge of Python and PyTorch (for the ML examples)
- Understanding of SSH for connecting to remote instances

If you're new to AWS, review the [AWS Getting Started Guide](https://aws.amazon.com/getting-started/) before beginning this workshop.

---

## Workshop Outline

1. [Setting Up Your AWS Environment](#1-setting-up-your-aws-environment)
2. [Configuring Budget Alerts](#2-configuring-budget-alerts)
3. [Installing and Configuring AWS Command Line Interface (CLI)](#3-installing-and-configuring-aws-cli)
4. [Launching a Trainium Instance](#4-launching-a-trainium-instance)
5. [Connecting to Your Instance](#5-connecting-to-your-instance)
6. [Setting Up Remote Development](#6-setting-up-remote-development)
7. [Hello World on Trainium](#7-hello-world-on-trainium)
8. [Instance Management](#8-instance-management)
9. [Cleanup and Best Practices](#9-cleanup-and-best-practices)
10. [Additional Resources](#10-additional-resources)
11. [Trainium Management Script](#11-trainium-management-script)
12. [Common Troubleshooting and Next Steps](#12-common-troubleshooting-and-next-steps)

> **Important**: This workshop uses the **US West (Oregon)** region (`us-west-2`), which supports Trainium instances. If you need to use a different region, first verify that it supports Trainium instances using the commands provided in section 4.

> **Note on Placeholders**: Throughout this guide, you'll see placeholder values like `<your-instance-ip>` or AMI IDs like `ami-0123456789abcdef`. These are just examples and must be replaced with your actual values. **Never use placeholder AMI IDs in actual commands**.

> **Quick Reference Card**: A single-page summary of key commands used in this workshop is available in the [Appendices](#appendices) section.

---

## 1. Setting Up Your AWS Environment

### Creating an IAM User

For security best practices, you should use an IAM user instead of your root account. This creates a user with limited permissions specific to the workshop needs:

1. Sign in to the [AWS Management Console](https://console.aws.amazon.com/) using your root credentials
2. Navigate to the IAM service (search for "IAM" in the top search bar)
3. In the left navigation panel, click "Users" and then "Create user"
4. Name your user (e.g., "trainium-workshop-user") and click "Next"
5. Select "Attach policies directly" and create a custom policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "s3:*",
                "cloudwatch:*",
                "budgets:*",
                "pricing:*"
            ],
            "Resource": "*"
        }
    ]
}
```

> **Note**: In a production environment, you would use more restrictive permissions following the principle of least privilege. This policy is simplified for workshop purposes.

6. Click "Next" and then "Create user"

### Creating Access Keys for CLI

1. From the IAM dashboard, select your newly created user
2. Go to the "Security credentials" tab
3. Under "Access keys", click "Create access key"
4. Select "Command Line Interface (CLI)" as your use case
5. (Optional) Add a tag for better tracking (e.g., Key: Purpose, Value: TrainiumWorkshop)
6. Click "Create access key"
7. **IMPORTANT**: Download the .csv file or copy your Access Key ID and Secret Access Key - you won't be able to access the secret again!

### Creating a Key Pair for SSH

1. Navigate to EC2 in the AWS Console
2. In the left navigation panel, under "Network & Security", select "Key Pairs"
3. Click "Create key pair"
4. Name your key (e.g., "trainium-workshop-key")
5. For key pair type, choose "RSA"
6. For private key format: 
   - For macOS/Linux users: Choose .pem
   - For Windows users: Choose .ppk if using PuTTY, or .pem if using OpenSSH
7. Click "Create key pair" and save the file securely (usually in `~/.ssh/` directory)
8. Change permissions (for .pem on macOS/Linux):
   ```bash
   chmod 400 ~/.ssh/trainium-workshop-key.pem
   ```

> **Tips**:
> - Save this key in a secure location, as you'll need it to connect to your instances
> - If you lose this key, you won't be able to connect to your instances and will need to create new ones
> - Never share your private key with others

---

## 2. Configuring Budget Alerts

### Using the Console

1. Go to the [AWS Billing Dashboard](https://console.aws.amazon.com/billing/)
2. In the left navigation pane, click "Budgets"
3. Click "Create budget"
4. Select "Cost budget" and click "Next"
5. Configure your budget:
   - Name: "TrainiumWorkshopBudget"
   - Period: Monthly
   - Budget amount: Set to $1,500 (or your desired amount)
6. Set up alerts at 25%, 50%, 75%, and 90% thresholds
7. Add your email address as a notification recipient
8. Review and click "Create budget"

---

## 3. Installing and Configuring AWS CLI

The AWS Command Line Interface (CLI) allows you to interact with AWS services from the terminal. This section covers installation and setup for different operating systems.

### For macOS

#### Using Homebrew (recommended)
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install AWS CLI
brew install awscli

# Verify installation
aws --version
```

#### Using the official installer
```bash
# Download the installer
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"

# Install the package
sudo installer -pkg AWSCLIV2.pkg -target /

# Verify installation
aws --version
```

### For Windows using WSL (Recommended)

Windows Subsystem for Linux (WSL) provides a Linux environment that works better with developer tools:

1. Install WSL by opening PowerShell as Administrator and running:
```powershell
wsl --install
```

2. Once installed and rebooted, open the Ubuntu terminal from your Start menu
3. Update your Linux distribution:
```bash
sudo apt update && sudo apt upgrade -y
```

4. Install AWS CLI in WSL:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt-get install unzip
unzip awscliv2.zip
sudo ./aws/install
```

5. Verify installation:
```bash
aws --version
```

6. Your WSL environment will now behave like Linux for all AWS CLI commands in this guide

### For Windows (Native - Alternative)

If you prefer not to use WSL:

1. Download the MSI installer: [AWS CLI MSI Installer for Windows](https://awscli.amazonaws.com/AWSCLIV2.msi)
2. Run the downloaded MSI file and follow installation prompts
3. Open Command Prompt or PowerShell to verify installation:
```
aws --version
```

### Configuring the AWS CLI

After installing the AWS CLI, you need to configure it with your AWS credentials:

1. Open a terminal (or Command Prompt/PowerShell on Windows)
2. Run the following command:

```bash
aws configure
```

3. You'll be prompted to enter the following information:
   - AWS Access Key ID: [Enter your access key]
   - AWS Secret Access Key: [Enter your secret key]
   - Default region name: us-west-2
   - Default output format: json

4. If you don't have access keys yet, create them in the IAM service after creating your IAM user (see Section 1)

5. Verify your configuration:
```bash
aws sts get-caller-identity
```

6. You should see output similar to:
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/trainium-workshop-user"
}
```

7. Create a credentials file backup (optional but recommended):
```bash
# For macOS/Linux/WSL
cp ~/.aws/credentials ~/.aws/credentials.backup

# For Windows (PowerShell)
Copy-Item -Path "$env:USERPROFILE\.aws\credentials" -Destination "$env:USERPROFILE\.aws\credentials.backup"
```

### Using the AWS CLI for Budget Alerts

Now that you have the AWS CLI installed, you can also create budget alerts and check your credit balance using the command line:

To create a budget alert, first create the required JSON files:

Create `budget.json`:
```json
{
    "BudgetName": "TrainiumWorkshopBudget",
    "BudgetLimit": {
        "Amount": "1500",
        "Unit": "USD"
    },
    "BudgetType": "COST",
    "TimeUnit": "MONTHLY"
}
```

Create `notifications.json`:
```json
[
    {
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 50.0,
            "ThresholdType": "PERCENTAGE",
            "NotificationState": "ALARM"
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "your-email@example.com"
            }
        ]
    }
]
```

Then run the create-budget command:

```bash
aws budgets create-budget \
    --account-id $(aws sts get-caller-identity --query 'Account' --output text) \
    --budget file://budget.json \
    --notifications-with-subscribers file://notifications.json
```

### Checking AWS Cost and Usage

To check your AWS current month spending using the CLI:

```bash
# For Linux:
aws ce get-cost-and-usage \
    --time-period Start=$(date -d "first day of this month" +%Y-%m-%d),End=$(date -d "tomorrow" +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --output table

# For macOS:
aws ce get-cost-and-usage \
    --time-period Start=$(date -v1d +%Y-%m-%d),End=$(date -v+1d +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --output table
```

To check how many AWS credits you've used this month:

```bash
# For Linux:
aws ce get-cost-and-usage \
    --time-period Start=$(date -d "first day of this month" +%Y-%m-%d),End=$(date -d "tomorrow" +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --filter '{"Dimensions": {"Key": "RECORD_TYPE", "Values": ["Credit"]}}' \
    --output table

# For macOS:
aws ce get-cost-and-usage \
    --time-period Start=$(date -v1d +%Y-%m-%d),End=$(date -v+1d +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --filter '{"Dimensions": {"Key": "RECORD_TYPE", "Values": ["Credit"]}}' \
    --output table
```

### Checking Your Remaining AWS Credit Balance

To check your remaining AWS credit balance (how many credits you have left):

1. Log into the [AWS Management Console](https://console.aws.amazon.com/)
2. Navigate to "Billing and Cost Management" dashboard
3. Select "Credits" from the left navigation pane
4. Here you can view:
   - Available credits
   - Remaining balances
   - Expiration dates
   - Which services each credit applies to

> **Note**: There is currently no AWS CLI command to directly check remaining credit balances.

---

## 4. Launching a Trainium Instance

### Checking EC2 Instance Quotas

Before attempting to launch any instances, check your account's service quotas to ensure you have access to Trainium instances:

```bash
# Check your current Trainium instance limits
aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-2E30FD7D \
    --region us-east-1

# Check your On-Demand instance limits (alternative method)
aws ec2 describe-instance-type-offerings \
    --location-type availability-zone \
    --filters Name=instance-type,Values=trn1.2xlarge \
    --region us-east-1 \
    --output table
```

If the output shows that Trainium instances are available but your quota is 0, you'll need to request a quota increase:

1. Go to the [Service Quotas Console](https://console.aws.amazon.com/servicequotas/)
2. Select "Amazon Elastic Compute Cloud (Amazon EC2)"
3. Search for "Running On-Demand Trn1 instances"
4. Click "Request quota increase" and follow the prompts

You can also use this CLI command to check quotas for any instance type:

```bash
# Replace c5.large with any instance type you want to check
aws ec2 describe-instance-type-offerings \
    --location-type availability-zone \
    --filters Name=instance-type,Values=c5.large \
    --region us-east-1 \
    --output table
```

### Understanding Trainium Instance Types

AWS Trainium is designed for cost-effective training of machine learning models. This workshop supports both generation 1 and 2 Trainium instances:

#### Trn1 Instances (First Generation)
- **trn1.2xlarge**: Entry-level instance with 1 AWS Trainium chip (2 NeuronCores)
- **trn1.32xlarge**: High-capacity instance with 16 AWS Trainium chips (32 NeuronCores)
- **trn1n.32xlarge**: Enhanced networking variant with 1600 Gbps of EFA bandwidth

#### Trn2 Instances (Second Generation - Released 2024)
- **trn2.2xlarge**: Entry-level Trainium2 instance
- **trn2.48xlarge**: High-capacity instance with 16 Trainium2 chips
- **Trn2 UltraServer**: A cluster of four Trn2 instances with 64 interconnected Trainium2 chips

For this workshop, we'll use the smallest instance type (`trn1.2xlarge`) which is ideal for learning and experimentation.

### AWS Trainium Regional Availability

As of early 2025, AWS Trainium instances are available in a limited number of regions. Before attempting to launch instances, confirm availability:

```bash
# Check if Trainium is available in your current region
aws ec2 describe-instance-type-offerings \
    --location-type region \
    --filters Name=instance-type,Values=trn1.2xlarge \
    --output table
```

According to AWS documentation, Trainium instances are primarily available in:
- US East (N. Virginia) - us-east-1
- US West (Oregon) - us-west-2
- US East (Ohio) - us-east-2 (newer availability)

If planning to use a different region, check availability before proceeding.

### Finding the Right AMI

⚠️ **CRITICAL WARNING: NEVER USE PLACEHOLDER AMI IDs IN ACTUAL COMMANDS** ⚠️

AWS Deep Learning AMIs (DLAMI) come pre-configured with ML frameworks:

```bash
# Find the latest Neuron DLAMI for Trainium
# As of April 2025, look for Ubuntu 22.04 DLAMIs which support both Trn1 and Trn2
aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=*Neuron*Ubuntu*22.04*" \
    --query "sort_by(Images, &CreationDate)[-1].[ImageId,Name,Description]" \
    --output table

# If no Ubuntu 22.04 DLAMI is found, fall back to Ubuntu 20.04 DLAMIs
aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=*Neuron*Ubuntu*20.04*" \
    --query "sort_by(Images, &CreationDate)[-1].[ImageId,Name,Description]" \
    --output table
```

> **Note**: As of 2025, AWS is phasing out Ubuntu 20.04 DLAMIs, so it's recommended to use Ubuntu 22.04 DLAMIs when possible, especially for Trn2 instances.

**IMPORTANT: You must use the actual AMI ID from the output above.** It will look something like `ami-0abcdef1234567890`, but with real values.

To save the AMI ID to a variable for easy use in the next steps (RECOMMENDED):

```bash
# Save the AMI ID to a variable (this will find and store the actual ID automatically)
export NEURON_AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=*Neuron*Ubuntu*22.04*" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text)

# VERIFY that the AMI ID was captured correctly - THIS IS IMPORTANT!
echo "Using AMI: $NEURON_AMI_ID"

# If the output is empty or says "None", try the Ubuntu 20.04 version:
if [ -z "$NEURON_AMI_ID" ] || [ "$NEURON_AMI_ID" = "None" ]; then
    export NEURON_AMI_ID=$(aws ec2 describe-images \
        --owners amazon \
        --filters "Name=name,Values=*Neuron*Ubuntu*20.04*" \
        --query "sort_by(Images, &CreationDate)[-1].ImageId" \
        --output text)
    echo "Using Ubuntu 20.04 AMI instead: $NEURON_AMI_ID"
fi
```

Alternatively, you can search for the Hugging Face Neuron Deep Learning AMI in the AWS Marketplace, which comes pre-configured for Trainium workloads.

### Creating a Security Group

Security best practice: We'll create a security group that only allows SSH access from your current IP address:

```bash
# Create a security group for Trainium instances
aws ec2 create-security-group \
    --group-name trainium-workshop-sg \
    --description "Security group for Trainium workshop" \
    --output json

# Get your public IP to restrict SSH access (security best practice)
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "Your public IP: $MY_IP (SSH access will be restricted to this IP only)"

# Allow SSH access from your IP only for better security
aws ec2 authorize-security-group-ingress \
    --group-name trainium-workshop-sg \
    --protocol tcp \
    --port 22 \
    --cidr $MY_IP/32
```

> **Security Note**: The above command restricts SSH access to your current public IP address only (`$MY_IP/32`). If your IP address changes (e.g., connecting from a different network), you'll need to update the security group rule by running these commands:
> 
> ```bash
> # Get your new public IP address
> NEW_IP=$(curl -s https://checkip.amazonaws.com)
> echo "Your new public IP: $NEW_IP"
> 
> # First, get your security group ID
> SG_ID=$(aws ec2 describe-security-groups \
>     --group-names trainium-workshop-sg \
>     --query "SecurityGroups[0].GroupId" \
>     --output text)
> 
> # Then, add a new rule for your current IP
> aws ec2 authorize-security-group-ingress \
>     --group-id $SG_ID \
>     --protocol tcp \
>     --port 22 \
>     --cidr $NEW_IP/32
> ```

### Launching Your Trainium Instance

⚠️ **CRITICAL WARNING: YOU MUST USE A REAL AMI ID, NOT THE PLACEHOLDER** ⚠️

```bash
# Launch a Trainium instance
# DO NOT USE ami-0123456789abcdef - THIS IS JUST A PLACEHOLDER!
# Use your actual AMI ID from the previous step
aws ec2 run-instances \
    --image-id $NEURON_AMI_ID \
    --instance-type trn1.2xlarge \
    --count 1 \
    --key-name trainium-workshop-key \
    --security-groups trainium-workshop-sg \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=TrainiumWorkshop}]' \
    --output json
```

If you didn't save the AMI ID to the `$NEURON_AMI_ID` variable, you must manually replace it with the actual AMI ID you found in the previous step.

Example of what NOT to do:
- ❌ DO NOT use `--image-id ami-0123456789abcdef` (placeholder)

Example of what TO do:
- ✅ Use `--image-id ami-0abcdef1234567890` (your actual AMI ID)
- ✅ Or use `--image-id $NEURON_AMI_ID` (if you set the variable as instructed)

Save the `InstanceId` from the output for later use:

```bash
# Save the instance ID to a variable
export INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" "Name=instance-state-name,Values=pending,running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text)

# Verify that the instance ID was captured correctly
echo "Instance ID: $INSTANCE_ID"
```

### Creating a Launch Template

Launch templates make it easier to launch instances with the same configuration:

```bash
# Create a launch template
# IMPORTANT: Replace this placeholder with your actual AMI ID
aws ec2 create-launch-template \
    --launch-template-name TrainiumTemplate \
    --version-description "Initial version" \
    --launch-template-data '{
        "ImageId": "'$NEURON_AMI_ID'",
        "InstanceType": "trn1.2xlarge",
        "KeyName": "trainium-workshop-key",
        "SecurityGroupIds": ["'$SECURITY_GROUP_ID'"],
        "TagSpecifications": [
            {
                "ResourceType": "instance",
                "Tags": [
                    {
                        "Key": "Name",
                        "Value": "TrainiumWorkshop"
                    }
                ]
            }
        ]
    }'
```

Note: Make sure you've defined the `$SECURITY_GROUP_ID` and `$NEURON_AMI_ID` variables properly before running this command:

```bash
# Get security group ID
export SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --group-names trainium-workshop-sg \
    --query "SecurityGroups[0].GroupId" \
    --output text)

echo "Security Group ID: $SECURITY_GROUP_ID"
```

To launch an instance using the template:

```bash
aws ec2 run-instances \
    --launch-template LaunchTemplateName=TrainiumTemplate \
    --output json
```

---

## 5. Connecting to Your Instance

### Getting Instance Information

```bash
# Find your instance's public IP
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]" \
    --output table

# Save the public IP address to an environment variable for easier use
export INSTANCE_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

# Verify it was captured correctly
echo "Instance IP: $INSTANCE_IP"

# You can now use $INSTANCE_IP in other commands, like SSH:
# ssh -i ~/.ssh/trainium-workshop-key.pem ubuntu@$INSTANCE_IP
```

### SSH to Your Instance

For macOS/Linux:
```bash
# Using the saved IP variable
ssh -i ~/.ssh/trainium-workshop-key.pem ubuntu@$INSTANCE_IP

# Or directly with the IP address
ssh -i ~/.ssh/trainium-workshop-key.pem ubuntu@<your-instance-ip>
```

For Windows using PowerShell with OpenSSH:
```powershell
# Using the saved IP variable (if you set it in PowerShell)
ssh -i C:\path\to\trainium-workshop-key.pem ubuntu@$env:INSTANCE_IP

# Or directly with the IP address
ssh -i C:\path\to\trainium-workshop-key.pem ubuntu@<your-instance-ip>
```

For Windows using PuTTY:
1. Open PuTTY
2. Enter your instance's IP address in the "Host Name" field
3. Navigate to Connection > SSH > Auth
4. Browse to your .ppk key file
5. Click "Open" to connect

### Copying Files to/from Your Instance (SCP)

To copy a local file to your instance:
```bash
# Using the saved IP variable
scp -i ~/.ssh/trainium-workshop-key.pem /path/to/local/file ubuntu@$INSTANCE_IP:/path/on/remote/machine

# Or directly with the IP address
scp -i ~/.ssh/trainium-workshop-key.pem /path/to/local/file ubuntu@<your-instance-ip>:/path/on/remote/machine
```

To copy a file from your instance to your local machine:
```bash
# Using the saved IP variable
scp -i ~/.ssh/trainium-workshop-key.pem ubuntu@$INSTANCE_IP:/path/on/remote/machine /path/to/local/destination

# Or directly with the IP address
scp -i ~/.ssh/trainium-workshop-key.pem ubuntu@<your-instance-ip>:/path/on/remote/machine /path/to/local/destination
```

---

## 6. Setting Up Remote Development

### Using VSCode Remote Development

Visual Studio Code offers excellent support for remote development on AWS instances. This allows you to work with the Trainium environment as if it were local, with full editor features.

1. Install [Visual Studio Code](https://code.visualstudio.com/) on your local machine
2. Install the "Remote - SSH" extension from the Extensions marketplace
3. Press F1 (or Ctrl+Shift+P), type "Remote-SSH: Connect to Host", and select it
4. For the host, enter: `ubuntu@<your-instance-ip>` (or use `ubuntu@$INSTANCE_IP` if you saved the IP as a variable)
5. Select your private key file when prompted
6. Once connected, VSCode will set up the remote environment (this might take a minute the first time)
7. After connection, open a folder on the remote machine (e.g., `/home/ubuntu`)

For more convenient connection, add this to your local SSH config file (`~/.ssh/config` on macOS/Linux or `C:\Users\<username>\.ssh\config` on Windows):

```
Host trainium-workshop
    HostName <your-instance-ip>
    User ubuntu
    IdentityFile ~/.ssh/trainium-workshop-key.pem
```

Then you can simply connect using "trainium-workshop" as the host in VSCode.

### Setting Up Python Environment

After connecting to your instance, open a terminal in VSCode and run:

```bash
# Verify Python installation (should be pre-installed in the DLAMI)
python --version

# Create a virtual environment for your project work (separate from the AWS Neuron environments)
python -m venv ~/trainium-project-env

# Activate the environment
source ~/trainium-project-env/bin/activate

# Install some basic packages you might need
pip install numpy matplotlib pandas jupyter

# Check pre-installed Neuron packages (don't install these in your environment - use the AWS ones)
pip list | grep neuron
```

### Setting Up Jupyter for Remote Development

If you prefer to work with Jupyter notebooks:

1. On the Trainium instance, install Jupyter if needed:
```bash
# Activate the Neuron PyTorch environment
source activate aws_neuron_pytorch_p310

# Install Jupyter if it isn't already installed
pip install jupyter
```

2. Start the Jupyter server with remote access:
```bash
# Start Jupyter with remote access allowed and no browser
jupyter notebook --no-browser --port=8888 --ip=0.0.0.0
```

3. On your local machine, set up an SSH tunnel:
```bash
# Replace <your-instance-ip> with your actual instance IP
ssh -i ~/.ssh/trainium-workshop-key.pem -N -L 8888:localhost:8888 ubuntu@<your-instance-ip>
```

4. Open a browser on your local machine and navigate to:
```
http://localhost:8888
```

5. Enter the token shown in the terminal where you started Jupyter on the remote instance

This setup allows you to develop using either VSCode or Jupyter notebooks, depending on your preference.

---

## 7. Hello World on Trainium

### Setting Up the Neuron Environment

The DLAMI should have the Neuron SDK pre-installed, but let's activate the right environment:

```bash
# Activate the Neuron environment for PyTorch (use the latest available environment)
source activate aws_neuron_pytorch_p310

# Verify Neuron installations
neuron-ls
```

You should see output similar to:
```
instance-type: trn1.2xlarge
instance-id: i-0123456789abcdef
+--------+--------+--------+---------+
| NEURON | NEURON | NEURON | PCI     |
| DEVICE | CORES  | MEMORY | BDF     |
+--------+--------+--------+---------+
| 0      | 2      | 32 GB  | 00:1e.0 |
+--------+--------+--------+---------+
```

> **Note**: As of April 2025, the Neuron SDK supports PyTorch 2.5 and has deprecated PyTorch 1.13 and 2.1. Python 3.8 support is also being phased out in favor of Python 3.9+.

### Simple PyTorch Example for Trainium

Create a file called `hello_trainium.py`:

```python
import torch
import torch_neuronx

# Simple example: matrix multiplication
def hello_trainium():
    # Create random matrices
    matrix_a = torch.randn(128, 256)
    matrix_b = torch.randn(256, 128)
    
    # Define a simple neural network module
    class SimpleNetwork(torch.nn.Module):
        def forward(self, x, y):
            return torch.matmul(x, y)
    
    # Create a model instance
    model = SimpleNetwork()
    
    # Prepare example inputs
    example_inputs = (matrix_a, matrix_b)
    
    # Compile the model for Neuron (Trainium)
    neuron_model = torch_neuronx.trace(model, example_inputs)
    
    # Run inference
    result = neuron_model(*example_inputs)
    
    # Validate
    expected_result = torch.matmul(matrix_a, matrix_b)
    match = torch.allclose(result, expected_result, rtol=1e-3, atol=1e-3)
    
    print(f"Hello Trainium! Matrix multiplication {'succeeded' if match else 'failed'}.")
    print(f"Result shape: {result.shape}")
    
    return result

if __name__ == "__main__":
    hello_trainium()
```

Run the example:
```bash
python hello_trainium.py
```

You should see output like:
```
Hello Trainium! Matrix multiplication succeeded.
Result shape: torch.Size([128, 128])
```

### Example Using Neuron Kernel Interface (NKI)

For more advanced users, here's a simple example using the NKI:

Create a file called `nki_example.py`:

```python
import torch
import torch.nn as nn
import torch_neuronx
from torch.profiler import profile
import torch_neuronx.experimental.nki as nki

# Define a simple model with a custom kernel
class SimpleCustomModel(nn.Module):
    def __init__(self):
        super(SimpleCustomModel, self).__init__()
        self.fc = nn.Linear(256, 128)
    
    def forward(self, x):
        # Use the NKI for a custom operation
        # This is a simplified example - real NKI usage would be more complex
        with torch.no_grad():
            result = self.fc(x)
            
            # Register a custom callback to be executed during runtime
            # This is where you would typically insert your custom kernel logic
            @nki.kernel_callback
            def custom_operation(inputs, outputs):
                # Simple operation: add a small value to each element
                outputs[0] = inputs[0] + 0.01
                return True
            
            # Apply the custom operation
            result = custom_operation(result)
            
        return result

# Create input tensor
x = torch.randn(128, 256)

# Create and trace the model
model = SimpleCustomModel()
neuron_model = torch_neuronx.trace(model, x)

# Execute the model
with profile() as prof:
    output = neuron_model(x)

print("NKI Example executed successfully!")
print(f"Output shape: {output.shape}")
print("Profile results:")
print(prof.key_averages().table(sort_by="self_cpu_time_total"))
```

### Using NKI Simulator on a Regular CPU

When developing custom kernels with the Neuron Kernel Interface (NKI), you can use the simulator functionality to test your code on a regular CPU before deploying to Trainium hardware. This allows for faster development cycles and easier debugging.

Create a file called `nki_simulator_example.py`:

```python
import torch
import torch_neuronx.experimental.nki as nki

# Define a simple custom kernel function
def custom_elementwise_add(a, b):
    # Implement a simple elementwise addition
    result = a + b
    return result

# Create input tensors
a = torch.randn(10, 10)
b = torch.randn(10, 10)

# Define a kernel that uses the function
@nki.kernel
def my_kernel(inputs, outputs):
    # inputs and outputs are lists of tensors
    result = custom_elementwise_add(inputs[0], inputs[1])
    outputs[0].copy_(result)
    return True

# Create output tensor placeholder
output = torch.zeros(10, 10)

# Using nki.simulate_kernel to test the kernel on CPU
print("Running kernel simulation on CPU...")
success = nki.simulate_kernel(my_kernel, [a, b], [output])

if success:
    print("Kernel simulation succeeded!")
    print("Result sample:", output[0, 0].item())
    
    # Verify the result
    expected = a + b
    match = torch.allclose(output, expected)
    print(f"Output matches expected result: {match}")
else:
    print("Kernel simulation failed!")
```

This example demonstrates:
1. Creating a custom kernel function
2. Using the `@nki.kernel` decorator to define an NKI kernel
3. Testing the kernel with `nki.simulate_kernel` on a regular CPU

After testing on CPU, you can deploy the same kernels to Trainium hardware with minimal changes.

> **Note**: As of April 2025, the NKI has been significantly enhanced with Trainium2 support, including Logical NeuronCore Configuration (LNC) and SPMD capabilities for multi-core operations.

See Appendix A for instructions on setting up a local environment for NKI simulation development.

---

## 8. Instance Management

### Listing Your Instances

To effectively manage your Trainium instances, you'll need to know how to list, stop, start, and terminate them. Here's how to view your instances:

```bash
# List all instances
aws ec2 describe-instances \
    --query "Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key=='Name'].Value|[0]]" \
    --output table

# List only running instances
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].[InstanceId,InstanceType,PublicIpAddress,Tags[?Key=='Name'].Value|[0]]" \
    --output table

# List only your workshop instances
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" \
    --query "Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,PublicIpAddress]" \
    --output table
```

### Stopping an Instance

Stopping an instance preserves its state but halts compute charges. The instance retains its data but won't incur hourly instance charges (though storage charges still apply):

```bash
# Stop an instance by ID
aws ec2 stop-instances \
    --instance-ids i-0123456789abcdef

# Verify it's stopping
aws ec2 describe-instances \
    --instance-ids i-0123456789abcdef \
    --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
    --output table
```

### Starting a Stopped Instance

To continue your work on a previously stopped instance:

```bash
# Start the stopped instance
aws ec2 start-instances \
    --instance-ids i-0123456789abcdef

# Wait for it to be fully running
aws ec2 wait instance-running \
    --instance-ids i-0123456789abcdef

# Get the new public IP (it will change after stopping/starting)
aws ec2 describe-instances \
    --instance-ids i-0123456789abcdef \
    --query "Reservations[*].Instances[*].[PublicIpAddress]" \
    --output text

# Update your instance IP environment variable
export INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids i-0123456789abcdef \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)
```

### Finding a Specific Instance

```bash
# Find instances by name tag
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" \
    --query "Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]" \
    --output table

# Find instances by type
aws ec2 describe-instances \
    --filters "Name=instance-type,Values=trn1.2xlarge" \
    --query "Reservations[*].Instances[*].[InstanceId,State.Name,Tags[?Key=='Name'].Value|[0]]" \
    --output table
```

### Terminating an Instance

Terminating an instance permanently deletes it and its data. This cannot be undone, so be certain before proceeding:

```bash
# Terminate an instance
aws ec2 terminate-instances \
    --instance-ids i-0123456789abcdef

# Verify it's terminating
aws ec2 describe-instances \
    --instance-ids i-0123456789abcdef \
    --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
    --output table
```

> **Important**: Always terminate instances you no longer need to avoid unexpected charges. For temporary pauses in work, stopping is more appropriate than terminating, as you'll retain your data and configuration.

---

## 9. Cleanup and Best Practices

### Preventing Unexpected AWS Spend
You are charged for AWS resources that you have provisioned until you explicitly disable or terminate them. It's crucial to ensure you disable or terminate any AWS resources you no longer need to avoid incurring unnecessary charges. 
- AWS charges for provisioned resources, not just active usage
- An idle EC2 instance still costs money because the virtual server is reserved for you
- Storage services like S3 charge for data stored, regardless of whether you access it
- Many AWS services have both provisioning costs (having the resource) and usage costs (actively using it)

**You can follow these steps to identify which AWS resources you are being billed for:**
#### Step 1: Use the Billing Dashboard
- Navigate to AWS Billing & Cost Management Console
- Check "Bills" section for current month's charges
- Review "Cost by Service" to see which services are generating costs
- The AWS Billing & Cost Management Console shows global costs across all regions in one view – meaning you see the total charges from all regions combined. You can filter or break down costs by region if needed, but the default view is global

#### Step 2: Cost Explorer Analysis
- Use AWS Cost Explorer for detailed breakdowns
- Filter by service, region, or time period
- Look for unexpected or growing costs

#### Step 3: Service-by-Service Inventory
- EC2: Check running instances across all regions
- RDS: Look for database instances (even stopped ones may charge for storage)
- S3: Review buckets and storage usage
- EBS: Check for unattached volumes
- Elastic Load Balancers: Verify active load balancers
- NAT Gateways: Often overlooked but expensive
- Elastic IPs: Unattached IPs incur charges

**NOTE: You need to check each region separately, as the AWS console is region-specific for most services. E.g., an EC2 instance in us-east-1 won't show up when you're viewing us-west-2.**

#### Step 4: Use AWS Resource Groups & Tag Editor
- Create resource groups to organize and track resources
- Use tags consistently to identify resource ownership and purpose

#### Step 5: Set Up Monitoring
- Enable billing alerts for spending thresholds
- Use AWS Budgets to track costs proactively
- Consider AWS Cost Anomaly Detection

#### Tips:
- Always check all AWS regions - resources in different AS regions won't show up unless you switch regions. Even if you disable an AWS Region, charges will continue for active resources in that region until they are terminated. 
- Use the "Resource Groups" console for a centralized view
- Take screenshots of your initial setup so you remember what you created
- Delete resources immediately after testing/learning exercises

### Automatic Instance Monitoring

To help manage costs, we've provided a monitoring script that can automatically check your instances and stop them when idle. This is especially useful for workshop participants who might forget to shut down their instances.

#### Setting Up the Monitor

1. Download the monitoring scripts:
   - `trainium-monitor.sh` - The main monitoring script that monitors both CPU and Trainium chip usage
   - `setup-cron-monitor.sh` - Script to set up the cron job

2. Make the scripts executable:
```bash
chmod +x trainium-monitor.sh setup-cron-monitor.sh
```

3. Run the setup script:
```bash
./setup-cron-monitor.sh install
```

This will set up a cron job that runs every 15 minutes to check your Trainium instance. The script will:

- Check if your instance is running
- Measure CPU and Neuron device usage
- Check if users are logged in
- If the instance is idle (< 5% usage) and no one is logged in, it will stop the instance
- If the instance is idle but users are logged in, it will send a warning message

You can customize the check interval:
```bash
./setup-cron-monitor.sh install --interval 30  # Check every 30 minutes
```

To remove the monitoring cron job:
```bash
./setup-cron-monitor.sh remove
```

To temporarily disable monitoring without removing the cron job, edit `~/.aws/trainium-workshop.conf` and set:
```
MONITOR_OVERRIDE="true"
```

### Manual Cleanup

When you're done with the workshop, follow these steps to avoid unnecessary charges:

1. Terminate all EC2 instances:
```bash
# List all running instances first to verify what will be terminated
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]" \
    --output table

# Then terminate the instances
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text | xargs -n1 aws ec2 terminate-instances --instance-ids
```

2. Delete any persistent resources:
```bash
# Delete launch template
aws ec2 delete-launch-template --launch-template-name TrainiumTemplate

# Delete security group (only works if no instances are using it)
aws ec2 delete-security-group --group-name trainium-workshop-sg
```

3. Verify all resources have been deleted:
```bash
# Check for any remaining instances
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" \
    --query "Reservations[*].Instances[*].[InstanceId,State.Name]" \
    --output table

# Check for launch templates
aws ec2 describe-launch-templates \
    --filters "Name=launch-template-name,Values=TrainiumTemplate" \
    --query "LaunchTemplates[*].[LaunchTemplateName,CreateTime]" \
    --output table
```

### Security Best Practices

1. **Restrict SSH Access to Your IP Only**
   - The scripts in this workshop automatically restrict SSH access to only your current IP address
   - If your IP changes, update the security group rule:
   ```bash
   # Get your new public IP
   NEW_IP=$(curl -s https://checkip.amazonaws.com)
   
   # Update the security group rule
   aws ec2 update-security-group-rule-descriptions-ingress \
       --group-id <your-security-group-id> \
       --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${NEW_IP}/32,Description='SSH access from my IP'}]"
   ```

2. **Never Share Your AWS Access Keys or Private Key Files**
   - Keep your AWS access keys secure and never commit them to version control
   - Regularly rotate your access keys (at least every 90 days)
   - Store private key files (.pem) in a secure location with proper permissions (chmod 400)

3. **Use IAM Roles with the Principle of Least Privilege**
   - Only grant the permissions that are absolutely necessary
   - Consider creating separate IAM users for different purposes
   - Remove permissions when they are no longer needed

4. **Enable Multi-Factor Authentication (MFA)**
   - Enable MFA for your AWS account
   - Require MFA for IAM users with elevated privileges

5. **Monitor Your AWS Account**
   - Enable AWS CloudTrail to log API calls
   - Set up billing alerts to monitor costs
   - Regularly review security settings and resources

6. **Regularly Back Up Important Data**
   - Make sure important data is backed up to S3 or another persistent storage
   - Consider enabling versioning for critical S3 buckets

7. **Automate Instance Management**
   - Use the provided monitoring script to automatically stop idle instances
   - Always terminate instances when not in use
   - Check for running instances before leaving the workshop

### Cost Management Best Practices

1. Always stop or terminate instances when not in use
2. Use Spot Instances for non-critical workloads
3. Monitor your AWS costs using AWS Cost Explorer
4. Set up budget alerts to avoid unexpected charges
5. Consider using AWS Savings Plans for long-term usage

---

## 10. Additional Resources

- [AWS Trainium Documentation](https://aws.amazon.com/ai/machine-learning/trainium/) - Official AWS Trainium product page
- [AWS Neuron SDK Documentation](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/) - Latest Neuron SDK version 2.22.0 (April 2025)
- [Neuron Kernel Interface (NKI) Guide](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/general/nki/index.html) - Learn about the Neuron Kernel Interface
- [AWS CLI Command Reference](https://awscli.amazonaws.com/v2/documentation/api/latest/index.html) - AWS CLI documentation
- [AWS Neuron GitHub Repository](https://github.com/aws-neuron/aws-neuron-sdk) - Source code and examples
- [Hugging Face Optimum Neuron](https://huggingface.co/docs/optimum-neuron) - For deploying transformer models on Trainium
- [AWS Neuron Deep Learning Containers](https://github.com/aws-neuron/deep-learning-containers) - Pre-built Docker images for Trainium development
- [AWS Best Practices](https://aws.amazon.com/architecture/well-architected/) - AWS Well-Architected framework

## 11. Trainium Management Script

To further streamline your AWS Trainium instance management, we've provided a comprehensive shell script that automates many of the tasks covered in this workshop. The script [`trainium.sh`](https://github.com/scttfrdmn/aws-101-for-tranium/blob/main/trainium.sh) offers a command-line interface to manage your Trainium instances:

```bash
# Download the script
wget https://raw.githubusercontent.com/scttfrdmn/aws-101-for-tranium/main/trainium.sh
chmod +x trainium.sh

# Set up your AWS environment
./trainium.sh setup

# Launch a Trainium instance
./trainium.sh start

# Check instance status
./trainium.sh status

# Connect to your instance
./trainium.sh connect

# Stop your instance (can be restarted)
./trainium.sh stop

# Terminate your instance (permanent)
./trainium.sh terminate
```

### Key Features of the Management Script

The script includes several advanced features to simplify your workflow:

- **Automatic AMI Discovery**: Automatically finds the latest Neuron DLAMI without requiring you to search and copy AMI IDs
- **Security Group Management**: Creates and manages security groups with proper IP restrictions
- **Configuration Persistence**: Stores all settings in `~/.aws/trainium-workshop.conf` for easy reuse
- **Region Flexibility**: Works with any AWS region that supports Trainium
- **Instance Type Options**: Supports both Trn1 and Trn2 instance types
- **Comprehensive Help**: Provides detailed help with `./trainium.sh help`

### Automated Monitoring System

Additionally, we provide a monitoring script that can be set up as a cron job to automatically stop idle instances:

```bash
# Download the monitoring scripts from the repository
wget https://raw.githubusercontent.com/scttfrdmn/aws-101-for-tranium/main/trainium-monitor.sh
wget https://raw.githubusercontent.com/scttfrdmn/aws-101-for-tranium/main/setup-cron-monitor.sh
chmod +x trainium-monitor.sh setup-cron-monitor.sh

# Set up the monitoring cron job (checks every 15 minutes)
./setup-cron-monitor.sh install

# Customize the check interval (e.g., every 30 minutes)
./setup-cron-monitor.sh install --interval 30

# Remove the monitoring cron job when no longer needed
./setup-cron-monitor.sh remove
```

### Monitoring System Features

The monitoring system includes intelligent resource management:

- **Comprehensive Monitoring**: Checks both CPU and Trainium chip (NeuronCore) utilization
- **User Awareness**: Detects if users are logged in before taking action 
- **Smart Idle Detection**: Instances are considered idle only when both CPU and Trainium activity are low
- **Automated Shutdown**: Stops idle instances with no active users
- **Warning System**: Sends warning messages to all logged-in users on idle instances
- **Override Option**: Can be temporarily disabled via configuration when needed
- **Cross-Platform Compatible**: Works on both macOS and Linux systems

### Benefits of Using These Scripts

These automation tools provide significant advantages:

1. **Cost Control**: Prevents unexpected charges by ensuring instances are shut down when not in use
2. **Consistency**: Eliminates common setup errors by standardizing the environment creation process
3. **Time Savings**: Reduces the time needed for routine management tasks
4. **Error Prevention**: Handles complex AWS interactions with built-in error checking and validation
5. **Accessibility**: Makes AWS Trainium development more accessible to those new to AWS

These scripts are especially valuable in environments where managing AWS resources efficiently is essential for staying within budget constraints.

## 12. Common Troubleshooting and Next Steps

### Common Issues and Solutions

#### Connection Issues

If you can't connect to your instance:
```bash
# Check if your instance is running
aws ec2 describe-instances \
    --region us-west-2 \
    --instance-ids $INSTANCE_ID \
    --query "Reservations[0].Instances[0].State.Name" \
    --output text

# Verify security group allows your IP
MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 describe-security-groups \
    --region us-west-2 \
    --group-ids $SECURITY_GROUP_ID \
    --query "SecurityGroups[0].IpPermissions[?ToPort==22].IpRanges[].CidrIp" \
    --output text
```

#### Instance Launch Failures

If your instance fails to launch:
```bash
# Check your quota for the instance type
aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-2E30FD7D \
    --region us-west-2

# Verify the AMI is available in your region
aws ec2 describe-images \
    --region us-west-2 \
    --image-ids $AMI_ID
```

#### Neuron SDK Issues

If you encounter Neuron SDK problems:
```bash
# Verify Neuron environment is correctly activated
source activate aws_neuron_pytorch_p310
python -c "import torch_neuronx; print(torch_neuronx.__version__)"

# Check Neuron device visibility
neuron-ls

# Check Neuron driver status
sudo systemctl status neuron-driver
```

### Next Steps After This Workshop

After completing this introductory workshop, you can explore:

1. **Advanced ML with Trainium**: Learn distributed training, model optimization, and advanced PyTorch techniques
2. **Trainium Performance Tuning**: Explore profiling, benchmarking, and optimization techniques
3. **NKI Development**: Develop custom kernels to maximize performance for specific operations
4. **MLOps on AWS**: Set up CI/CD pipelines for ML development with Trainium

Refer to these resources for deeper learning:
- [AWS Neuron SDK Documentation](https://awsdocs-neuron.readthedocs-hosted.com/)
- [AWS Trainium Developer Guide](https://aws.amazon.com/machine-learning/trainium/)
- [PyTorch on AWS Trainium Guide](https://pytorch.org/tutorials/beginner/aws_trainium.html)
- [AWS ML Blog](https://aws.amazon.com/blogs/machine-learning/)

---

## Troubleshooting

### Common Issues and Solutions

1. **Instance Limit Exceeded**
   - Solution: Request a limit increase through the AWS Support Center

2. **Cannot Connect to Instance**
   - Check security group rules
   - Verify key pair is correct
   - Ensure instance is in 'running' state

3. **Neuron SDK Issues**
   - Verify you're using the correct environment: `source activate aws_neuron_pytorch_p38`
   - Check if Neuron devices are visible: `neuron-ls`

4. **Budget Alert Not Working**
   - Verify email notification settings
   - Check if the budget was created correctly using: `aws budgets describe-budgets`

If you encounter issues not covered here, consult the [AWS Neuron Troubleshooting Guide](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/general/troubleshooting-guide.html).

---

## Workshop Feedback

We value your feedback! Please share your experience and suggestions to help us improve this workshop.

---

## Appendices

### Appendix A: Local Development Environment for NKI Simulation

This appendix provides instructions for setting up a local environment for developing and testing NKI kernels using the simulation functionality, without needing access to actual Trainium hardware.

#### System Requirements

- Python 3.9 or later (Python 3.8 support is being deprecated as of 2025)
- pip (Python package manager)
- CUDA toolkit (optional, for GPU development)

#### Setting Up the Environment

##### For macOS:

```bash
# Create a virtual environment
python3 -m venv neuron-env
source neuron-env/bin/activate

# Install PyTorch
pip install torch torchvision

# Install AWS Neuron SDK dependencies (latest as of April 2025)
pip install "neuronx-cc==2.*" packaging "torch-neuronx==2.0.*"
```

##### For Linux:

```bash
# Create a virtual environment
python3 -m venv neuron-env
source neuron-env/bin/activate

# Install PyTorch
pip install torch torchvision

# Install AWS Neuron SDK dependencies (latest as of April 2025)
pip install "neuronx-cc==2.*" packaging "torch-neuronx==2.0.*"
```

##### For Windows (using Anaconda):

```bash
# Create a conda environment
conda create -n neuron-env python=3.9
conda activate neuron-env

# Install PyTorch
conda install pytorch torchvision -c pytorch

# Install AWS Neuron SDK dependencies (latest as of April 2025)
pip install "neuronx-cc==2.*" packaging "torch-neuronx==2.0.*"
```

#### Verifying the Installation

Create a test script called `test_neuron_sdk.py`:

```python
# Verify Neuron SDK installation
try:
    import torch
    import torch_neuronx
    import torch_neuronx.experimental.nki as nki
    
    print("PyTorch version:", torch.__version__)
    print("torch_neuronx version:", torch_neuronx.__version__)
    print("NKI module available:", "Yes" if hasattr(torch_neuronx.experimental, "nki") else "No")
    
    # Test NKI simulator functionality
    @nki.kernel
    def simple_test_kernel(inputs, outputs):
        outputs[0].copy_(inputs[0] * 2)
        return True
    
    # Create test tensors
    input_tensor = torch.tensor([1.0, 2.0, 3.0])
    output_tensor = torch.zeros(3)
    
    # Run simulation
    success = nki.simulate_kernel(simple_test_kernel, [input_tensor], [output_tensor])
    
    if success:
        print("NKI Simulator test passed!")
        print("Output:", output_tensor)
    else:
        print("NKI Simulator test failed!")
        
except ImportError as e:
    print("Import error:", e)
    print("Please check your installation.")
```

Run the test script:

```bash
python test_neuron_sdk.py
```

#### Troubleshooting

If you encounter installation issues:

1. Make sure your PyTorch version is compatible with the torch-neuronx version
2. For import errors, check that all packages are installed in the same environment
3. If you get a "module not found" error for torch_neuronx, try:
   ```bash
   pip uninstall torch-neuronx
   pip install --force-reinstall "torch-neuronx==2.0.*"
   ```

#### Development Workflow

1. **Develop and test locally**: Use `nki.simulate_kernel` to test kernels on your local machine
2. **Profile on CPU/GPU**: Optimize your kernels before deploying to Trainium
3. **Deploy to Trainium**: After local testing, move to Trainium hardware for final testing and performance tuning

This workflow allows you to develop NKI kernels efficiently without continuously needing access to Trainium hardware.

### Appendix B: Quick Reference

This quick reference card summarizes the key commands used throughout this workshop.

### AWS CLI Setup & Configuration

```bash
# Install AWS CLI (macOS with Homebrew)
brew install awscli

# Configure AWS CLI
aws configure
```

### Instance Management

```bash
# List available Trainium instance types
aws ec2 describe-instance-type-offerings \
    --filters Name=instance-type,Values=trn1*,trn2* \
    --output table

# Find latest Neuron DLAMI
aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=*Neuron*Ubuntu*22.04*" \
    --query "sort_by(Images, &CreationDate)[-1].[ImageId,Name]" \
    --output table

# Launch Trainium instance (use actual AMI ID)
aws ec2 run-instances \
    --image-id $NEURON_AMI_ID \
    --instance-type trn1.2xlarge \
    --key-name trainium-workshop-key \
    --security-groups trainium-workshop-sg \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=TrainiumWorkshop}]'

# Get instance details
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].[InstanceId,PublicIpAddress,State.Name]" \
    --output table

# Stop instance
aws ec2 stop-instances \
    --instance-ids $INSTANCE_ID

# Start instance
aws ec2 start-instances \
    --instance-ids $INSTANCE_ID

# Terminate instance
aws ec2 terminate-instances \
    --instance-ids $INSTANCE_ID
```

### SSH and File Transfer

```bash
# Connect to instance
ssh -i ~/.ssh/trainium-workshop-key.pem ubuntu@$INSTANCE_IP

# Copy file to instance
scp -i ~/.ssh/trainium-workshop-key.pem /path/to/local/file ubuntu@$INSTANCE_IP:/path/on/remote/machine

# Copy file from instance
scp -i ~/.ssh/trainium-workshop-key.pem ubuntu@$INSTANCE_IP:/path/on/remote/machine /path/to/local/destination
```

### Neuron SDK on Instance

```bash
# Activate Neuron environment
source activate aws_neuron_pytorch_p310

# Check Neuron installation
neuron-ls

# Run a simple PyTorch model
python hello_trainium.py
```

### Management Scripts

```bash
# Set up Trainium environment
./trainium.sh setup

# Launch Trainium instance
./trainium.sh start

# Set up auto-monitoring
./setup-cron-monitor.sh install --interval 30
```

### Cleanup

```bash
# Terminate all workshop instances
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=TrainiumWorkshop" "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text | xargs -n1 aws ec2 terminate-instances --instance-ids

# Remove monitoring cron job
./setup-cron-monitor.sh remove
```
