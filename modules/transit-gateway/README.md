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
| [aws_cloudwatch_log_group.tgw_flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ec2_transit_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway) | resource |
| [aws_ec2_transit_gateway_route_table.inspection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table.nonprod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table.onprem](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table.prod](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_ec2_transit_gateway_route_table.shared_services](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table) | resource |
| [aws_flow_log.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_ram_principal_association.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.tgw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_amazon_side_asn"></a> [amazon\_side\_asn](#input\_amazon\_side\_asn) | Private ASN for the Amazon side of the TGW BGP sessions (64512-65534 or 4200000000-4294967294) | `number` | `64512` | no |
| <a name="input_auto_accept_shared_attachments"></a> [auto\_accept\_shared\_attachments](#input\_auto\_accept\_shared\_attachments) | Auto-accept attachments from accounts the TGW is shared with via RAM | `bool` | `true` | no |
| <a name="input_create_route_tables"></a> [create\_route\_tables](#input\_create\_route\_tables) | Create segmented route tables (prod, nonprod, shared-services, inspection, onprem) | `bool` | `true` | no |
| <a name="input_description"></a> [description](#input\_description) | Description for the Transit Gateway | `string` | `"Hub Transit Gateway for hybrid network landing zone"` | no |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Enable Transit Gateway flow logs | `bool` | `true` | no |
| <a name="input_enable_multicast"></a> [enable\_multicast](#input\_enable\_multicast) | Enable multicast support on the Transit Gateway | `bool` | `false` | no |
| <a name="input_flow_logs_aggregation_interval"></a> [flow\_logs\_aggregation\_interval](#input\_flow\_logs\_aggregation\_interval) | Maximum aggregation interval in seconds (60 or 600) | `number` | `60` | no |
| <a name="input_flow_logs_destination_type"></a> [flow\_logs\_destination\_type](#input\_flow\_logs\_destination\_type) | Destination type for flow logs: cloud-watch-logs or s3 | `string` | `"cloud-watch-logs"` | no |
| <a name="input_flow_logs_kms_key_id"></a> [flow\_logs\_kms\_key\_id](#input\_flow\_logs\_kms\_key\_id) | KMS key ID for encrypting flow logs | `string` | `null` | no |
| <a name="input_flow_logs_retention_days"></a> [flow\_logs\_retention\_days](#input\_flow\_logs\_retention\_days) | CloudWatch log retention in days for flow logs | `number` | `30` | no |
| <a name="input_flow_logs_s3_bucket_arn"></a> [flow\_logs\_s3\_bucket\_arn](#input\_flow\_logs\_s3\_bucket\_arn) | S3 bucket ARN for flow logs when destination\_type is s3 | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for Transit Gateway and related resources | `string` | n/a | yes |
| <a name="input_ram_allow_external_principals"></a> [ram\_allow\_external\_principals](#input\_ram\_allow\_external\_principals) | Allow sharing with principals outside the organization | `bool` | `false` | no |
| <a name="input_ram_principals"></a> [ram\_principals](#input\_ram\_principals) | List of principals (account IDs, OU ARNs, or Organization ARN) to share TGW with | `list(string)` | `[]` | no |
| <a name="input_share_tgw"></a> [share\_tgw](#input\_share\_tgw) | Share TGW via Resource Access Manager | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_amazon_side_asn"></a> [amazon\_side\_asn](#output\_amazon\_side\_asn) | Amazon side ASN configured on the Transit Gateway |
| <a name="output_flow_log_group_arn"></a> [flow\_log\_group\_arn](#output\_flow\_log\_group\_arn) | ARN of the CloudWatch log group for flow logs |
| <a name="output_flow_log_id"></a> [flow\_log\_id](#output\_flow\_log\_id) | ID of the Transit Gateway flow log |
| <a name="output_inspection_route_table_id"></a> [inspection\_route\_table\_id](#output\_inspection\_route\_table\_id) | ID of the inspection route table |
| <a name="output_nonprod_route_table_id"></a> [nonprod\_route\_table\_id](#output\_nonprod\_route\_table\_id) | ID of the non-production route table |
| <a name="output_onprem_route_table_id"></a> [onprem\_route\_table\_id](#output\_onprem\_route\_table\_id) | ID of the on-premises route table |
| <a name="output_prod_route_table_id"></a> [prod\_route\_table\_id](#output\_prod\_route\_table\_id) | ID of the production route table |
| <a name="output_ram_resource_share_arn"></a> [ram\_resource\_share\_arn](#output\_ram\_resource\_share\_arn) | ARN of the RAM resource share for the Transit Gateway |
| <a name="output_route_table_ids"></a> [route\_table\_ids](#output\_route\_table\_ids) | Map of route table names to IDs |
| <a name="output_shared_services_route_table_id"></a> [shared\_services\_route\_table\_id](#output\_shared\_services\_route\_table\_id) | ID of the shared services route table |
| <a name="output_transit_gateway_arn"></a> [transit\_gateway\_arn](#output\_transit\_gateway\_arn) | ARN of the Transit Gateway |
| <a name="output_transit_gateway_id"></a> [transit\_gateway\_id](#output\_transit\_gateway\_id) | ID of the Transit Gateway |
| <a name="output_transit_gateway_owner_id"></a> [transit\_gateway\_owner\_id](#output\_transit\_gateway\_owner\_id) | Owner ID of the Transit Gateway |
