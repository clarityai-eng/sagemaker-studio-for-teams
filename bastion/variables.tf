variable "profile" {
  description = "AWS profile"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "key_filename" {
  description = "Filname to store private key"
  type        = string
}

variable "key_name" {
  description = "Key pair name"
  type        = string
  default     = "sagemaker-bastion"
}

variable "vpc" {
  description = "VPC for EC2 instance"
  type        = string
}

variable "subnet" {
  description = "Subnet for EC2 instance"
  type        = string
}

variable "ami" {
  description = "Ubuntu AMI"
  type        = string
  default     = "ami-0caef02b518350c8b"
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t2.micro"
}

variable "volume_size" {
  description = "EBS disk size"
  type        = string
  default     = "30"
}

variable "sagemaker_domain_name" {
  description = "SageMaker Studio domain name"
  type        = string
  default     = "datascience"
}

variable "connection_secret" {
  description = "Connection secret"
  type        = string
}

variable "security_group" {
  description = "Security group"
  type        = string
}
