variable DEPLOYMENTPREFIX {}
variable AUTHTAGS {}



data "aws_caller_identity" "current" {}
data "aws_region" "current" {}



resource "aws_iam_role" "lambda-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-webhook-lambda-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DEPLOYMENTPREFIX, "-webhook-lambda-policy"])

    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "logs:CreateLogGroup",
          "Resource" : join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":*"])
        },
        {
          "Effect" : "Allow",
          "Action" : [
                "ec2:DescribeInstances",
                "ec2:AssignPrivateIpAddresses",
                "autoscaling:CompleteLifecycleAction",
                "ec2:DescribeNetworkInterfaces",
                "ec2:AttachNetworkInterface"
                ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : [
            join("", ["arn:aws:logs:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":", "log-group:/aws/lambda/", var.DEPLOYMENTPREFIX, "-webhook-lambda:*"])
          ]
        }
      ]
    })
  }
}



data "archive_file" "lambda-code" {
  type        = "zip"
  output_path = "lambda-code.zip"
  source {
    content  = <<EOF
import json
import boto3
import os
import time 
import logging


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def collect_interface_status(interface_id):
    interface_details = {}
    client_ec2 = boto3.client('ec2')
    response = client_ec2.describe_network_interfaces(
        NetworkInterfaceIds=[interface_id]
    )    
    interface_details["MacAddress"]= response["NetworkInterfaces"][0]["MacAddress"]
    interface_details["Status"]= response["NetworkInterfaces"][0]["Status"]
    interface_details["SubnetId"]= response["NetworkInterfaces"][0]["SubnetId"]
    return (interface_details)


def attach_interface(instance_id, interface_id):    
    client_ec2 = boto3.client('ec2')
    response = client_ec2.attach_network_interface (
        DeviceIndex=1,
        InstanceId=instance_id,
        NetworkInterfaceId=interface_id)
    return (response)


def all_in_one(instance_id,interface_id):
    #  check if interface is in available mode. If not, wait 5 sec 5 times
    no_of_waits = 5
    counter_of_waits = 0
    while collect_interface_status(interface_id)["Status"] != "available":
         print("waiting for interface to be available")
         logger.info ('Interface seems not to be ready to be attached, waiting ... ')
         time.sleep(5)
         counter_of_waits +=1
         logger.info ('Attempt: '+str(counter_of_waits)+'/'+str( no_of_waits))
         if (counter_of_waits > no_of_waits) :
              logger.info ('ACION FAILED !!!')
              return False
    attach_interface(instance_id,interface_id)


def complete_hook(hook_name, asg_name, asg_token):
    client_asg = boto3.client('autoscaling')
    response = client_asg.complete_lifecycle_action(
        LifecycleHookName=hook_name,
        AutoScalingGroupName=asg_name,
        LifecycleActionToken=asg_token,
        LifecycleActionResult='CONTINUE'
    )
    return 0

def lambda_handler(event, context):

    InstanceID = event['detail']['EC2InstanceId']
    NetworkInterfaceID = event['detail']['NotificationMetadata']['interface_id']
    
    logger.info ('Attaching interface: '+str(NetworkInterfaceID)+' to '+str( InstanceID)+' in progress ...')
    
    all_in_one(InstanceID,NetworkInterfaceID)
    logger.info ('Interface successfully attached ')
    
    complete_hook(event['detail']['LifecycleHookName'],event['detail']['AutoScalingGroupName'],event['detail']['LifecycleActionToken'])
    return 0


EOF
    filename = "lambda_function.py"
  }
}

        
resource "aws_lambda_function" "webhook-lambda-exec" {
  #checkov:skip=CKV_AWS_50:No X-Ray tracing needed
  #checkov:skip=CKV_AWS_115:Lambda intentionaly deployed without concurent execution limit
  #checkov:skip=CKV_AWS_116:Lambda intentionaly deployed without concurent execution limit
  #checkov:skip=CKV_AWS_116:Lambda intentionaly deployed without DLQ
  #checkov:skip=CKV_AWS_117:Lambda intentionaly deployed outside solution VPC
  #checkov:skip=CKV_AWS_272:No code-signing required
  description      = "Webhook for licenseservers"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda-code.output_path
  source_code_hash = data.archive_file.lambda-code.output_base64sha256
  role             = aws_iam_role.lambda-role.arn
  function_name    = join("", [var.DEPLOYMENTPREFIX, "-webhook-lambda"])
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  timeout          = 90
  memory_size      = 128
  tags             = var.AUTHTAGS
}

resource "aws_cloudwatch_log_group" "lambda-logs" {
  #checkov:skip=CKV_AWS_158:The log group is intentionaly not encrypted using KMS
  name = join("", ["/aws/lambda/",var.DEPLOYMENTPREFIX, "-webhook-lambda"])
  retention_in_days = 365
}



output "WEBHOOK-INFO" {
  value = {
    "arn" = aws_lambda_function.webhook-lambda-exec.arn
    "name" = aws_lambda_function.webhook-lambda-exec.function_name
    "role" = aws_lambda_function.webhook-lambda-exec.role
    }
}