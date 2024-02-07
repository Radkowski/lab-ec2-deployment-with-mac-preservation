variable DEPLOYMENTPREFIX {}
variable NETWORK {}
variable INTERFACES {}
variable SG-INFO {}



locals {
  SUBNET-MAP = zipmap(var.NETWORK.SUBNETS_IDS[*].Name,var.NETWORK.SUBNETS_IDS[*].ID)
  NAME_TO_ID = zipmap(var.INTERFACES[*].Name,aws_network_interface.eni[*].id)
  NAME_TO_MAC = zipmap(var.INTERFACES[*].Name,aws_network_interface.eni[*].mac_address)
  NAME_TO_SUBNET = zipmap(var.INTERFACES[*].Name,aws_network_interface.eni[*].subnet_id)
  MAC_TO_NAME = zipmap(aws_network_interface.eni[*].mac_address,var.INTERFACES[*].Name)
  }



resource "aws_network_interface" "eni" {
  count = length(var.INTERFACES)
  subnet_id       = local.SUBNET-MAP[var.INTERFACES[count.index].MapToSubnet]
  security_groups = [var.SG-INFO.id]
  tags = {
  Name = join("", [var.INTERFACES[count.index].Name,"-",var.DEPLOYMENTPREFIX ])
  }
}



output "ENI-INFO" {
  value =   {for k,v in local.NAME_TO_ID: k => {"interface_id" = local.NAME_TO_ID[k], "interface_mac"= local.NAME_TO_MAC[k], "subnet_id"= local.NAME_TO_SUBNET[k]}}
    }

