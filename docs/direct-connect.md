# Direct Connect Integration

**Design document only. Nothing in this file is created by Terraform in this repository.** The lab hybrid path is Site-to-Site VPN (`modules/site-to-site-vpn` + `modules/simulated-onprem`). Use this note if you are replacing that VPN attachment with a DX Gateway + transit VIF.

This document explains how AWS Direct Connect would integrate with the same TGW route tables. Direct Connect is the usual production choice for hybrid connectivity; it is not part of `examples/complete` or `examples/minimal`.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           On-Premises Data Center                           │
│  ┌─────────────────┐                                                        │
│  │  Core Router    │──── BGP ────┐                                          │
│  │  (ASN 65000)    │             │                                          │
│  └─────────────────┘             │                                          │
└──────────────────────────────────┼──────────────────────────────────────────┘
                                   │
                          ┌────────┴────────┐
                          │ Direct Connect  │
                          │    Location     │
                          └────────┬────────┘
                                   │
                          ┌────────┴────────┐
                          │  DX Connection  │
                          │   (1-100 Gbps)  │
                          └────────┬────────┘
                                   │
                          ┌────────┴────────┐
                          │   DX Gateway    │
                          └────────┬────────┘
                                   │
                          ┌────────┴────────┐
                          │  Transit VIF    │
                          │ (VLAN + BGP)    │
                          └────────┬────────┘
                                   │
                          ┌────────┴────────┐
                          │ Transit Gateway │
                          │  (ASN 64512)    │
                          └────────┬────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
        ┌─────┴─────┐        ┌─────┴─────┐       ┌─────┴─────┐
        │ Prod VPC  │        │ Nonprod   │       │  Shared   │
        └───────────┘        │   VPC     │       │ Services  │
                             └───────────┘       └───────────┘
```

## Key Components

### DX Connection
Physical connection at a Direct Connect location (colocation facility). Options:
- **Dedicated**: 1, 10, or 100 Gbps - you own the port
- **Hosted**: Sub-1 Gbps or hosted 1/10 Gbps via a partner

### DX Gateway
Regional resource that bridges DX connections to VPCs or Transit Gateways. Required for Transit Gateway association.

### Transit Virtual Interface (Transit VIF)
A virtual interface on the DX connection associated with a DX Gateway. Carries BGP sessions and routes traffic to/from the Transit Gateway.

## Terraform Configuration (not implemented)

There is no `modules/dx-gateway` in this repo. The HCL below is illustrative.

### DX Gateway (conceptual)

```hcl
module "dx_gateway" {
  source = "./modules/dx-gateway"  # not in this repository

  name            = "hybrid-network-dxgw"
  amazon_side_asn = 64512

  # Associate with Transit Gateway
  transit_gateway_id = module.transit_gateway.transit_gateway_id

  # Allowed prefixes from on-premises
  allowed_prefixes = [
    "10.200.0.0/16",  # On-prem data center
    "10.201.0.0/16",  # On-prem DR site
  ]
}

# Transit VIF configuration (managed by AWS partner or in console)
# This Terraform just documents the expected configuration
resource "aws_dx_transit_virtual_interface" "main" {
  connection_id  = var.dx_connection_id  # Existing DX connection
  dx_gateway_id  = aws_dx_gateway.this.id
  name           = "hybrid-network-transit-vif"
  vlan           = 100
  address_family = "ipv4"
  bgp_asn        = 65000  # On-premises ASN
  mtu            = 9001   # Jumbo frames supported on DX
}
```

### Route Propagation

With DX, routes propagate the same way as VPN:

```hcl
# DX Gateway association with TGW (replaces VPN attachment)
resource "aws_dx_gateway_association" "tgw" {
  dx_gateway_id         = aws_dx_gateway.this.id
  associated_gateway_id = module.transit_gateway.transit_gateway_id

  allowed_prefixes = var.allowed_prefixes
}

# Routes from on-prem propagate to these route tables
# (Same as VPN configuration in this project)
resource "aws_ec2_transit_gateway_route_table_propagation" "dx_to_prod" {
  transit_gateway_attachment_id  = aws_dx_gateway_association.tgw.id
  transit_gateway_route_table_id = module.transit_gateway.prod_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "dx_to_shared" {
  transit_gateway_attachment_id  = aws_dx_gateway_association.tgw.id
  transit_gateway_route_table_id = module.transit_gateway.shared_services_route_table_id
}

# On-prem route table association
resource "aws_ec2_transit_gateway_route_table_association" "dx" {
  transit_gateway_attachment_id  = aws_dx_gateway_association.tgw.id
  transit_gateway_route_table_id = module.transit_gateway.onprem_route_table_id
}
```

## VPN vs Direct Connect Comparison

| Aspect | Site-to-Site VPN | Direct Connect |
|--------|------------------|----------------|
| **Bandwidth** | Up to 1.25 Gbps/tunnel | 1-100 Gbps |
| **Latency** | Variable (internet) | Consistent, low |
| **Encryption** | IPsec built-in | Optional (MACsec) |
| **Failover** | Seconds (BGP) | Depends on setup |
| **Cost** | ~$0.05/hour/connection | ~$0.30/hour/port + data |
| **Setup time** | Minutes | Weeks-months |
| **Use case** | DR, backup, dev/test | Production, high bandwidth |

## High Availability Patterns

### Active/Active with VPN Backup

```
                    ┌─────────────────┐
                    │   On-Premises   │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────┴─────┐  ┌─────┴─────┐  ┌─────┴─────┐
        │  DX #1    │  │  DX #2    │  │   VPN     │
        │ (Primary) │  │ (Primary) │  │ (Backup)  │
        └─────┬─────┘  └─────┬─────┘  └─────┬─────┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────┴────────┐
                    │ Transit Gateway │
                    └─────────────────┘
```

- Two DX connections at different locations (diversified paths)
- VPN over internet as backup (lower BGP preference)
- Equal-cost multipath (ECMP) between DX connections

### BGP Configuration for Failover

```
# On-premises router configuration (example)
router bgp 65000
  neighbor <dx1-aws-ip> remote-as 64512
  neighbor <dx1-aws-ip> route-map PREFER-DX out
  
  neighbor <dx2-aws-ip> remote-as 64512
  neighbor <dx2-aws-ip> route-map PREFER-DX out
  
  neighbor <vpn-aws-ip> remote-as 64512
  neighbor <vpn-aws-ip> route-map BACKUP out

route-map PREFER-DX permit 10
  set as-path prepend 65000

route-map BACKUP permit 10
  set as-path prepend 65000 65000 65000
```

## Migration from VPN to DX

1. **Establish DX connection** (4-6 weeks lead time)
2. **Create DX Gateway and Transit VIF**
3. **Associate DX Gateway with Transit Gateway**
4. **Verify route propagation** (both directions)
5. **Adjust BGP preferences** to prefer DX
6. **Monitor traffic shift**
7. **Keep VPN as backup** or decommission

The Transit Gateway route tables don't change - the DX attachment simply replaces or supplements the VPN attachment in the `onprem` route table.

## Cost Considerations

### Direct Connect Pricing (us-west-2 example)

| Component | Cost |
|-----------|------|
| DX Port (1 Gbps) | $0.30/hour (~$219/month) |
| DX Port (10 Gbps) | $2.25/hour (~$1,643/month) |
| DX Data Out | $0.02/GB |
| DX Gateway | Free |
| Transit VIF | Free |
| TGW Attachment | $0.05/hour (~$37/month) |
| TGW Data | $0.02/GB |

### When DX Makes Sense

- Consistent > 100 Mbps traffic to AWS
- Latency-sensitive applications
- Large data transfers (backup, replication)
- Compliance requirements for dedicated connectivity

### When VPN is Sufficient

- < 100 Mbps traffic
- Development/test environments
- DR/backup connectivity
- Quick setup needed
