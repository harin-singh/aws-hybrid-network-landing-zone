# Deploy and verify (complete example)

Run this in a disposable AWS account. The stack is not free. Tear it down when you are done.

Estimated **idle** cost in us-east-1: **about $1.71 per hour** (~$41 per day). See the README cost table for the arithmetic. Data processing and CloudWatch ingestion are extra.

This runbook does not include captured command output. After you apply, save the real `test-connectivity.sh` transcript under `docs/evidence/`.

## Prerequisites

- AWS credentials for a sandbox account (`aws sts get-caller-identity`)
- Terraform >= 1.5
- `jq`
- Session Manager plugin (only needed for interactive SSM; the script uses `aws ssm send-command`)
- Region: `us-east-1` unless you change `aws_region` (cost table is us-east-1)

## 1. Apply

```bash
cd examples/complete
cp terraform.tfvars.example terraform.tfvars
# Optional: set aws_region = "us-east-1" to match the README cost table
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

First apply can take 20–40 minutes (Network Firewall endpoints and VPN).

## 2. Wait for VPN/BGP

```bash
../../scripts/check-vpn-status.sh
```

Both tunnels and BGP should be up before connectivity tests that involve on-prem. Prod↔nonprod deny tests do not need VPN.

## 3. Run the connectivity matrix

From `examples/complete`:

```bash
mkdir -p ../../docs/evidence
../../scripts/test-connectivity.sh | tee ../../docs/evidence/connectivity-$(date -u +%Y%m%dT%H%M%SZ).txt
```

The script prints `RESULT: PASS` or `RESULT: FAIL` and exits 0/1. Expected rows:

| Source | Destination | Expected |
|--------|-------------|----------|
| Prod | Shared Services | allow |
| Prod | Non-prod | deny |
| Prod | On-prem | allow |
| Non-prod | Shared Services | allow |
| Non-prod | Prod | deny |
| Non-prod | On-prem | deny |
| On-prem | Shared Services | allow |
| On-prem | Prod | allow |
| On-prem | Non-prod | deny |

Do not commit fabricated evidence files.

## 4. Destroy

```bash
cd examples/complete
terraform destroy
```

Confirm in the console that the Transit Gateway, Network Firewall, NAT Gateway, VPN, and Resolver endpoints are gone; those five line items are most of the hourly cost.

If destroy fails on Network Firewall or VPN, retry `terraform destroy` after the delete-protection/ENI cleanup finishes (often a few minutes).

## What you cannot verify without AWS

`terraform test`, `terraform validate`, `tflint`, and `checkov` run offline in CI. They do not prove live packet drops. Only a real apply plus `scripts/test-connectivity.sh` does that.
