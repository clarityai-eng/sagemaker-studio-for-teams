variable "profile" {
  description = "AWS profile"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc" {
  description = "VPC for SageMaker Studio"
  type        = string
  default     = "vpc-0c6743b4a18cb9230"
}

variable "subnets" {
  description = "Subnets for SageMaker Studio"
  type        = list(string)
}

variable "domain_name" {
  description = "SageMaker Studio domain name"
  type        = string
  default     = "datascience"
}

variable "git_provider" {
  description = "Git provider e.g. gitlab.acme.com"
  type        = string
}

variable "users" {
  description = "List of GitLab user names and emails"
  type        = list(object({ gitlab_name = string, gitlab_email = string, is_admin = bool }))
}

variable "root_account" {
  description = "Root account"
  type        = string
}
