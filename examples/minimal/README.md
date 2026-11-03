# Minimal Example - Cost-Optimized Deployment

A simplified, cost-optimized version of the hybrid network architecture.

## What's Included

- Transit Gateway with segmented route tables
- Egress VPC with single NAT Gateway (replaces inspection VPC)
- Shared Services VPC (no Route 53 Resolver endpoints)
- Prod and Non-prod spoke VPCs
- Single AZ deployment

## What's NOT Included

- AWS Network Firewall (biggest cost saver)
- Route 53 Resolver endpoints (4 ENIs × $0.125/h ≈ $365/month saved vs complete)
- VPN connection and simulated on-prem
- VPC Flow Logs
- SSM VPC Endpoints
- Multi-AZ redundancy

## Cost Estimate

| Resource | Hourly | Monthly (730h) |
|----------|--------|----------------|
| TGW attachments (4 × $0.05) | $0.20 | $146.00 |
| NAT Gateway (1 × $0.045) | $0.045 | $32.85 |
| **Idle total** | **~$0.25** | **~$179** |

*Does not include data transfer costs.*

## Usage

```bash
terraform init
terraform plan
terraform apply

# Destroy when done
terraform destroy
```

## Upgrading to Complete

To upgrade to the full architecture:

1. Add Network Firewall (inspection-vpc module)
2. Enable Route 53 Resolver endpoints
3. Add VPN and simulated on-prem
4. Enable multi-AZ
5. Enable flow logs

See [examples/complete](../complete/) for the full configuration.
