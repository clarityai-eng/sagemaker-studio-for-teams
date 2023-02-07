data "aws_availability_zones" "az" {}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  name               = "sagemaker-studio"
  cidr               = "10.0.0.0/16"
  azs                = data.aws_availability_zones.az.names
  private_subnets    = [for index in range(length(module.vpc.azs)) : "10.0.${10 + index}.0/24"]
  public_subnets     = [for index in range(length(module.vpc.azs)) : "10.0.${20 + index}.0/24"]
  enable_nat_gateway = true
}
