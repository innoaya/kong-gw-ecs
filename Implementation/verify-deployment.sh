#!/bin/bash

# Kong Gateway Deployment Verification Script
# Checks the health and status of Control Plane and Data Plane

set -e

# Configuration
CONTROL_PLANE_URL="http://config.kong.local:8001"
AWS_REGION="ap-southeast-1"
CLUSTER_NAME="kong-gateway-cluster"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_fail() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Check if running from bastion or VPC-connected environment
check_network_access() {
    print_header "Network Access Check"
    
    if curl -s --max-time 5 http://config.kong.local:8001/status &> /dev/null; then
        print_success "Can reach Control Plane at config.kong.local"
        return 0
    else
        print_fail "Cannot reach Control Plane. You may need to:"
        echo "  - Run this from a bastion host in the VPC"
        echo "  - Connect via VPN"
        echo "  - Use AWS Systems Manager Session Manager"
        return 1
    fi
}

# Check Control Plane
check_control_plane() {
    print_header "Control Plane Status"
    
    # Check ECS service
    CP_SERVICE_STATUS=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services kong-control-plane \
        --region $AWS_REGION \
        --query 'services[0].status' \
        --output text 2>/dev/null)
    
    if [ "$CP_SERVICE_STATUS" == "ACTIVE" ]; then
        print_success "ECS Service: ACTIVE"
    else
        print_fail "ECS Service: $CP_SERVICE_STATUS"
    fi
    
    # Check running tasks
    CP_RUNNING_COUNT=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services kong-control-plane \
        --region $AWS_REGION \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null)
    
    CP_DESIRED_COUNT=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services kong-control-plane \
        --region $AWS_REGION \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null)
    
    if [ "$CP_RUNNING_COUNT" == "$CP_DESIRED_COUNT" ]; then
        print_success "Tasks: $CP_RUNNING_COUNT/$CP_DESIRED_COUNT running"
    else
        print_fail "Tasks: $CP_RUNNING_COUNT/$CP_DESIRED_COUNT running"
    fi
    
    # Check health endpoint
    if check_network_access &> /dev/null; then
        CP_STATUS=$(curl -s $CONTROL_PLANE_URL/status 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            print_success "Admin API responding"
            
            # Check database connectivity
            DB_STATUS=$(echo $CP_STATUS | jq -r '.database.reachable' 2>/dev/null)
            if [ "$DB_STATUS" == "true" ]; then
                print_success "Database: Connected"
            else
                print_fail "Database: Not reachable"
            fi
        else
            print_fail "Admin API not responding"
        fi
    fi
}

# Check Data Plane
check_data_plane() {
    print_header "Data Plane Status"
    
    # Check ECS service
    DP_SERVICE_STATUS=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services kong-data-plane \
        --region $AWS_REGION \
        --query 'services[0].status' \
        --output text 2>/dev/null)
    
    if [ "$DP_SERVICE_STATUS" == "ACTIVE" ]; then
        print_success "ECS Service: ACTIVE"
    else
        print_fail "ECS Service: $DP_SERVICE_STATUS"
    fi
    
    # Check running tasks
    DP_RUNNING_COUNT=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services kong-data-plane \
        --region $AWS_REGION \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null)
    
    DP_DESIRED_COUNT=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services kong-data-plane \
        --region $AWS_REGION \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null)
    
    if [ "$DP_RUNNING_COUNT" == "$DP_DESIRED_COUNT" ]; then
        print_success "Tasks: $DP_RUNNING_COUNT/$DP_DESIRED_COUNT running"
    else
        print_fail "Tasks: $DP_RUNNING_COUNT/$DP_DESIRED_COUNT running"
    fi
    
    # Get ALB DNS
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --names kong-data-plane-alb \
        --region $AWS_REGION \
        --query 'LoadBalancers[0].DNSName' \
        --output text 2>/dev/null)
    
    if [ ! -z "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
        print_success "ALB: $ALB_DNS"
        
        # Check ALB health
        DP_STATUS=$(curl -s http://$ALB_DNS/status 2>/dev/null)
        if [ $? -eq 0 ]; then
            print_success "Data Plane responding via ALB"
        else
            print_fail "Data Plane not responding via ALB"
        fi
    else
        print_fail "ALB not found or not configured"
    fi
}

# Check cluster connectivity
check_cluster_connectivity() {
    print_header "Cluster Connectivity"
    
    if check_network_access &> /dev/null; then
        DATA_PLANES=$(curl -s $CONTROL_PLANE_URL/clustering/data-planes 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            DP_COUNT=$(echo $DATA_PLANES | jq '. | length' 2>/dev/null)
            
            if [ ! -z "$DP_COUNT" ] && [ "$DP_COUNT" != "null" ]; then
                print_success "Connected Data Planes: $DP_COUNT"
                
                # Show details
                echo "$DATA_PLANES" | jq -r '.[] | "  - \(.hostname) (\(.ip)) - Last seen: \(.last_seen) - Status: \(.sync_status)"' 2>/dev/null
            else
                print_fail "No Data Planes connected"
            fi
        else
            print_fail "Cannot retrieve cluster status"
        fi
    fi
}

# Check database
check_database() {
    print_header "Database Status"
    
    if check_network_access &> /dev/null; then
        # Get database info from control plane
        DB_INFO=$(curl -s $CONTROL_PLANE_URL/status 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            DB_REACHABLE=$(echo $DB_INFO | jq -r '.database.reachable' 2>/dev/null)
            
            if [ "$DB_REACHABLE" == "true" ]; then
                print_success "Aurora PostgreSQL: Connected"
                
                # Check number of services and routes
                SERVICE_COUNT=$(curl -s $CONTROL_PLANE_URL/services 2>/dev/null | jq '.data | length' 2>/dev/null)
                ROUTE_COUNT=$(curl -s $CONTROL_PLANE_URL/routes 2>/dev/null | jq '.data | length' 2>/dev/null)
                
                print_info "Services configured: $SERVICE_COUNT"
                print_info "Routes configured: $ROUTE_COUNT"
            else
                print_fail "Aurora PostgreSQL: Not reachable"
            fi
        fi
    fi
}

# Check service discovery
check_service_discovery() {
    print_header "Service Discovery"
    
    # Check if config.kong.local resolves
    if nslookup config.kong.local &> /dev/null; then
        print_success "DNS resolution: config.kong.local"
        RESOLVED_IP=$(nslookup config.kong.local | grep -A1 "Name:" | tail -1 | awk '{print $2}')
        print_info "Resolved to: $RESOLVED_IP"
    else
        print_fail "DNS resolution failed for config.kong.local"
        print_info "Ensure you're running this from within the VPC"
    fi
    
    # Check Cloud Map service
    NAMESPACE_ID=$(aws servicediscovery list-namespaces \
        --region $AWS_REGION \
        --query "Namespaces[?Name=='kong.local'].Id" \
        --output text 2>/dev/null)
    
    if [ ! -z "$NAMESPACE_ID" ]; then
        print_success "Cloud Map Namespace: kong.local ($NAMESPACE_ID)"
        
        SERVICE_ID=$(aws servicediscovery list-services \
            --filters Name=NAMESPACE_ID,Values=$NAMESPACE_ID \
            --region $AWS_REGION \
            --query "Services[?Name=='config'].Id" \
            --output text 2>/dev/null)
        
        if [ ! -z "$SERVICE_ID" ]; then
            print_success "Cloud Map Service: config ($SERVICE_ID)"
        else
            print_fail "Cloud Map Service 'config' not found"
        fi
    else
        print_fail "Cloud Map Namespace 'kong.local' not found"
    fi
}

# Main execution
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   Kong Gateway Deployment Verification               ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

check_control_plane
check_data_plane
check_cluster_connectivity
check_database
check_service_discovery

print_header "Summary"
echo ""
echo "For detailed logs:"
echo "  Control Plane: aws logs tail /fargate/kong-controlplane-logs --follow"
echo "  Data Plane:    aws logs tail /fargate/kong-dataplane-logs --follow"
echo ""
echo "To test admin API via data plane:"
echo "  curl -H \"apikey: YOUR-KEY\" http://\$ALB_DNS/admin-api/status"
echo ""
