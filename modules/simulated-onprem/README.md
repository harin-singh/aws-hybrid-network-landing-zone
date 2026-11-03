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
| [aws_eip.router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_iam_instance_profile.router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_instance.test](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_network_interface.router_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_interface) | resource |
| [aws_network_interface.router_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_interface) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.router](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.test_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_ami.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | Availability zone for the VPC (if null, auto-selects first available) | `string` | `null` | no |
| <a name="input_aws_bgp_asn"></a> [aws\_bgp\_asn](#input\_aws\_bgp\_asn) | BGP ASN on the AWS side (Transit Gateway) | `number` | `64512` | no |
| <a name="input_create_test_instance"></a> [create\_test\_instance](#input\_create\_test\_instance) | Create a test instance in the private subnet | `bool` | `true` | no |
| <a name="input_customer_bgp_asn"></a> [customer\_bgp\_asn](#input\_customer\_bgp\_asn) | BGP ASN for the simulated on-premises router | `number` | `65000` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for the router | `string` | `"t3.small"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for simulated on-premises resources | `string` | n/a | yes |
| <a name="input_onprem_cidr_to_advertise"></a> [onprem\_cidr\_to\_advertise](#input\_onprem\_cidr\_to\_advertise) | On-premises CIDR to advertise via BGP (e.g., 10.200.0.0/16) | `string` | `"10.200.0.0/16"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_tunnel1_aws_endpoint"></a> [tunnel1\_aws\_endpoint](#input\_tunnel1\_aws\_endpoint) | AWS VPN endpoint IP for tunnel 1 | `string` | `""` | no |
| <a name="input_tunnel1_aws_inside_ip"></a> [tunnel1\_aws\_inside\_ip](#input\_tunnel1\_aws\_inside\_ip) | AWS inside IP for tunnel 1 (e.g., 169.254.10.1) | `string` | `"169.254.10.1"` | no |
| <a name="input_tunnel1_cgw_inside_ip"></a> [tunnel1\_cgw\_inside\_ip](#input\_tunnel1\_cgw\_inside\_ip) | Customer gateway inside IP for tunnel 1 (e.g., 169.254.10.2) | `string` | `"169.254.10.2"` | no |
| <a name="input_tunnel1_psk"></a> [tunnel1\_psk](#input\_tunnel1\_psk) | Pre-shared key for tunnel 1 | `string` | `""` | no |
| <a name="input_tunnel2_aws_endpoint"></a> [tunnel2\_aws\_endpoint](#input\_tunnel2\_aws\_endpoint) | AWS VPN endpoint IP for tunnel 2 | `string` | `""` | no |
| <a name="input_tunnel2_aws_inside_ip"></a> [tunnel2\_aws\_inside\_ip](#input\_tunnel2\_aws\_inside\_ip) | AWS inside IP for tunnel 2 (e.g., 169.254.11.1) | `string` | `"169.254.11.1"` | no |
| <a name="input_tunnel2_cgw_inside_ip"></a> [tunnel2\_cgw\_inside\_ip](#input\_tunnel2\_cgw\_inside\_ip) | Customer gateway inside IP for tunnel 2 (e.g., 169.254.11.2) | `string` | `"169.254.11.2"` | no |
| <a name="input_tunnel2_psk"></a> [tunnel2\_psk](#input\_tunnel2\_psk) | Pre-shared key for tunnel 2 | `string` | `""` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the simulated on-premises VPC | `string` | `"192.168.0.0/24"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_advertised_cidr"></a> [advertised\_cidr](#output\_advertised\_cidr) | CIDR being advertised via BGP |
| <a name="output_private_subnet_id"></a> [private\_subnet\_id](#output\_private\_subnet\_id) | ID of the private subnet |
| <a name="output_public_subnet_id"></a> [public\_subnet\_id](#output\_public\_subnet\_id) | ID of the public subnet |
| <a name="output_router_instance_id"></a> [router\_instance\_id](#output\_router\_instance\_id) | Instance ID of the router |
| <a name="output_router_private_ip"></a> [router\_private\_ip](#output\_router\_private\_ip) | Private IP of the VPN router |
| <a name="output_router_public_ip"></a> [router\_public\_ip](#output\_router\_public\_ip) | Public IP of the VPN router (for customer gateway) |
| <a name="output_test_instance_id"></a> [test\_instance\_id](#output\_test\_instance\_id) | Instance ID of the test instance |
| <a name="output_test_instance_private_ip"></a> [test\_instance\_private\_ip](#output\_test\_instance\_private\_ip) | Private IP of the test instance |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR block of the VPC |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the simulated on-premises VPC |
