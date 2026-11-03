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
| [aws_customer_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/customer_gateway) | resource |
| [aws_ec2_transit_gateway_route.static](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route) | resource |
| [aws_ec2_transit_gateway_route_table_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_association) | resource |
| [aws_ec2_transit_gateway_route_table_propagation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_transit_gateway_route_table_propagation) | resource |
| [aws_vpn_connection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpn_connection) | resource |
| [aws_ec2_transit_gateway_vpn_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_transit_gateway_vpn_attachment) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_customer_gateway_bgp_asn"></a> [customer\_gateway\_bgp\_asn](#input\_customer\_gateway\_bgp\_asn) | BGP ASN of the customer gateway (on-premises router) | `number` | `65000` | no |
| <a name="input_customer_gateway_device_name"></a> [customer\_gateway\_device\_name](#input\_customer\_gateway\_device\_name) | Descriptive name for the customer gateway device | `string` | `null` | no |
| <a name="input_customer_gateway_ip"></a> [customer\_gateway\_ip](#input\_customer\_gateway\_ip) | Public IP address of the customer gateway device | `string` | n/a | yes |
| <a name="input_enable_acceleration"></a> [enable\_acceleration](#input\_enable\_acceleration) | Enable VPN acceleration (uses AWS Global Accelerator) | `bool` | `false` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for VPN resources | `string` | n/a | yes |
| <a name="input_static_routes_to_onprem"></a> [static\_routes\_to\_onprem](#input\_static\_routes\_to\_onprem) | Map of TGW route table ID to CIDR for static routes to on-prem | `map(string)` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_tgw_propagation_route_table_ids"></a> [tgw\_propagation\_route\_table\_ids](#input\_tgw\_propagation\_route\_table\_ids) | List of TGW route table IDs to propagate VPN routes to | `list(string)` | `[]` | no |
| <a name="input_tgw_route_table_id"></a> [tgw\_route\_table\_id](#input\_tgw\_route\_table\_id) | TGW route table ID to associate the VPN attachment with | `string` | `null` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | Transit Gateway ID for VPN attachment | `string` | n/a | yes |
| <a name="input_tunnel1_inside_cidr"></a> [tunnel1\_inside\_cidr](#input\_tunnel1\_inside\_cidr) | Inside CIDR for tunnel 1 (must be /30 from 169.254.0.0/16) | `string` | `null` | no |
| <a name="input_tunnel1_psk"></a> [tunnel1\_psk](#input\_tunnel1\_psk) | Pre-shared key for tunnel 1 (if null, AWS generates one) | `string` | `null` | no |
| <a name="input_tunnel2_inside_cidr"></a> [tunnel2\_inside\_cidr](#input\_tunnel2\_inside\_cidr) | Inside CIDR for tunnel 2 (must be /30 from 169.254.0.0/16) | `string` | `null` | no |
| <a name="input_tunnel2_psk"></a> [tunnel2\_psk](#input\_tunnel2\_psk) | Pre-shared key for tunnel 2 (if null, AWS generates one) | `string` | `null` | no |
| <a name="input_tunnel_dpd_timeout_action"></a> [tunnel\_dpd\_timeout\_action](#input\_tunnel\_dpd\_timeout\_action) | DPD timeout action: clear, none, or restart | `string` | `"restart"` | no |
| <a name="input_tunnel_ike_versions"></a> [tunnel\_ike\_versions](#input\_tunnel\_ike\_versions) | IKE versions for tunnels | `list(string)` | <pre>[<br>  "ikev2"<br>]</pre> | no |
| <a name="input_tunnel_phase1_dh_groups"></a> [tunnel\_phase1\_dh\_groups](#input\_tunnel\_phase1\_dh\_groups) | Phase 1 DH groups | `list(number)` | <pre>[<br>  20,<br>  21<br>]</pre> | no |
| <a name="input_tunnel_phase1_encryption"></a> [tunnel\_phase1\_encryption](#input\_tunnel\_phase1\_encryption) | Phase 1 encryption algorithms | `list(string)` | <pre>[<br>  "AES256-GCM-16"<br>]</pre> | no |
| <a name="input_tunnel_phase1_integrity"></a> [tunnel\_phase1\_integrity](#input\_tunnel\_phase1\_integrity) | Phase 1 integrity algorithms (ignored for GCM encryption) | `list(string)` | <pre>[<br>  "SHA2-256"<br>]</pre> | no |
| <a name="input_tunnel_phase2_dh_groups"></a> [tunnel\_phase2\_dh\_groups](#input\_tunnel\_phase2\_dh\_groups) | Phase 2 DH groups | `list(number)` | <pre>[<br>  20,<br>  21<br>]</pre> | no |
| <a name="input_tunnel_phase2_encryption"></a> [tunnel\_phase2\_encryption](#input\_tunnel\_phase2\_encryption) | Phase 2 encryption algorithms | `list(string)` | <pre>[<br>  "AES256-GCM-16"<br>]</pre> | no |
| <a name="input_tunnel_phase2_integrity"></a> [tunnel\_phase2\_integrity](#input\_tunnel\_phase2\_integrity) | Phase 2 integrity algorithms (ignored for GCM encryption) | `list(string)` | <pre>[<br>  "SHA2-256"<br>]</pre> | no |
| <a name="input_tunnel_startup_action"></a> [tunnel\_startup\_action](#input\_tunnel\_startup\_action) | Startup action for tunnels: add (on-demand) or start (always up) | `string` | `"add"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_customer_gateway_configuration"></a> [customer\_gateway\_configuration](#output\_customer\_gateway\_configuration) | XML configuration for customer gateway device |
| <a name="output_customer_gateway_id"></a> [customer\_gateway\_id](#output\_customer\_gateway\_id) | ID of the customer gateway |
| <a name="output_tgw_attachment_id"></a> [tgw\_attachment\_id](#output\_tgw\_attachment\_id) | ID of the TGW VPN attachment |
| <a name="output_tunnel1_address"></a> [tunnel1\_address](#output\_tunnel1\_address) | Public IP address of VPN tunnel 1 |
| <a name="output_tunnel1_bgp_asn"></a> [tunnel1\_bgp\_asn](#output\_tunnel1\_bgp\_asn) | BGP ASN on AWS side for tunnel 1 |
| <a name="output_tunnel1_bgp_holdtime"></a> [tunnel1\_bgp\_holdtime](#output\_tunnel1\_bgp\_holdtime) | BGP hold time for tunnel 1 |
| <a name="output_tunnel1_cgw_inside_address"></a> [tunnel1\_cgw\_inside\_address](#output\_tunnel1\_cgw\_inside\_address) | Customer gateway inside address for tunnel 1 |
| <a name="output_tunnel1_preshared_key"></a> [tunnel1\_preshared\_key](#output\_tunnel1\_preshared\_key) | Pre-shared key for tunnel 1 |
| <a name="output_tunnel1_vgw_inside_address"></a> [tunnel1\_vgw\_inside\_address](#output\_tunnel1\_vgw\_inside\_address) | Virtual gateway (AWS) inside address for tunnel 1 |
| <a name="output_tunnel2_address"></a> [tunnel2\_address](#output\_tunnel2\_address) | Public IP address of VPN tunnel 2 |
| <a name="output_tunnel2_bgp_asn"></a> [tunnel2\_bgp\_asn](#output\_tunnel2\_bgp\_asn) | BGP ASN on AWS side for tunnel 2 |
| <a name="output_tunnel2_bgp_holdtime"></a> [tunnel2\_bgp\_holdtime](#output\_tunnel2\_bgp\_holdtime) | BGP hold time for tunnel 2 |
| <a name="output_tunnel2_cgw_inside_address"></a> [tunnel2\_cgw\_inside\_address](#output\_tunnel2\_cgw\_inside\_address) | Customer gateway inside address for tunnel 2 |
| <a name="output_tunnel2_preshared_key"></a> [tunnel2\_preshared\_key](#output\_tunnel2\_preshared\_key) | Pre-shared key for tunnel 2 |
| <a name="output_tunnel2_vgw_inside_address"></a> [tunnel2\_vgw\_inside\_address](#output\_tunnel2\_vgw\_inside\_address) | Virtual gateway (AWS) inside address for tunnel 2 |
| <a name="output_vpn_connection_arn"></a> [vpn\_connection\_arn](#output\_vpn\_connection\_arn) | ARN of the VPN connection |
| <a name="output_vpn_connection_id"></a> [vpn\_connection\_id](#output\_vpn\_connection\_id) | ID of the VPN connection |
