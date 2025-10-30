#!/bin/bash

# Kong Database Migration Script for AWS ECS
# This script runs Kong database migrations on Aurora PostgreSQL

set -e

# Configuration
CLUSTER_NAME="kong-gateway-cluster"
TASK_DEFINITION="kong-migrations"
SUBNET_ID="subnet-private-1"  # Update with your private subnet ID
SECURITY_GROUP="sg-kong-cp"    # Update with your control plane security group ID
AWS_REGION="ap-southeast-1"
LOG_GROUP="/fargate/kong-migrations"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Kong Database Migration Script ===${NC}\n"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warn "jq is not installed. Output formatting will be limited."
fi

# Prompt for migration type
echo "Select migration type:"
echo "1) bootstrap - First time setup (creates all tables)"
echo "2) up - Run pending migrations (for updates)"
echo "3) finish - Complete migrations (if required by update)"
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        MIGRATION_COMMAND='["kong", "migrations", "bootstrap"]'
        MIGRATION_TYPE="bootstrap"
        ;;
    2)
        MIGRATION_COMMAND='["kong", "migrations", "up"]'
        MIGRATION_TYPE="up"
        ;;
    3)
        MIGRATION_COMMAND='["kong", "migrations", "finish"]'
        MIGRATION_TYPE="finish"
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

print_info "Running migration: $MIGRATION_TYPE"

# Check if task definition exists
print_info "Checking if task definition exists..."
if ! aws ecs describe-task-definition --task-definition $TASK_DEFINITION --region $AWS_REGION &> /dev/null; then
    print_error "Task definition '$TASK_DEFINITION' not found. Please register it first:"
    echo "  aws ecs register-task-definition --cli-input-json file://kong-migrations-task-definition.json"
    exit 1
fi

# Run the migration task
print_info "Starting migration task..."
TASK_ARN=$(aws ecs run-task \
    --cluster $CLUSTER_NAME \
    --task-definition $TASK_DEFINITION \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
    --overrides "{\"containerOverrides\":[{\"name\":\"kong-migrations\",\"command\":$MIGRATION_COMMAND}]}" \
    --region $AWS_REGION \
    --query 'tasks[0].taskArn' \
    --output text)

if [ -z "$TASK_ARN" ]; then
    print_error "Failed to start migration task"
    exit 1
fi

print_info "Migration task started: $TASK_ARN"
print_info "Waiting for task to complete..."

# Wait for task to complete
aws ecs wait tasks-stopped \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION

# Check exit code
EXIT_CODE=$(aws ecs describe-tasks \
    --cluster $CLUSTER_NAME \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].containers[0].exitCode' \
    --output text)

print_info "Task completed with exit code: $EXIT_CODE"

# Display logs
print_info "Fetching migration logs..."
echo -e "\n${GREEN}=== Migration Logs ===${NC}"

# Get task ID from ARN
TASK_ID=$(echo $TASK_ARN | awk -F/ '{print $NF}')

# Try to get logs
aws logs get-log-events \
    --log-group-name $LOG_GROUP \
    --log-stream-name "migrations/$TASK_ID" \
    --region $AWS_REGION \
    --query 'events[*].message' \
    --output text 2>/dev/null || print_warn "Could not fetch logs. Check CloudWatch Logs manually."

echo -e "\n${GREEN}=== Summary ===${NC}"

if [ "$EXIT_CODE" == "0" ]; then
    print_info "✓ Migration completed successfully!"
    
    if [ "$MIGRATION_TYPE" == "bootstrap" ]; then
        echo -e "\n${GREEN}Next steps:${NC}"
        echo "1. Verify database tables:"
        echo "   psql -h <aurora-endpoint> -U kongadmin -d kong -c \"\\dt\""
        echo "2. Deploy Control Plane service"
        echo "3. Deploy Data Plane service"
    fi
else
    print_error "✗ Migration failed with exit code: $EXIT_CODE"
    echo -e "\nCheck logs for details:"
    echo "  aws logs tail $LOG_GROUP --follow"
    exit 1
fi

echo -e "\n${GREEN}Migration task ARN:${NC} $TASK_ARN"
echo -e "${GREEN}View logs:${NC} aws logs tail $LOG_GROUP --follow"
