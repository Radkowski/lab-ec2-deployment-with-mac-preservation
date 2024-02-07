data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


locals {
  user_data        = fileexists("./config.yaml") ? yamldecode(file("./config.yaml")) : jsondecode(file("./config.json"))
  REGION           = local.user_data.Parameters.Region
  DEPLOYMENTPREFIX = local.user_data.Parameters.DeploymentPrefix
  AUTHTAGS         = local.user_data.Parameters.AuthTags
  NETWORK          = local.user_data.Parameters.Networking
  TEMPLATE         = local.user_data.Parameters.Template
  INTERFACES       = local.user_data.Parameters.Interfaces
}

