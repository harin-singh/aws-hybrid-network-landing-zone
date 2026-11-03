# Complete Example - Full AWS Hybrid Network Landing Zone

This example deploys the complete architecture with all components:
- Transit Gateway with segmented routing
- Inspection VPC with AWS Network Firewall
- Shared Services VPC with Route 53 Resolver
- Prod and Non-prod spoke VPCs
- Site-to-Site VPN with BGP
- Simulated on-premises environment

## Architecture

```
                                 ┌─────────────────────────────────────────────────────────────┐
                                 │                        Internet                              │
                                 └─────────────────────────────┬───────────────────────────────┘
                                                               │
                                 ┌─────────────────────────────┼───────────────────────────────┐
                                 │                     Inspection VPC                          │
                                 │  ┌─────────────────────────┬┴┬─────────────────────────┐   │
                                 │  │        NAT Gateway      │ │      NAT Gateway         │   │
                                 │  └─────────────────────────┴┬┴─────────────────────────┘   │
                                 │                             │                               │
                                 │  ┌──────────────────────────┴───────────────────────────┐  │
                                 │  │              AWS Network Firewall                     │  │
                                 │  └──────────────────────────┬───────────────────────────┘  │
                                 │                             │                               │
                                 └─────────────────────────────┼───────────────────────────────┘
                                                               │
┌────────────────────┐         ┌───────────────────────────────┴───────────────────────────────┐
│  Simulated On-Prem │         │                       Transit Gateway                         │
│  ┌──────────────┐  │         │  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────────┐ │
│  │ strongSwan   │  │◄───────►│  │ On-Prem │  │   Prod   │  │ Nonprod │  │ Shared Services  │ │
│  │ + FRR (BGP)  │  │   VPN   │  │Route Tbl│  │Route Tbl │  │Route Tbl│  │   Route Table    │ │
│  └──────────────┘  │         │  └─────────┘  └──────────┘  └─────────┘  └──────────────────┘ │
│                    │         └───────────────────────────────┬───────────────────────────────┘
│  10.200.0.0/16     │                     │                   │                │
│  (advertised)      │                     │                   │                │
└────────────────────┘                     ▼                   ▼                ▼
                             ┌─────────────────┐  ┌────────────────┐  ┌──────────────────────┐
                             │    Prod VPC     │  │  Nonprod VPC   │  │ Shared Services VPC  │
                             │  10.10.0.0/24   │  │  10.20.0.0/24  │  │    10.1.0.0/24       │
                             │                 │  │                │  │                      │
                             │ ✓ → On-prem     │  │ ✗ → On-prem    │  │  Route 53 Resolver   │
                             │ ✓ → Shared Svc  │  │ ✓ → Shared Svc │  │  - Inbound endpoint  │
                             │ ✗ → Nonprod     │  │ ✗ → Prod       │  │  - Outbound endpoint │
                             └─────────────────┘  └────────────────┘  └──────────────────────┘
```

## Segmentation Rules

| Source | Destination | Allowed | Via |
|--------|-------------|---------|-----|
| Prod | Shared Services | ✓ | Inspection |
| Prod | Non-prod | ✗ | - |
| Prod | On-prem | ✓ | Inspection |
| Prod | Internet | ✓ | Inspection → NAT |
| Non-prod | Shared Services | ✓ | Inspection |
| Non-prod | Prod | ✗ | - |
| Non-prod | On-prem | ✗ | - |
| Non-prod | Internet | ✓ | Inspection → NAT |
| On-prem | Prod | ✓ | Inspection |
| On-prem | Shared Services | ✓ | Inspection |
| On-prem | Non-prod | ✗ | - |

## Cost Estimate

**This stack incurs hourly charges until destroyed.** Figures are us-east-1 public list, idle, 730 h/month. See the root README for sources and arithmetic.

| Resource | Hourly | Monthly (730h) |
|----------|--------|----------------|
| TGW attachments (5 × $0.05) | $0.25 | $182.50 |
| Network Firewall (2 endpoints × $0.395) | $0.79 | $576.70 |
| NAT Gateway (1 × $0.045) | $0.045 | $32.85 |
| Site-to-Site VPN | $0.05 | $36.50 |
| Resolver ENIs (4 × $0.125) | $0.50 | $365.00 |
| EC2 (t3.small + 3 × t3.micro) | $0.052 | $37.96 |
| Public IPv4 (4 × $0.005) | $0.02 | $14.60 |
| KMS (approx.) | — | $6 |
| **Idle total** | **~$1.71** | **~$1,252** |

Data processing is extra. There is no TGW charge beyond the five attachments. Network Firewall is per endpoint (two AZs). Resolver is per ENI (two endpoints × two AZs).

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0
- AWS account with permissions for VPC, EC2, TGW, Network Firewall

## Usage

```bash
# Initialize
terraform init

# Review plan
terraform plan

# Deploy
terraform apply

# Test connectivity (after deployment)
../../scripts/test-connectivity.sh

# IMPORTANT: Destroy when done to avoid costs
terraform destroy
```

## Connectivity Testing

After deployment, test the segmentation rules:

```bash
# Connect to prod instance via SSM
aws ssm start-session --target $(terraform output -raw prod_test_instance_id)

# From prod, test connectivity:
ping <nonprod_ip>        # Should FAIL (blocked)
ping <shared_services>   # Should SUCCEED
ping <onprem_test_ip>    # Should SUCCEED (via inspection)
curl -I https://aws.amazon.com  # Should SUCCEED (via NAT)

# Connect to nonprod instance
aws ssm start-session --target $(terraform output -raw nonprod_test_instance_id)

# From nonprod:
ping <prod_ip>           # Should FAIL (blocked)
ping <shared_services>   # Should SUCCEED
ping <onprem_test_ip>    # Should FAIL (blocked)
```

## Outputs

After deployment, key outputs include:
- Transit Gateway ID
- VPC IDs for all components
- Network Firewall endpoint IDs
- NAT Gateway public IPs (for allowlisting)
- Resolver inbound IPs (for on-prem DNS forwarding)
- Test instance IDs (for SSM sessions)
