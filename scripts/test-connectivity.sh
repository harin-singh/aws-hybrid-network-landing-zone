#!/bin/bash
#------------------------------------------------------------------------------
# Connectivity matrix for examples/complete
#
# Expected results (must match README traffic table and TGW/firewall rules):
#   Prod     → Shared Services  ALLOW
#   Prod     → Non-prod         DENY
#   Prod     → On-prem          ALLOW
#   Non-prod → Shared Services  ALLOW
#   Non-prod → Prod             DENY
#   Non-prod → On-prem          DENY
#   On-prem  → Shared Services  ALLOW
#   On-prem  → Prod             ALLOW
#   On-prem  → Non-prod         DENY
#
# Run from examples/complete after terraform apply.
# Capture: ./scripts/test-connectivity.sh | tee ../../docs/evidence/connectivity-$(date -u +%Y%m%dT%H%M%SZ).txt
#------------------------------------------------------------------------------

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ROOT_ERR=0
PASSED=0
FAILED=0
SKIPPED=0
declare -a RESULTS

echo "======================================"
echo "AWS Hybrid Network Connectivity Tests"
echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "======================================"
echo

if [[ ! -f "terraform.tfstate" && ! -d ".terraform" ]]; then
    echo -e "${RED}Error: run this script from examples/complete after terraform apply.${NC}"
    echo "  cd examples/complete && ../../scripts/test-connectivity.sh"
    exit 1
fi

echo "Fetching Terraform outputs..."
PROD_INSTANCE=$(terraform output -raw prod_test_instance_id 2>/dev/null || echo "")
NONPROD_INSTANCE=$(terraform output -raw nonprod_test_instance_id 2>/dev/null || echo "")
ONPREM_INSTANCE=$(terraform output -raw onprem_test_instance_id 2>/dev/null || echo "")

PROD_IP=$(terraform output -raw prod_test_instance_private_ip 2>/dev/null || echo "")
NONPROD_IP=$(terraform output -raw nonprod_test_instance_private_ip 2>/dev/null || echo "")
ONPREM_IP=$(terraform output -raw onprem_test_instance_private_ip 2>/dev/null || echo "")
SHARED_DNS_IP=$(terraform output -json resolver_inbound_ips 2>/dev/null | jq -r '.[0] // empty' || echo "")

if [[ -z "$PROD_INSTANCE" ]]; then
    echo -e "${RED}Error: Could not read Terraform outputs. Run from examples/complete.${NC}"
    exit 1
fi

echo "Test instances:"
echo "  Prod:    ${PROD_INSTANCE} (${PROD_IP})"
echo "  Nonprod: ${NONPROD_INSTANCE} (${NONPROD_IP})"
echo "  On-prem: ${ONPREM_INSTANCE} (${ONPREM_IP})"
echo "  Shared:  ${SHARED_DNS_IP}"
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

record() {
    local name=$1
    local result=$2
    RESULTS+=("$result|$name")
    case "$result" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
        SKIP) SKIPPED=$((SKIPPED + 1)) ;;
    esac
}

test_connectivity() {
    local source_instance=$1
    local source_name=$2
    local target_ip=$3
    local target_name=$4
    local expected=$5

    local label="$source_name → $target_name ($expected)"

    if [[ -z "$source_instance" || -z "$target_ip" || "$target_ip" == "null" ]]; then
        echo -e "${YELLOW}SKIP${NC} $label (missing instance or IP)"
        record "$label" "SKIP"
        return 0
    fi

    echo -n "Testing $label ($target_ip)... "

    local command_id
    if ! command_id=$(run_ssm_command "$source_instance" "ping -c 2 -W 3 $target_ip"); then
        echo -e "${RED}FAIL${NC} (SSM send-command failed)"
        record "$label" "FAIL"
        return 1
    fi

    if wait_for_command "$command_id" "$source_instance"; then
        if [[ "$expected" == "allow" ]]; then
            echo -e "${GREEN}PASS${NC} (reachable as expected)"
            record "$label" "PASS"
            return 0
        else
            echo -e "${RED}FAIL${NC} (reachable but should be blocked)"
            record "$label" "FAIL"
            return 1
        fi
    else
        if [[ "$expected" == "deny" ]]; then
            echo -e "${GREEN}PASS${NC} (blocked as expected)"
            record "$label" "PASS"
            return 0
        else
            echo -e "${RED}FAIL${NC} (blocked but should be reachable)"
            record "$label" "FAIL"
            return 1
        fi
    fi
}

echo "======================================"
echo "Running Connectivity Matrix Tests"
echo "======================================"
echo

echo "--- From Production VPC ---"
test_connectivity "$PROD_INSTANCE" "Prod" "$SHARED_DNS_IP" "Shared Services" "allow"
test_connectivity "$PROD_INSTANCE" "Prod" "$NONPROD_IP" "Non-prod" "deny"
test_connectivity "$PROD_INSTANCE" "Prod" "$ONPREM_IP" "On-prem" "allow"
echo

echo "--- From Non-Production VPC ---"
test_connectivity "$NONPROD_INSTANCE" "Nonprod" "$SHARED_DNS_IP" "Shared Services" "allow"
test_connectivity "$NONPROD_INSTANCE" "Nonprod" "$PROD_IP" "Prod" "deny"
test_connectivity "$NONPROD_INSTANCE" "Nonprod" "$ONPREM_IP" "On-prem" "deny"
echo

echo "--- From On-Premises (Simulated) ---"
test_connectivity "$ONPREM_INSTANCE" "On-prem" "$SHARED_DNS_IP" "Shared Services" "allow"
test_connectivity "$ONPREM_INSTANCE" "On-prem" "$PROD_IP" "Prod" "allow"
test_connectivity "$ONPREM_INSTANCE" "On-prem" "$NONPROD_IP" "Non-prod" "deny"
echo

echo "======================================"
echo "SUMMARY"
echo "======================================"
for row in "${RESULTS[@]+"${RESULTS[@]}"}"; do
    result="${row%%|*}"
    name="${row#*|}"
    case "$result" in
        PASS) echo -e "  ${GREEN}PASS${NC}  $name" ;;
        FAIL) echo -e "  ${RED}FAIL${NC}  $name" ;;
        SKIP) echo -e "  ${YELLOW}SKIP${NC}  $name" ;;
    esac
done
echo
echo "Passed: $PASSED   Failed: $FAILED   Skipped: $SKIPPED"
echo "Finished: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}RESULT: FAIL${NC}"
    exit 1
fi

if [[ $PASSED -eq 0 ]]; then
    echo -e "${RED}RESULT: FAIL (no tests ran)${NC}"
    exit 1
fi

echo -e "${GREEN}RESULT: PASS${NC}"
exit 0
