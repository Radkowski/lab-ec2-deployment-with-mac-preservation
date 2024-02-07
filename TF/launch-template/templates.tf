variable REGION {}
variable "DEPLOYMENTPREFIX" {}
variable "TEMPLATE" {}
variable "AUTHTAGS" {}
variable ENI-INFO {}
variable SG-INFO {}



data "aws_ssm_parameter" "ami" {
  name = var.TEMPLATE.AmiSSMLocation
}


data "template_file" "host_user_data" {
  template = "${file("${path.module}/host_user_data.tpl")}"
  vars = {
    region = var.REGION
    enable_policy = lower(tostring(var.TEMPLATE.UseCodeDeployVPCEndpoints))
  }
}



resource "aws_iam_role" "instance-profile-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-ec2-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  inline_policy {
    name = "my_inline_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
                      "codedeploy-commands-secure:GetDeploymentSpecification",
                      "codedeploy-commands-secure:PollHostCommand",
                      "codedeploy-commands-secure:PutHostCommandAcknowledgement",
                      "codedeploy-commands-secure:PutHostCommandComplete"
                    ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action   = [
                "s3:Get*",
                "s3:List*",
                "s3:Describe*",
                "s3-object-lambda:Get*",
                "s3-object-lambda:List*"
                    ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
}
}


resource "aws_iam_instance_profile" "instance-profile" {
  name = join("", [var.DEPLOYMENTPREFIX, "-instance-profile"])
  role = aws_iam_role.instance-profile-role.name
}


resource "aws_launch_template" "lic-server-template" {
  for_each = var.ENI-INFO
  name = join("", [var.DEPLOYMENTPREFIX,"-",each.key,"-",replace(var.ENI-INFO[each.key].interface_mac,":","-")])
  image_id                             = data.aws_ssm_parameter.ami.value
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.TEMPLATE.InstanceType
  vpc_security_group_ids               = [var.SG-INFO.id]
  key_name                             = var.TEMPLATE.KeyName
  update_default_version               = true
  user_data                            = base64encode(data.template_file.host_user_data.rendered)
    metadata_options {
    http_tokens = "required"
    http_put_response_hop_limit = 1
    }
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance-profile.arn
    }
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags          = var.AUTHTAGS
  }
}



locals {
  DATA_TO_BE_MERGED = {for k,v in aws_launch_template.lic-server-template: k => {"template_arn" = v["arn"],"template_id" = v["id"], "template_name" =v["name"]}}
}



output "TEMPLATE-INFO" {
  value = {  for k,v in local.DATA_TO_BE_MERGED: k=> merge (local.DATA_TO_BE_MERGED[k],var.ENI-INFO[k])}
  }


