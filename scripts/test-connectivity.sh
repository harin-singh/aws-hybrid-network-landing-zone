#!/bin/bash
#------------------------------------------------------------------------------
# Connectivity Matrix Test Script
#
# Tests the segmentation rules after deployment:
# - Prod → Shared Services: ALLOW
# - Prod → On-prem: ALLOW  
# - Prod → Non-prod: DENY
# - Non-prod → Shared Services: ALLOW
# - Non-prod → Prod: DENY
# - Non-prod → On-prem: DENY
#
# Prerequisites:
# - AWS CLI configured
# - jq installed
# - Terraform deployed (run from examples/complete directory)
# - SSM plugin installed for AWS CLI
#------------------------------------------------------------------------------

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "AWS Hybrid Network Connectivity Tests"
echo "======================================"
echo

# Get instance IDs from Terraform outputs
echo "Fetching Terraform outputs..."
PROD_INSTANCE=$(terraform output -raw prod_test_instance_id 2>/dev/null || echo "")
NONPROD_INSTANCE=$(terraform output -raw nonprod_test_instance_id 2>/dev/null || echo "")
ONPREM_INSTANCE=$(terraform output -raw onprem_test_instance_id 2>/dev/null || echo "")

PROD_IP=$(terraform output -raw prod_test_instance_private_ip 2>/dev/null || echo "")
NONPROD_IP=$(terraform output -raw nonprod_test_instance_private_ip 2>/dev/null || echo "")
ONPREM_IP=$(terraform output -raw onprem_test_instance_private_ip 2>/dev/null || echo "")
SHARED_DNS_IP=$(terraform output -json resolver_inbound_ips 2>/dev/null | jq -r '.[0]' || echo "")

if [[ -z "$PROD_INSTANCE" ]]; then
    echo -e "${RED}Error: Could not get Terraform outputs. Run from examples/complete directory.${NC}"
    exit 1
fi

echo "Test instances:"
echo "  Prod:    $PROD_INSTANCE ($PROD_IP)"
echo "  Nonprod: $NONPROD_INSTANCE ($NONPROD_IP)"
echo "  On-prem: $ONPREM_INSTANCE ($ONPREM_IP)"
echo "  Shared:  $SHARED_DNS_IP"
echo

run_ssm_command() {
    local instance=$1
    local command=$2
    local timeout=${3:-30}
    
    aws ssm send-command \
        --instance-ids "$instance" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[\"$command\"]" \
        --timeout-seconds "$timeout" \
        --output text \
        --query "Command.CommandId"
}

wait_for_command() {
    local command_id=$1
    local instance=$2
    local max_wait=60
    local waited=0
    
    while [[ $waited -lt $max_wait ]]; do
        status=$(aws ssm get-command-invocation \
            --command-id "$command_id" \
            --instance-id "$instance" \
            --query "Status" \
            --output text 2>/dev/null || echo "Pending")
        
        if [[ "$status" == "Success" ]]; then
            return 0
        elif [[ "$status" == "Failed" || "$status" == "Cancelled" || "$status" == "TimedOut" ]]; then
            return 1
        fi
        
        sleep 2
        waited=$((waited + 2))
    done
    
    return 1
}

test_connectivity() {
    local source_instance=$1
    local source_name=$2
    local target_ip=$3
    local target_name=$4
    local expected=$5  # "allow" or "deny"
    
    echo -n "Testing $source_name → $target_name ($target_ip)... "
    
    command_id=$(run_ssm_command "$source_instance" "ping -c 2 -W 3 $target_ip")
    
    if wait_for_command "$command_id" "$source_instance"; then
        if [[ "$expected" == "allow" ]]; then
            echo -e "${GREEN}PASS${NC} (reachable as expected)"
            return 0
        else
            echo -e "${RED}FAIL${NC} (reachable but should be blocked)"
            return 1
        fi
    else
        if [[ "$expected" == "deny" ]]; then
            echo -e "${GREEN}PASS${NC} (blocked as expected)"
            return 0
        else
            echo -e "${RED}FAIL${NC} (blocked but should be reachable)"
            return 1
        fi
    fi
}

echo "======================================"
echo "Running Connectivity Matrix Tests"
echo "======================================"
echo

PASSED=0
FAILED=0

# Prod tests
echo "--- From Production VPC ---"
if test_connectivity "$PROD_INSTANCE" "Prod" "$SHARED_DNS_IP" "Shared Services" "allow"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

if test_connectivity "$PROD_INSTANCE" "Prod" "$NONPROD_IP" "Non-prod" "deny"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

if test_connectivity "$PROD_INSTANCE" "Prod" "$ONPREM_IP" "On-prem" "allow"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

echo

# Nonprod tests
echo "--- From Non-Production VPC ---"
if test_connectivity "$NONPROD_INSTANCE" "Nonprod" "$SHARED_DNS_IP" "Shared Services" "allow"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

if test_connectivity "$NONPROD_INSTANCE" "Nonprod" "$PROD_IP" "Prod" "deny"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

if test_connectivity "$NONPROD_INSTANCE" "Nonprod" "$ONPREM_IP" "On-prem" "deny"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

echo

# On-prem tests  
echo "--- From On-Premises (Simulated) ---"
if test_connectivity "$ONPREM_INSTANCE" "On-prem" "$SHARED_DNS_IP" "Shared Services" "allow"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

if test_connectivity "$ONPREM_INSTANCE" "On-prem" "$PROD_IP" "Prod" "allow"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

if test_connectivity "$ONPREM_INSTANCE" "On-prem" "$NONPROD_IP" "Non-prod" "deny"; then
    PASSED=$((PASSED + 1))
else
    FAILED=$((FAILED + 1))
fi

echo
echo "======================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "======================================"

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
