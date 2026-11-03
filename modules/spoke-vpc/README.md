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
| [aws_route.default_to_tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.tgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.tgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.vpc_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.tgw_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.ec2_messages](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ssm_messages](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of AZs to use (if null, auto-selects based on az\_count) | `list(string)` | `null` | no |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of AZs to use when availability\_zones is null | `number` | `2` | no |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | VPC CIDR block (required if not using IPAM) | `string` | `null` | no |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Enable VPC flow logs | `bool` | `true` | no |
| <a name="input_enable_ssm_endpoints"></a> [enable\_ssm\_endpoints](#input\_enable\_ssm\_endpoints) | Create VPC endpoints for SSM, SSM Messages, and EC2 Messages | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (prod, nonprod, shared-services) | `string` | n/a | yes |
| <a name="input_flow_logs_kms_key_id"></a> [flow\_logs\_kms\_key\_id](#input\_flow\_logs\_kms\_key\_id) | KMS key ID for encrypting flow logs | `string` | `null` | no |
| <a name="input_flow_logs_retention_days"></a> [flow\_logs\_retention\_days](#input\_flow\_logs\_retention\_days) | CloudWatch log retention in days | `number` | `30` | no |
| <a name="input_ipam_netmask_length"></a> [ipam\_netmask\_length](#input\_ipam\_netmask\_length) | Netmask length when using IPAM | `number` | `24` | no |
| <a name="input_ipam_pool_id"></a> [ipam\_pool\_id](#input\_ipam\_pool\_id) | IPAM pool ID for CIDR allocation | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for VPC and related resources | `string` | n/a | yes |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | List of CIDR blocks for private subnets (if null, calculated from VPC CIDR) | `list(string)` | `null` | no |
| <a name="input_private_subnet_newbits"></a> [private\_subnet\_newbits](#input\_private\_subnet\_newbits) | Number of additional bits for private subnet calculation | `number` | `4` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for VPC endpoints | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_tgw_propagation_route_table_ids"></a> [tgw\_propagation\_route\_table\_ids](#input\_tgw\_propagation\_route\_table\_ids) | List of TGW route table IDs to propagate this VPC's routes to | `list(string)` | `[]` | no |
| <a name="input_tgw_route_table_id"></a> [tgw\_route\_table\_id](#input\_tgw\_route\_table\_id) | TGW route table ID to associate this VPC's attachment with | `string` | `null` | no |
| <a name="input_tgw_subnet_cidrs"></a> [tgw\_subnet\_cidrs](#input\_tgw\_subnet\_cidrs) | List of CIDR blocks for TGW attachment subnets | `list(string)` | `null` | no |
| <a name="input_tgw_subnet_newbits"></a> [tgw\_subnet\_newbits](#input\_tgw\_subnet\_newbits) | Number of additional bits for TGW subnet calculation | `number` | `8` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | Transit Gateway ID for attachment | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | List of availability zones used |
| <a name="output_flow_log_group_arn"></a> [flow\_log\_group\_arn](#output\_flow\_log\_group\_arn) | ARN of the VPC flow logs CloudWatch log group |
| <a name="output_private_route_table_id"></a> [private\_route\_table\_id](#output\_private\_route\_table\_id) | ID of the private route table |
| <a name="output_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#output\_private\_subnet\_cidrs) | List of private subnet CIDR blocks |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | List of private subnet IDs |
| <a name="output_tgw_attachment_id"></a> [tgw\_attachment\_id](#output\_tgw\_attachment\_id) | ID of the Transit Gateway VPC attachment |
| <a name="output_tgw_attachment_subnet_ids"></a> [tgw\_attachment\_subnet\_ids](#output\_tgw\_attachment\_subnet\_ids) | List of TGW attachment subnet IDs |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR block of the VPC |
| <a name="output_vpc_endpoints_security_group_id"></a> [vpc\_endpoints\_security\_group\_id](#output\_vpc\_endpoints\_security\_group\_id) | ID of the VPC endpoints security group |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |
