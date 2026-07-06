#!/bin/bash

# AWS CLI Installation & EC2 Instance Launch Script
# Complete automation for AWS setup and instance creation
# Author: DevOps Engineer

set -e  # Exit on error
  
# ============================================
# COLOR CODES FOR BETTER VISIBILITY
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ============================================
# FUNCTIONS FOR PRINTING
# ============================================
print_status() {
    echo -e "${GREEN}[✔]${NC} $1"
}

print_error() {
    echo -e "${RED}[✘]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

print_header() {
    echo -e "\n${BOLD}${PURPLE}========================================${NC}"
    echo -e "${BOLD}${PURPLE}  $1${NC}"
    echo -e "${BOLD}${PURPLE}========================================${NC}\n"
}

# ============================================
# CHECK PREREQUISITES
# ============================================
check_prerequisites() {
    print_header "CHECKING PREREQUISITES"
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then 
        print_warning "Running as root user (not recommended for AWS CLI)"
    fi
    
    # Check OS compatibility
    if ! uname -m | grep -q "x86_64"; then
        print_error "This script is for x86_64 architecture only"
        print_error "Your architecture: $(uname -m)"
        exit 1
    fi
    
    if ! grep -qi "linux" <<< "$(uname -s)"; then
        print_error "This script is for Linux systems only"
        print_error "Your OS: $(uname -s)"
        exit 1
    fi
    
    print_status "System compatible: $(uname -a)"
}

# ============================================
# INSTALL AWS CLI
# ============================================
install_awscli() {
    print_header "INSTALLING AWS CLI V2"
    
    # Check if AWS CLI is already installed
    if command -v aws &> /dev/null; then
        CURRENT_VERSION=$(aws --version 2>&1)
        print_warning "AWS CLI is already installed: $CURRENT_VERSION"
        read -p "Do you want to reinstall? (y/n): " REINSTALL
        if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
            print_status "Skipping AWS CLI installation"
            return 0
        fi
    fi
    
    # Install dependencies
    print_info "Installing dependencies..."
    
    if ! command -v unzip &> /dev/null; then
        print_info "Installing unzip..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y unzip curl
        elif command -v yum &> /dev/null; then
            sudo yum install -y unzip curl
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y unzip curl
        else
            print_error "Cannot install dependencies. Please install unzip and curl manually."
            exit 1
        fi
    fi
    
    # Download AWS CLI
    print_info "Downloading AWS CLI v2..."
    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    
    if [ $? -ne 0 ]; then
        print_error "Download failed"
        exit 1
    fi
    print_status "Download completed"
    
    # Extract
    print_info "Extracting AWS CLI package..."
    unzip -q awscliv2.zip
    print_status "Extraction completed"
    
    # Install
    print_info "Installing AWS CLI..."
    if [ "$EUID" -eq 0 ]; then
        ./aws/install
    else
        sudo ./aws/install
    fi
    
    if [ $? -eq 0 ]; then
        print_status "AWS CLI installed successfully!"
        aws --version
    else
        print_error "Installation failed"
        exit 1
    fi
    
    # Cleanup
    print_info "Cleaning up installation files..."
    rm -f awscliv2.zip
    rm -rf aws
    print_status "Cleanup completed"
}

# ============================================
# CONFIGURE AWS CLI
# ============================================
configure_aws() {
    print_header "AWS CLI CONFIGURATION"
    
    # Check if already configured
    if aws sts get-caller-identity &>/dev/null; then
        CURRENT_USER=$(aws sts get-caller-identity --query 'Arn' --output text)
        print_status "AWS CLI is already configured"
        print_info "Current user: $CURRENT_USER"
        
        read -p "Do you want to reconfigure? (y/n): " RECONFIGURE
        if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    print_info "Please enter your AWS credentials:"
    
    # Get credentials interactively
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY
    read -sp "AWS Secret Access Key: " AWS_SECRET_KEY
    echo
    read -p "Default region [us-east-1]: " AWS_REGION
    AWS_REGION=${AWS_REGION:-us-east-1}
    read -p "Default output format [json]: " AWS_OUTPUT
    AWS_OUTPUT=${AWS_OUTPUT:-json}
    
    # Configure AWS CLI
    aws configure set aws_access_key_id "$AWS_ACCESS_KEY"
    aws configure set aws_secret_access_key "$AWS_SECRET_KEY"
    aws configure set region "$AWS_REGION"
    aws configure set output "$AWS_OUTPUT"
    
    print_status "AWS CLI configured successfully!"
    
    # Verify configuration
    print_info "Verifying credentials..."
    if aws sts get-caller-identity &>/dev/null; then
        USER_ARN=$(aws sts get-caller-identity --query 'Arn' --output text)
        print_status "Authentication successful!"
        print_info "User ARN: $USER_ARN"
    else
        print_error "Authentication failed. Please check your credentials."
        exit 1
    fi
}

# ============================================
# CREATE RESOURCES FOR EC2
# ============================================
create_resources() {
    print_header "CREATING RESOURCES FOR EC2 INSTANCE"
    
    # Check if resources already exist
    if aws ec2 describe-key-pairs --key-names "my-ec2-key" &>/dev/null; then
        print_warning "Key pair 'my-ec2-key' already exists"
        USE_EXISTING_KEY="yes"
    else
        USE_EXISTING_KEY="no"
    fi
    
    if aws ec2 describe-security-groups --group-names "my-ec2-sg" &>/dev/null; then
        print_warning "Security group 'my-ec2-sg' already exists"
        USE_EXISTING_SG="yes"
    else
        USE_EXISTING_SG="no"
    fi
}

# ============================================
# CREATE KEY PAIR
# ============================================
create_keypair() {
    print_info "Creating Key Pair..."
    
    if [ "$USE_EXISTING_KEY" == "yes" ]; then
        read -p "Do you want to create a new key pair? (y/n): " CREATE_NEW_KEY
        if [[ ! "$CREATE_NEW_KEY" =~ ^[Yy]$ ]]; then
            print_status "Using existing key pair"
            KEY_NAME="my-ec2-key"
            return 0
        fi
    fi
    
    read -p "Enter key pair name [my-ec2-key]: " KEY_NAME
    KEY_NAME=${KEY_NAME:-my-ec2-key}
    
    # Check if key exists and delete if needed
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" &>/dev/null; then
        print_warning "Key pair '$KEY_NAME' exists. Deleting..."
        aws ec2 delete-key-pair --key-name "$KEY_NAME"
    fi
    
    # Create new key pair
    print_info "Creating key pair: $KEY_NAME"
    aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "${KEY_NAME}.pem"
    
    if [ -f "${KEY_NAME}.pem" ]; then
        chmod 400 "${KEY_NAME}.pem"
        print_status "Key pair created: ${KEY_NAME}.pem"
        print_info "Private key saved to: ${KEY_NAME}.pem"
        print_warning "Keep this file safe! You need it to SSH into your instance."
    else
        print_error "Failed to create key pair"
        exit 1
    fi
}

# ============================================
# CREATE SECURITY GROUP
# ============================================
create_security_group() {
    print_info "Creating Security Group..."
    
    if [ "$USE_EXISTING_SG" == "yes" ]; then
        read -p "Do you want to create a new security group? (y/n): " CREATE_NEW_SG
        if [[ ! "$CREATE_NEW_SG" =~ ^[Yy]$ ]]; then
            SG_NAME="my-ec2-sg"
            SG_ID=$(aws ec2 describe-security-groups --group-names "$SG_NAME" --query 'SecurityGroups[0].GroupId' --output text)
            print_status "Using existing security group: $SG_ID"
            return 0
        fi
    fi
    
    read -p "Enter security group name [my-ec2-sg]: " SG_NAME
    SG_NAME=${SG_NAME:-my-ec2-sg}
    
    # Check if exists and delete
    if aws ec2 describe-security-groups --group-names "$SG_NAME" &>/dev/null; then
        print_warning "Security group '$SG_NAME' exists. Deleting..."
        aws ec2 delete-security-group --group-name "$SG_NAME" 2>/dev/null || true
        sleep 2
    fi
    
    # Create security group
    print_info "Creating security group: $SG_NAME"
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SG_NAME" \
        --description "Security group for EC2 instance" \
        --query 'GroupId' \
        --output text)
    
    if [ -z "$SG_ID" ]; then
        print_error "Failed to create security group"
        exit 1
    fi
    
    print_status "Security group created: $SG_ID"
    
    # Add SSH rule
    print_info "Adding SSH rule (port 22)..."
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0
    
    print_status "SSH rule added"
    
    # Optionally add HTTP rule
    read -p "Do you want to add HTTP rule (port 80)? (y/n): " ADD_HTTP
    if [[ "$ADD_HTTP" =~ ^[Yy]$ ]]; then
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port 80 \
            --cidr 0.0.0.0/0
        print_status "HTTP rule added"
    fi
    
    # Optionally add HTTPS rule
    read -p "Do you want to add HTTPS rule (port 443)? (y/n): " ADD_HTTPS
    if [[ "$ADD_HTTPS" =~ ^[Yy]$ ]]; then
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port 443 \
            --cidr 0.0.0.0/0
        print_status "HTTPS rule added"
    fi
    
    print_status "Security group configured successfully!"
}

# ============================================
# GET AVAILABLE AMIs
# ============================================
get_ami_id() {
    print_info "Getting available AMIs..."
    
    # Get region
    REGION=$(aws configure get region)
    
    # Show popular AMIs based on region
    echo -e "\n${CYAN}Available AMIs in $REGION:${NC}"
    echo "1. Amazon Linux 2 (Free Tier eligible)"
    echo "2. Ubuntu 22.04 LTS (Free Tier eligible)"
    echo "3. Ubuntu 20.04 LTS (Free Tier eligible)"
    echo "4. CentOS 7"
    echo "5. Custom AMI ID"
    
    read -p "Select AMI [1-5]: " AMI_CHOICE
    
    case $AMI_CHOICE in
        1)
            AMI_ID=$(aws ec2 describe-images \
                --owners amazon \
                --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
                --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
                --output text)
            OS_NAME="Amazon Linux 2"
            ;;
        2)
            AMI_ID=$(aws ec2 describe-images \
                --owners 099720109477 \
                --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*" \
                --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
                --output text)
            OS_NAME="Ubuntu 22.04 LTS"
            ;;
        3)
            AMI_ID=$(aws ec2 describe-images \
                --owners 099720109477 \
                --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*" \
                --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
                --output text)
            OS_NAME="Ubuntu 20.04 LTS"
            ;;
        4)
            AMI_ID=$(aws ec2 describe-images \
                --owners aws-marketplace \
                --filters "Name=name,Values=CentOS 7*" \
                --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
                --output text)
            OS_NAME="CentOS 7"
            ;;
        5)
            read -p "Enter AMI ID: " AMI_ID
            OS_NAME="Custom AMI"
            ;;
        *)
            print_error "Invalid choice. Using Amazon Linux 2."
            AMI_ID=$(aws ec2 describe-images \
                --owners amazon \
                --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
                --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
                --output text)
            OS_NAME="Amazon Linux 2"
            ;;
    esac
    
    if [ -z "$AMI_ID" ]; then
        print_error "Failed to get AMI ID. Using default."
        AMI_ID="ami-0c55b159cbfafe1f0"  # Default Amazon Linux 2
        OS_NAME="Amazon Linux 2 (Default)"
    fi
    
    print_status "Selected AMI: $AMI_ID ($OS_NAME)"
}

# ============================================
# LAUNCH EC2 INSTANCE
# ============================================
launch_instance() {
    print_header "LAUNCHING EC2 INSTANCE"
    
    # Get instance details
    read -p "Enter instance name [MyWebServer]: " INSTANCE_NAME
    INSTANCE_NAME=${INSTANCE_NAME:-MyWebServer}
    
    read -p "Enter instance type [t2.micro]: " INSTANCE_TYPE
    INSTANCE_TYPE=${INSTANCE_TYPE:-t2.micro}
    
    # Check if t2.micro is available in the region
    if [ "$INSTANCE_TYPE" == "t2.micro" ]; then
        print_warning "t2.micro is Free Tier eligible (750 hours/month)"
    fi
    
    read -p "Number of instances [1]: " INSTANCE_COUNT
    INSTANCE_COUNT=${INSTANCE_COUNT:-1}
    
    # Get subnet ID
    SUBNET_ID=$(aws ec2 describe-subnets \
        --filters "Name=default-for-az,Values=true" \
        --query 'Subnets[0].SubnetId' \
        --output text)
    
    if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" == "None" ]; then
        print_warning "No default subnet found. Getting first available..."
        SUBNET_ID=$(aws ec2 describe-subnets \
            --query 'Subnets[0].SubnetId' \
            --output text)
    fi
    
    print_info "Using subnet: $SUBNET_ID"
    
    # Check if we want user data (startup script)
    read -p "Do you want to add a startup script (user data)? (y/n): " ADD_USERDATA
    USER_DATA=""
    if [[ "$ADD_USERDATA" =~ ^[Yy]$ ]]; then
        echo "Enter your startup script (type 'END' on a new line to finish):"
        USER_DATA_SCRIPT=""
        while IFS= read -r line; do
            if [[ "$line" == "END" ]]; then
                break
            fi
            USER_DATA_SCRIPT+="$line\n"
        done
        USER_DATA="--user-data \"$USER_DATA_SCRIPT\""
    fi
    
    # Launch instance
    print_info "Launching EC2 instance(s)..."
    print_info "  - Name: $INSTANCE_NAME"
    print_info "  - Type: $INSTANCE_TYPE"
    print_info "  - OS: $OS_NAME"
    print_info "  - AMI: $AMI_ID"
    print_info "  - Key Pair: $KEY_NAME"
    print_info "  - Security Group: $SG_NAME"
    
    # Build launch command
    LAUNCH_CMD="aws ec2 run-instances \
        --image-id $AMI_ID \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SG_ID \
        --subnet-id $SUBNET_ID \
        --count $INSTANCE_COUNT \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]'"
    
    # Execute launch
    INSTANCE_JSON=$(eval $LAUNCH_CMD)
    
    if [ $? -eq 0 ]; then
        INSTANCE_ID=$(echo "$INSTANCE_JSON" | jq -r '.Instances[0].InstanceId')
        PUBLIC_IP=$(echo "$INSTANCE_JSON" | jq -r '.Instances[0].PublicIpAddress')
        PRIVATE_IP=$(echo "$INSTANCE_JSON" | jq -r '.Instances[0].PrivateIpAddress')
        
        print_status "Instance launched successfully!"
        print_info "Instance ID: $INSTANCE_ID"
        print_info "Private IP: $PRIVATE_IP"
        
        if [ "$PUBLIC_IP" != "null" ] && [ -n "$PUBLIC_IP" ]; then
            print_info "Public IP: $PUBLIC_IP"
        else
            print_warning "No public IP assigned. You may need to associate an Elastic IP."
        fi
        
        # Wait for instance to be running
        print_info "Waiting for instance to reach 'running' state..."
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID
        print_status "Instance is now running!"
        
        # Get updated public IP
        PUBLIC_IP=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
        
        if [ "$PUBLIC_IP" != "null" ] && [ -n "$PUBLIC_IP" ]; then
            print_status "Instance is accessible at: $PUBLIC_IP"
            print_info "To SSH into your instance:"
            echo -e "${CYAN}ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP${NC}"
            
            # For Ubuntu
            if [[ "$OS_NAME" == *"Ubuntu"* ]]; then
                echo -e "${CYAN}ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP${NC}"
            fi
        fi
        
    else
        print_error "Failed to launch instance"
        exit 1
    fi
}

# ============================================
# DISPLAY INSTANCE INFORMATION
# ============================================
show_instance_info() {
    print_header "INSTANCE INFORMATION"
    
    # Get all running instances
    echo -e "${CYAN}Your Running Instances:${NC}\n"
    
    aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value | [0], InstanceId, InstanceType, State.Name, PublicIpAddress, PrivateIpAddress]' \
        --output table
    
    echo -e "\n${CYAN}SSH Commands:${NC}"
    
    # Get instances with public IP
    INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[].Instances[?PublicIpAddress!=`null`]' \
        --output json)
    
    if [ "$INSTANCES" != "[]" ] && [ -n "$INSTANCES" ]; then
        for row in $(echo "$INSTANCES" | jq -r '.[] | @base64'); do
            _jq() {
                echo ${row} | base64 --decode | jq -r ${1}
            }
            
            PUBLIC_IP=$(_jq '.PublicIpAddress')
            KEY_NAME=$(_jq '.KeyName')
            INSTANCE_NAME=$(_jq '.Tags[]? | select(.Key=="Name") | .Value')
            
            echo "Instance: $INSTANCE_NAME"
            echo "ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
            echo "ssh -i ${KEY_NAME}.pem ubuntu@$PUBLIC_IP"
            echo "---"
        done
    else
        print_warning "No running instances with public IP found"
    fi
}

# ============================================
# TERMINATE INSTANCE OPTION
# ============================================
terminate_instances() {
    read -p "Do you want to terminate all running instances? (y/n): " TERMINATE
    if [[ "$TERMINATE" =~ ^[Yy]$ ]]; then
        print_warning "This will permanently delete all running instances!"
        read -p "Are you sure? Type 'yes' to confirm: " CONFIRM
        
        if [ "$CONFIRM" == "yes" ]; then
            INSTANCE_IDS=$(aws ec2 describe-instances \
                --filters "Name=instance-state-name,Values=running" \
                --query 'Reservations[].Instances[].InstanceId' \
                --output text)
            
            if [ -n "$INSTANCE_IDS" ]; then
                print_info "Terminating instances: $INSTANCE_IDS"
                aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
                print_status "Instances terminated successfully!"
            else
                print_info "No running instances found to terminate"
            fi
        else
            print_status "Termination cancelled"
        fi
    fi
}

# ============================================
# MAIN EXECUTION
# ============================================
main() {
    print_header "AWS CLI & EC2 INSTANCE LAUNCH SCRIPT"
    echo "This script will:"
    echo "1. Install AWS CLI v2"
    echo "2. Configure AWS credentials"
    echo "3. Create necessary resources (Key Pair, Security Group)"
    echo "4. Launch an EC2 instance"
    echo ""
    
    # Step 1: Check system prerequisites
    check_prerequisites
    
    # Step 2: Install AWS CLI
    install_awscli
    
    # Step 3: Configure AWS
    configure_aws
    
    # Step 4: Create resources
    create_resources
    
    # Step 5: Create key pair
    create_keypair
    
    # Step 6: Create security group
    create_security_group
    
    # Step 7: Get AMI
    get_ami_id
    
    # Step 8: Launch instance
    launch_instance
    
    # Step 9: Show instance info
    show_instance_info
    
    # Step 10: Ask about termination
    terminate_instances
    
    print_header "SCRIPT COMPLETED SUCCESSFULLY"
    print_status "Your EC2 instance is ready to use!"
    echo ""
    echo "For more help:"
    echo "  aws ec2 help"
    echo "  aws ec2 run-instances help"
}

# ============================================
# ERROR HANDLING
# ============================================
trap 'print_error "Script failed at line $LINENO"; exit 1' ERR

# ============================================
# RUN SCRIPT
# ============================================
main

exit 0
