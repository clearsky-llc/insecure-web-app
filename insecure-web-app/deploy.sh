#!/bin/bash

# This script deploys the insecure three-tier application
# Assumes AWS CLI is configured with appropriate credentials

# Variables
STACK_NAME="insecure-three-tier-app"
REPO_URL="https://github.com/yourusername/insecure-web-app.git"
S3_BUCKET_NAME="insecure-frontend-$(date +%s)"
KEY_PAIR_NAME="insecure-key-pair"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Create EC2 key pair if it doesn't exist
if ! aws ec2 describe-key-pairs --key-names $KEY_PAIR_NAME &> /dev/null; then
    echo "Creating EC2 key pair: $KEY_PAIR_NAME"
    aws ec2 create-key-pair --key-name $KEY_PAIR_NAME --query 'KeyMaterial' --output text > $KEY_PAIR_NAME.pem
    chmod 400 $KEY_PAIR_NAME.pem
    echo "Key pair created and saved as $KEY_PAIR_NAME.pem"
else
    echo "Key pair $KEY_PAIR_NAME already exists"
fi

# Clone the repository to get the application code
echo "Cloning application repository..."
git clone $REPO_URL
cd insecure-web-app

# Create S3 bucket for frontend
echo "Creating S3 bucket for frontend..."
aws s3api create-bucket --bucket $S3_BUCKET_NAME --acl public-read

# Enable website hosting on S3 bucket
aws s3 website s3://$S3_BUCKET_NAME/ --index-document index.html --error-document error.html

# Copy frontend files to S3
echo "Deploying frontend to S3..."
aws s3 sync ./web-tier/static s3://$S3_BUCKET_NAME/ --acl public-read

# Create CloudFormation stack
echo "Deploying CloudFormation stack..."
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://cloudformation.yaml \
    --parameters ParameterKey=KeyPairName,ParameterValue=$KEY_PAIR_NAME \
               ParameterKey=FrontendBucketName,ParameterValue=$S3_BUCKET_NAME \
    --capabilities CAPABILITY_IAM

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME

# Get outputs
echo "Deployment completed. Here are your endpoints:"
aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].Outputs' --output table

echo "Remember, this deployment has intentional security weaknesses for demonstration purposes."
echo "Use a CSP security tool to identify and remediate these issues."
