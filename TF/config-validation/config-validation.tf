variable "NETWORK" {}
variable "INTERFACES" {}



locals {
  SUBNET_LIST        = var.NETWORK.SUBNETS_IDS[*].ID
  SUBNET_NAMES       = var.NETWORK.SUBNETS_IDS[*].Name
  INTERFACES_SUBNETS = var.INTERFACES[*].MapToSubnet
}



data "aws_vpcs" "find_my_vpc" {
  filter {
    name   = "vpc-id"
    values = [var.NETWORK.VPCID]
  }
}


data "aws_subnets" "find_my_subnets" {
  filter {
    name   = "vpc-id"
    values = [var.NETWORK.VPCID]
  }
}



resource "null_resource" "verify_if_vpc_exists" {
  # check if VPC exists
  triggers = {
    VPCID = var.NETWORK.VPCID
  }
  lifecycle {
    postcondition {
      condition     = (length(data.aws_vpcs.find_my_vpc.ids) != 0)
      error_message = "VPC doesn't exist"
    }
  }
}


resource "null_resource" "verify_if_subnets_belong_to_vpc" {
  # check if subnets belong to the VPC
  count = length(local.SUBNET_LIST)
  triggers = {
    VPCID = local.SUBNET_LIST[count.index]
  }
  lifecycle {
    postcondition {
      condition     = contains(data.aws_subnets.find_my_subnets.ids, local.SUBNET_LIST[count.index])
      error_message = join("", ["Subnet ", local.SUBNET_LIST[count.index], " does not belong to ", var.NETWORK.VPCID, " VPC"])
    }
  }
}


resource "null_resource" "check_subnets_unique_names" {
  # check if subnets names are unique
  triggers = {
    SUBNET_NAMES = md5(join("", local.SUBNET_NAMES))
  }
  lifecycle {
    postcondition {
      condition     = (length(distinct(local.SUBNET_NAMES)) == length(local.SUBNET_NAMES))
      error_message = "Subnet names are not unique"
    }
  }
}


resource "null_resource" "check_subnets_unique_IDs" {
  # check if subnets IDs are unique
  triggers = {
    SUBNET_LIST = md5(join("", local.SUBNET_LIST))
  }
  lifecycle {
    postcondition {
      condition     = (length(distinct(local.SUBNET_LIST)) == length(local.SUBNET_LIST))
      error_message = "Subnet IDs are not unique"
    }
  }
}


resource "null_resource" "check_subnets_to_eni_mappings" {
  # check if interface-to-subnet mapping is correct
  count = length(local.INTERFACES_SUBNETS)
  triggers = {
    SUBNET_LIST = local.INTERFACES_SUBNETS[count.index]
  }
  lifecycle {
    postcondition {
      condition     = contains(local.SUBNET_NAMES, local.INTERFACES_SUBNETS[count.index])
      error_message = join("", ["One of the interface is mapped to nondefined subnet: ", local.INTERFACES_SUBNETS[count.index]])
    }
  }
}
