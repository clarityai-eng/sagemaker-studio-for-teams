include "root" {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  vpc     = dependency.vpc.outputs.vpc
  subnets = dependency.vpc.outputs.public_subnets
}
