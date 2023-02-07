variable "profile" {
  description = "AWS profile"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "admin_email" {
  description = "Email of administrator"
  type        = string
}

variable "email_domain" {
  description = "Domain of email addresses (e.g. gmail.com)"
  type        = string
}

variable "users" {
  description = "List of GitLab user names and emails"
  type        = list(object({ gitlab_name = string, gitlab_email = string, is_admin = bool }))
}
