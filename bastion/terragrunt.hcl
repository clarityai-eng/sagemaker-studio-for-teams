include "root" {
  path = find_in_parent_folders()
}

dependency "sagemaker_studio" {
  config_path = "../sagemaker_studio"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  connection_secret = dependency.sagemaker_studio.outputs.bastion_connection_secret
  security_group    = dependency.sagemaker_studio.outputs.bastion_security_group
  vpc               = dependency.vpc.outputs.vpc
  subnet            = dependency.vpc.outputs.private_subnets[0]
}
