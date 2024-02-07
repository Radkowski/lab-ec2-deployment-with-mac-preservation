module "CONFIG-VALIDATION" {
  source     = "./config-validation"
  NETWORK    = local.NETWORK
  INTERFACES = local.INTERFACES

}
module "SECURITY-GROUPS" {
  depends_on       = [module.CONFIG-VALIDATION]
  source           = "./security-groups"
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
  TEMPLATE         = local.TEMPLATE
  NETWORK          = local.NETWORK
}

module "NETWORK-INTERFACE" {
  depends_on       = [module.SECURITY-GROUPS]
  source           = "./network-interface"
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
  NETWORK          = local.NETWORK
  INTERFACES       = local.INTERFACES
  SG-INFO          = module.SECURITY-GROUPS.SG-INFO
}

module "LAUNCH-TEMPLATE" {
  depends_on       = [module.NETWORK-INTERFACE]
  source           = "./launch-template"
  REGION           = local.REGION
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
  TEMPLATE         = local.TEMPLATE
  AUTHTAGS         = local.AUTHTAGS
  ENI-INFO         = module.NETWORK-INTERFACE.ENI-INFO
  SG-INFO          = module.SECURITY-GROUPS.SG-INFO
}

module "LAMBDA-WEBHOOK" {
  depends_on       = [module.NETWORK-INTERFACE]
  source           = "./lambda-webhook"
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
  AUTHTAGS         = local.AUTHTAGS
}


module "ASG" {
  source           = "./asg"
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
  TEMPLATE-INFO    = module.LAUNCH-TEMPLATE.TEMPLATE-INFO
  WEBHOOK-INFO     = module.LAMBDA-WEBHOOK.WEBHOOK-INFO
}

module "CICD" {
  depends_on       = [module.ASG]
  source           = "./cicd"
  DEPLOYMENTPREFIX = local.DEPLOYMENTPREFIX
  ASG-INFO         = module.ASG.ASG-INFO
}


output "DEPLOYMENT-INFO" {
  value = module.CICD.CICD-INFO
}


