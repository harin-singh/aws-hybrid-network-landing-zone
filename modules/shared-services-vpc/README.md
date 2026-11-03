## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.71.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ec2_transit_gateway_route_table_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_ec2_transit_gateway_vpc_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_vpc_attachment) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_ram_principal_association.resolver_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.resolver_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.resolver_rules](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |
| [aws_route.default_to_tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route53_resolver_endpoint.inbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_endpoint) | resource |
| [aws_route53_resolver_endpoint.outbound](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_endpoint) | resource |
| [aws_route53_resolver_rule.forward](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_rule) | resource |
| [aws_route53_zone.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.tgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.tgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.resolver](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.tgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of AZs to use | `list(string)` | `null` | no |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of AZs to use when availability\_zones is null | `number` | `2` | no |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | VPC CIDR block | `string` | n/a | yes |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Enable VPC flow logs | `bool` | `true` | no |
| <a name="input_enable_forwarding_rules"></a> [enable\_forwarding\_rules](#input\_enable\_forwarding\_rules) | Create Route 53 Resolver forwarding rules for on-prem domains | `bool` | `true` | no |
| <a name="input_enable_private_zones"></a> [enable\_private\_zones](#input\_enable\_private\_zones) | Create Route 53 private hosted zones | `bool` | `true` | no |
| <a name="input_enable_resolver_endpoints"></a> [enable\_resolver\_endpoints](#input\_enable\_resolver\_endpoints) | Create Route 53 Resolver inbound and outbound endpoints | `bool` | `true` | no |
| <a name="input_flow_logs_retention_days"></a> [flow\_logs\_retention\_days](#input\_flow\_logs\_retention\_days) | CloudWatch log retention in days | `number` | `30` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ID for log encryption | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for shared services VPC and related resources | `string` | n/a | yes |
| <a name="input_onprem_dns_servers"></a> [onprem\_dns\_servers](#input\_onprem\_dns\_servers) | List of on-premises DNS server IPs | `list(string)` | <pre>[<br>  "10.200.0.10",<br>  "10.200.0.11"<br>]</pre> | no |
| <a name="input_onprem_domains"></a> [onprem\_domains](#input\_onprem\_domains) | List of on-premises domains to forward DNS queries for | `list(string)` | <pre>[<br>  "corp.example.internal"<br>]</pre> | no |
| <a name="input_private_zone_names"></a> [private\_zone\_names](#input\_private\_zone\_names) | List of private hosted zone domain names | `list(string)` | <pre>[<br>  "aws.example.internal"<br>]</pre> | no |
| <a name="input_ram_allow_external_principals"></a> [ram\_allow\_external\_principals](#input\_ram\_allow\_external\_principals) | Allow sharing with principals outside the organization | `bool` | `false` | no |
| <a name="input_ram_principals"></a> [ram\_principals](#input\_ram\_principals) | List of principals to share resolver rules with | `list(string)` | `[]` | no |
| <a name="input_resolver_allowed_cidrs"></a> [resolver\_allowed\_cidrs](#input\_resolver\_allowed\_cidrs) | CIDRs allowed to query the inbound resolver endpoint | `list(string)` | <pre>[<br>  "10.0.0.0/8",<br>  "172.16.0.0/12",<br>  "192.168.0.0/16"<br>]</pre> | no |
| <a name="input_share_resolver_rules"></a> [share\_resolver\_rules](#input\_share\_resolver\_rules) | Share resolver rules via RAM | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_tgw_propagation_route_table_ids"></a> [tgw\_propagation\_route\_table\_ids](#input\_tgw\_propagation\_route\_table\_ids) | List of TGW route table IDs to propagate this VPC's routes to | `list(string)` | `[]` | no |
| <a name="input_tgw_route_table_id"></a> [tgw\_route\_table\_id](#input\_tgw\_route\_table\_id) | TGW route table ID to associate this VPC's attachment with | `string` | `null` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | Transit Gateway ID for attachment | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | List of availability zones used |
| <a name="output_flow_log_group_arn"></a> [flow\_log\_group\_arn](#output\_flow\_log\_group\_arn) | ARN of the VPC flow logs CloudWatch log group |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of private subnet IDs |
| <a name="output_private_zone_ids"></a> [private\_zone\_ids](#output\_private\_zone\_ids) | Map of zone name to zone ID |
| <a name="output_private_zone_name_servers"></a> [private\_zone\_name\_servers](#output\_private\_zone\_name\_servers) | Map of zone name to name servers |
| <a name="output_resolver_inbound_endpoint_id"></a> [resolver\_inbound\_endpoint\_id](#output\_resolver\_inbound\_endpoint\_id) | ID of the Route 53 Resolver inbound endpoint |
| <a name="output_resolver_inbound_endpoint_ips"></a> [resolver\_inbound\_endpoint\_ips](#output\_resolver\_inbound\_endpoint\_ips) | IP addresses of the inbound resolver endpoint |
| <a name="output_resolver_outbound_endpoint_id"></a> [resolver\_outbound\_endpoint\_id](#output\_resolver\_outbound\_endpoint\_id) | ID of the Route 53 Resolver outbound endpoint |
| <a name="output_resolver_rule_arns"></a> [resolver\_rule\_arns](#output\_resolver\_rule\_arns) | Map of domain to resolver rule ARN |
| <a name="output_resolver_rule_ids"></a> [resolver\_rule\_ids](#output\_resolver\_rule\_ids) | Map of domain to resolver rule ID |
| <a name="output_resolver_rules_ram_share_arn"></a> [resolver\_rules\_ram\_share\_arn](#output\_resolver\_rules\_ram\_share\_arn) | ARN of the RAM share for resolver rules |
| <a name="output_resolver_subnet_ids"></a> [resolver\_subnet\_ids](#output\_resolver\_subnet\_ids) | List of resolver subnet IDs |
| <a name="output_tgw_attachment_id"></a> [tgw\_attachment\_id](#output\_tgw\_attachment\_id) | ID of the Transit Gateway VPC attachment |
| <a name="output_tgw_attachment_subnet_ids"></a> [tgw\_attachment\_subnet\_ids](#output\_tgw\_attachment\_subnet\_ids) | List of TGW attachment subnet IDs |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR block of the VPC |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the shared services VPC |
