# Multi-account example

Network account owns the Transit Gateway and inspection VPC and shares the TGW via RAM. One workload account creates a spoke VPC and attaches to that TGW. Route table association stays in the network account (TGW owner). An Organizations SCP denies TGW and route-table mutation outside the network account.

This configuration is `terraform validate`-able without live accounts. Apply requires three provider identities (management, network, workload) or a single sandbox with the assume-role ARNs left null.

## Providers

| Alias | Account | Resources |
|-------|---------|-----------|
| `aws.management` | Organizations management | SCP |
| `aws.network` | Network hub | TGW, inspection VPC, RAM share, attachment association |
| `aws.workload` | Workload | Spoke VPC + TGW attachment |

Set `network_assume_role_arn`, `workload_assume_role_arn`, and `management_assume_role_arn` to `arn:aws:iam::<account-id>:role/OrganizationAccountAccessRole` (or equivalent). Leave them `null` to use the caller identity for validate/plan.

## SCP

`policies/protect-network-hub.json` denies create/delete/modify of Transit Gateways, TGW route tables, TGW routes, associations, propagations, and VPC attachments unless `aws:PrincipalAccount` is the network account.

The policy is always created. It is attached only when `scp_target_id` is set (typically a workload OU). Do not attach it to the network account.

Workload `terraform destroy` of the attachment is denied by this SCP on purpose: attachment teardown belongs to the network account (or a network-account role assumed from automation).

## Apply

```bash
cp terraform.tfvars.example terraform.tfvars
# fill account IDs and role ARNs
terraform init
terraform plan
terraform apply
```

Destroy from the same config. If the SCP is attached, delete the workload attachment with the network provider first or detach the SCP.
