#!/bin/bash
#------------------------------------------------------------------------------
# VPN Status Check Script
#
# Checks the status of:
# - VPN connection tunnels
# - BGP sessions
# - Route propagation
#------------------------------------------------------------------------------

set -e

echo "======================================"
echo "VPN and BGP Status Check"
echo "======================================"
echo

# Get VPN connection ID from Terraform
VPN_ID=$(terraform output -raw vpn_connection_id 2>/dev/null || echo "")
ROUTER_INSTANCE=$(terraform output -raw onprem_router_instance_id 2>/dev/null || echo "")

if [[ -z "$VPN_ID" ]]; then
    echo "Error: Could not get VPN connection ID from Terraform outputs."
    echo "Run this script from the examples/complete directory after deployment."
    exit 1
fi

echo "VPN Connection: $VPN_ID"
echo

# Check VPN tunnel status
echo "--- VPN Tunnel Status ---"
aws ec2 describe-vpn-connections \
    --vpn-connection-ids "$VPN_ID" \
    --query 'VpnConnections[0].VgwTelemetry[*].{Tunnel:OutsideIpAddress,Status:Status,StatusMessage:StatusMessage}' \
    --output table

echo

# Check BGP routes on router via SSM
echo "--- BGP Status (On-Prem Router) ---"
if [[ -n "$ROUTER_INSTANCE" ]]; then
    echo "Fetching BGP summary from router..."
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$ROUTER_INSTANCE" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["sudo vtysh -c \"show bgp summary\""]' \
        --output text \
        --query "Command.CommandId")
    
    sleep 5
    
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$ROUTER_INSTANCE" \
        --query "StandardOutputContent" \
        --output text 2>/dev/null || echo "Could not retrieve BGP status"
    
    echo
    echo "--- BGP Advertised Routes ---"
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids "$ROUTER_INSTANCE" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["sudo vtysh -c \"show ip route\""]' \
        --output text \
        --query "Command.CommandId")
    
    sleep 5
    
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$ROUTER_INSTANCE" \
        --query "StandardOutputContent" \
        --output text 2>/dev/null || echo "Could not retrieve routes"
else
    echo "Router instance ID not found in Terraform outputs."
fi

echo

# Check TGW route table for propagated routes
echo "--- Transit Gateway Routes ---"
TGW_ID=$(terraform output -raw transit_gateway_id 2>/dev/null || echo "")

if [[ -n "$TGW_ID" ]]; then
    ROUTE_TABLES=$(aws ec2 describe-transit-gateway-route-tables \
        --filters "Name=transit-gateway-id,Values=$TGW_ID" \
        --query 'TransitGatewayRouteTables[*].TransitGatewayRouteTableId' \
        --output text)
    
    for rt in $ROUTE_TABLES; do
        echo "Route Table: $rt"
        aws ec2 search-transit-gateway-routes \
            --transit-gateway-route-table-id "$rt" \
            --filters "Name=type,Values=propagated,static" \
            --query 'Routes[*].{CIDR:DestinationCidrBlock,Type:Type,State:State}' \
            --output table 2>/dev/null || echo "  No routes found"
        echo
    done
else
    echo "Transit Gateway ID not found."
fi
