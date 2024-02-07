variable "DEPLOYMENTPREFIX" {}
variable "TEMPLATE-INFO" {}
variable WEBHOOK-INFO {}



data "template_file" "event_pattern" {
  template = "${file("${path.module}/event_pattern.tpl")}"
  vars = {
    asgs = "[ ${join(",", [for k,v in aws_autoscaling_group.asg : format("%q", v["name"]) ])} ]"
  }
}


resource "aws_autoscaling_group" "asg" {
  for_each = var.TEMPLATE-INFO
  name = join("", [var.DEPLOYMENTPREFIX,"-",each.key,"-",replace(var.TEMPLATE-INFO[each.key].interface_mac,":","-")])
  vpc_zone_identifier = [var.TEMPLATE-INFO[each.key].subnet_id]
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  health_check_grace_period = 60
  launch_template {
    name    = var.TEMPLATE-INFO[each.key].template_name
    version = "$Latest"
  }
  tag {
    key                 = "subnet_id"
    value               = var.TEMPLATE-INFO[each.key].subnet_id
    propagate_at_launch = true
  }
  tag {
    key                 = "interface_mac"
    value               = var.TEMPLATE-INFO[each.key].interface_mac
    propagate_at_launch = true
  }
  tag {
    key                 = "interface_id"
    value               = var.TEMPLATE-INFO[each.key].interface_id
    propagate_at_launch = true
  }
}


resource "aws_cloudwatch_event_rule" "webhook-rule" {
  name        = join("", [var.DEPLOYMENTPREFIX, "-webhook-rule"])
  description = "Rule to capture ASG changes defined in ASG Lifecycle hooks"
  event_pattern = data.template_file.event_pattern.rendered
}


resource "aws_cloudwatch_event_target" "cloudwatch-as-target" {
  rule      = aws_cloudwatch_event_rule.webhook-rule.name
  target_id = "SendToCloudWatch"
  arn       = aws_cloudwatch_log_group.asg-logs.arn
}


resource "aws_cloudwatch_event_target" "lambda-as-target" {
  rule      = aws_cloudwatch_event_rule.webhook-rule.name
  target_id = "SendToLambda"
  arn       = var.WEBHOOK-INFO.arn
}


resource "aws_cloudwatch_log_group" "asg-logs" {
  #checkov:skip=CKV_AWS_158:The log group is intentionaly not encrypted using KMS
  name = join("", ["/aws/events/",var.DEPLOYMENTPREFIX, "-ASG-lifecycle-hooks"])
  retention_in_days = 365
}


resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = var.WEBHOOK-INFO.arn
  principal     = "events.amazonaws.com"
  source_arn    =  aws_cloudwatch_event_rule.webhook-rule.arn
}


resource "aws_autoscaling_lifecycle_hook" "asg-hook" {
  for_each = var.TEMPLATE-INFO
  name                   = "asg-hook"
  autoscaling_group_name = aws_autoscaling_group.asg[each.key].name
  default_result         = "ABANDON"
  heartbeat_timeout      = 60
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_LAUNCHING"
notification_metadata = jsonencode({
    subnet_id = "${var.TEMPLATE-INFO[each.key].subnet_id}",
    mac_id = "${var.TEMPLATE-INFO[each.key].interface_mac}",
    interface_id = "${var.TEMPLATE-INFO[each.key].interface_id}"
  })
}



locals {
  DATA_TO_BE_MERGED = {for k,v in aws_autoscaling_group.asg: k => {"asg_arn" = v["arn"],"asg_id" = v["id"], "asg_tags" =v["tag"]}}
}



output "ASG-INFO" {
  value = {  for k,v in local.DATA_TO_BE_MERGED: k=> merge (local.DATA_TO_BE_MERGED[k],var.TEMPLATE-INFO[k])}
}
