variable "DEPLOYMENTPREFIX" {}
variable ASG-INFO {}



resource "random_string" "random" {
  length           = 12
  special          = false
  min_lower=6
  min_numeric = 6
}



locals {
  bucket_types = ["Source","Artifacts"]
  bucket_names = {for k in local.bucket_types: k => { "name": lower(join("", [var.DEPLOYMENTPREFIX,"-",k,"-",random_string.random.result ]))}}
  bucket_pipeline_keys = {for k,v in var.ASG-INFO: k=> {"bucket_key_name": lower(v["asg_id"])} }
  DATA_TO_BE_MERGED = {for k,v in aws_codedeploy_deployment_group.deploy-group: k => {
                                                                    "app_name" = v["app_name"], 
                                                                    "deployment_group_arn" = v["arn"],
                                                                    "deployment_group_name" =v["deployment_group_name"],
                                                                    "deployment_group_id" =v["deployment_group_id"],
                                                                    "bucket_pipeline_keys " = join("", [local.bucket_pipeline_keys[k].bucket_key_name,"/"])
                                                                    }}
}



resource "aws_s3_bucket" "s3-buckets" {
  #checkov:skip=CKV_AWS_18:No access logging needed
  #checkov:skip=CKV2_AWS_61:No lifecycle configuration needed
  #checkov:skip=CKV2_AWS_62:No event notification needed
  #checkov:skip=CKV_AWS_144:No cross-region replication needed
  #checkov:skip=CKV_AWS_145:No KMS encryption needed
  for_each = local.bucket_names
  bucket = local.bucket_names[each.key].name
  force_destroy = true
}


resource "aws_s3_bucket_versioning" "s3_versioning" {
  for_each = aws_s3_bucket.s3-buckets
  bucket                  = aws_s3_bucket.s3-buckets[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_public_access_block" "block_public_access" {
  for_each = aws_s3_bucket.s3-buckets
  bucket                  = aws_s3_bucket.s3-buckets[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_iam_role" "eventbridge-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-eventbridge-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DEPLOYMENTPREFIX, "-eventbridge-policy"])
    policy = jsonencode({
      "Version" : "2012-10-17"
      "Statement" : [
        {
          "Action" : "codepipeline:StartPipelineExecution",
          "Resource" : "*",
          "Effect" : "Allow"
        }
      ]
    })
  }
}


resource "aws_iam_role" "codedeploy-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-codedeploy-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"]
  inline_policy {
    name = join("", [var.DEPLOYMENTPREFIX, "-pipeline-policy"])
    policy = jsonencode({
      "Version" : "2012-10-17"
      "Statement" : [
        {
          "Action" : [
            "iam:PassRole",
            "ec2:CreateTags",
            "ec2:RunInstances"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },

      ]
    })
  }
}


resource "aws_iam_role" "codepipeline-role" {
  name = join("", [var.DEPLOYMENTPREFIX, "-pipeline-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DEPLOYMENTPREFIX, "-pipeline-policy"])
    policy = jsonencode({
      "Version" : "2012-10-17"
      "Statement" : [
        {
          "Action" : [
            "iam:PassRole"
          ],
          "Resource" : "*",
          "Effect" : "Allow",
          "Condition" : {
            "StringEqualsIfExists" : {
              "iam:PassedToService" : [
                "cloudformation.amazonaws.com",
                "elasticbeanstalk.amazonaws.com",
                "ec2.amazonaws.com",
                "ecs-tasks.amazonaws.com"
              ]
            }
          }
        },
        {
          "Action" : [
            "codecommit:CancelUploadArchive",
            "codecommit:GetBranch",
            "codecommit:GetCommit",
            "codecommit:GetRepository",
            "codecommit:GetUploadArchiveStatus",
            "codecommit:UploadArchive"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "codedeploy:CreateDeployment",
            "codedeploy:GetApplication",
            "codedeploy:GetApplicationRevision",
            "codedeploy:GetDeployment",
            "codedeploy:GetDeploymentConfig",
            "codedeploy:RegisterApplicationRevision"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "codestar-connections:UseConnection"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "elasticbeanstalk:*",
            "ec2:*",
            "elasticloadbalancing:*",
            "autoscaling:*",
            "cloudwatch:*",
            "s3:*",
            "sns:*",
            "cloudformation:*",
            "rds:*",
            "sqs:*",
            "ecs:*"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "lambda:InvokeFunction",
            "lambda:ListFunctions"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "opsworks:CreateDeployment",
            "opsworks:DescribeApps",
            "opsworks:DescribeCommands",
            "opsworks:DescribeDeployments",
            "opsworks:DescribeInstances",
            "opsworks:DescribeStacks",
            "opsworks:UpdateApp",
            "opsworks:UpdateStack"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "cloudformation:CreateStack",
            "cloudformation:DeleteStack",
            "cloudformation:DescribeStacks",
            "cloudformation:UpdateStack",
            "cloudformation:CreateChangeSet",
            "cloudformation:DeleteChangeSet",
            "cloudformation:DescribeChangeSet",
            "cloudformation:ExecuteChangeSet",
            "cloudformation:SetStackPolicy",
            "cloudformation:ValidateTemplate"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Action" : [
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild",
            "codebuild:BatchGetBuildBatches",
            "codebuild:StartBuildBatch"
          ],
          "Resource" : "*",
          "Effect" : "Allow"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "devicefarm:ListProjects",
            "devicefarm:ListDevicePools",
            "devicefarm:GetRun",
            "devicefarm:GetUpload",
            "devicefarm:CreateUpload",
            "devicefarm:ScheduleRun"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "servicecatalog:ListProvisioningArtifacts",
            "servicecatalog:CreateProvisioningArtifact",
            "servicecatalog:DescribeProvisioningArtifact",
            "servicecatalog:DeleteProvisioningArtifact",
            "servicecatalog:UpdateProduct"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "cloudformation:ValidateTemplate"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ecr:DescribeImages"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "states:DescribeExecution",
            "states:DescribeStateMachine",
            "states:StartExecution"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "appconfig:StartDeployment",
            "appconfig:StopDeployment",
            "appconfig:GetDeployment"
          ],
          "Resource" : "*"
        }
      ]
    })
  }
}


resource "aws_s3_object" "object" {
  depends_on = [ aws_s3_bucket.s3-buckets ]
  for_each = local.bucket_pipeline_keys
  bucket = local.bucket_names.Source.name
  key    = lower(join("", [each.value.bucket_key_name, "/"]))
}


resource "aws_codedeploy_app" "deploy-app" {
  for_each = var.ASG-INFO
  compute_platform = "Server"
  name             = join("", [each.value["asg_id"], "-deploy-app"])

}


resource "aws_codedeploy_deployment_group" "deploy-group" {
 for_each = aws_codedeploy_app.deploy-app
  app_name               = each.value["name"]
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  deployment_group_name  = join("", [var.ASG-INFO[each.key].asg_id,"-deploy-group"])
  service_role_arn       = aws_iam_role.codedeploy-role.arn
  autoscaling_groups     = [var.ASG-INFO[each.key].asg_id]
}


resource "aws_codepipeline" "codepipeline" {
  #checkov:skip=CKV_AWS_219:No need for KMS encryption for Artifact Store
  for_each = local.bucket_pipeline_keys
  name = each.value.bucket_key_name
  pipeline_type = "V2"
  role_arn = aws_iam_role.codepipeline-role.arn
  artifact_store {
    location = local.bucket_names.Artifacts.name
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
          S3Bucket = local.bucket_names.Source.name
          S3ObjectKey = join("", [each.value.bucket_key_name,"/config.zip"])
          PollForSourceChanges =  false
      }
    }
  }
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["SourceArtifact"]
      version         = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.deploy-app[each.key].name
        DeploymentGroupName = aws_codedeploy_deployment_group.deploy-group[each.key].deployment_group_name

      }
    }
  }
}


resource "aws_cloudwatch_event_rule" "pipeline-rule" {
  for_each = local.bucket_pipeline_keys
  name        = join("-", [var.DEPLOYMENTPREFIX,each.key, "pipeline-rule"])
  description = "Rule to capture S3 uploads to start CodePipelines"
 event_pattern = jsonencode({
    detail-type = [
      "AWS API Call via CloudTrail"
    ],
    source = ["aws.s3"],
    detail = {
        "eventSource" = ["s3.amazonaws.com"],
        "eventName" = ["PutObject", "CopyObject", "CompleteMultipartUpload"],
        "requestParameters" = {
          "bucketName" = ["${local.bucket_names.Source.name}"],
          "key" = ["${join("/", [each.value.bucket_key_name,"config.zip"])}"]
        }

    }
  })
}


resource "aws_cloudwatch_event_target" "codepipeline-as-target" {
  for_each = local.bucket_pipeline_keys
  rule      = aws_cloudwatch_event_rule.pipeline-rule[each.key].name
  target_id = "StartPipeLine"
  arn       = aws_codepipeline.codepipeline[each.key].arn
  role_arn = aws_iam_role.eventbridge-role.arn
 }



output "CICD-INFO" {
  value = {  for k,v in local.DATA_TO_BE_MERGED: k=> merge (local.DATA_TO_BE_MERGED[k],var.ASG-INFO[k])}
}