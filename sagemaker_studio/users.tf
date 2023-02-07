resource "aws_sagemaker_user_profile" "user" {
  count             = length(var.users)
  domain_id         = aws_sagemaker_domain.this.id
  user_profile_name = replace(var.users[count.index].gitlab_name, ".", "-")

  user_settings {
    execution_role = aws_iam_role.sagemaker_user_execution_role[count.index].arn
    jupyter_server_app_settings {
      default_resource_spec {
        sagemaker_image_arn  = "arn:aws:sagemaker:${var.region}:936697816551:image/jupyter-server-3"
        lifecycle_config_arn = aws_sagemaker_studio_lifecycle_config.jupyter[count.index].arn
        instance_type        = "system"
      }
      lifecycle_config_arns = [aws_sagemaker_studio_lifecycle_config.jupyter[count.index].arn]
    }
  }
}

resource "aws_sagemaker_studio_lifecycle_config" "jupyter" {
  count                            = length(var.users)
  studio_lifecycle_config_name     = "${lower(var.domain_name)}-${replace(var.users[count.index].gitlab_name, ".", "-")}"
  studio_lifecycle_config_app_type = "JupyterServer"
  studio_lifecycle_config_content = base64encode(templatefile("jupyter_lifecycle_config.tftpl", {
    user_name    = var.users[count.index].gitlab_name,
    email        = var.users[count.index].gitlab_email,
    secret_name  = aws_secretsmanager_secret.gitlab[count.index].name,
    region       = var.region,
    git_provider = var.git_provider
  }))
}

resource "aws_secretsmanager_secret" "gitlab" {
  count                   = length(var.users)
  name                    = "gitlab-${var.users[count.index].gitlab_name}"
  recovery_window_in_days = 0
}

module "iam_assumable_role" {
  source            = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  count             = length(var.users)
  create_role       = true
  role_name         = var.users[count.index].gitlab_name
  role_requires_mfa = false

  trusted_role_arns = [
    "arn:aws:iam::${var.root_account}:user/${var.users[count.index].gitlab_name}",
  ]

  custom_role_policy_arns = [
    aws_iam_policy.sagemaker_user[count.index].arn
  ]
  number_of_custom_role_policy_arns = 1
}

resource "aws_iam_role" "sagemaker_user_execution_role" {
  count              = length(var.users)
  name               = "${lower(var.domain_name)}-${var.users[count.index].gitlab_name}"
  path               = "/sagemaker/"
  assume_role_policy = data.aws_iam_policy_document.role_trust_policies.json
}

resource "aws_iam_role_policy_attachment" "sagemaker_user_execution_role_sagemaker" {
  count      = length(var.users)
  role       = aws_iam_role.sagemaker_user_execution_role[count.index].id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "sagemaker_user_execution_role_ssm" {
  count      = length(var.users)
  role       = aws_iam_role.sagemaker_user_execution_role[count.index].id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "sagemaker_user_execution_role_user" {
  count      = length(var.users)
  role       = aws_iam_role.sagemaker_user_execution_role[count.index].id
  policy_arn = aws_iam_policy.sagemaker_user[count.index].arn
}
