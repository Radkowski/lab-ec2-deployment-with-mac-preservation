variable DEPLOYMENTPREFIX {}
variable TEMPLATE {}
variable NETWORK {}


resource "aws_security_group" "lic-server-sg" {
  #checkov:skip=CKV2_AWS_5:Security Group is attached to the resource located in separate module
  name        = join("", [var.DEPLOYMENTPREFIX, "-template-SG"])
  description = "This setup is dinamicly updated based on config file stored as a part of Terraform IaC"
  vpc_id      = var.NETWORK.VPCID
  dynamic "ingress" {
    for_each = var.TEMPLATE.SecurityGroups
    content {
      description      = ingress.value.Description
      from_port        = ingress.value.Port
      to_port          = ingress.value.Port
      protocol         = ingress.value.Proto
      cidr_blocks      = [ingress.value.From]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  }
  egress = [
    {
      description      = "Default egress rule"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}

output "SG-INFO" {
  value = aws_security_group.lic-server-sg
}