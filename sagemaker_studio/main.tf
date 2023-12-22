resource "random_pet" "name" {
  length = 2
}

resource "aws_sagemaker_domain" "this" {
  domain_name = var.domain_name
  auth_mode   = "IAM"
  vpc_id      = var.vpc
  subnet_ids  = var.subnets

  domain_settings {
    execution_role_identity_config = "USER_PROFILE_NAME"
  }

  default_user_settings {
    execution_role = aws_iam_role.sagemaker_default_execution_role.arn
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type        = "ml.t3.medium"
        lifecycle_config_arn = aws_sagemaker_studio_lifecycle_config.kernel["pipenv"].arn
      }
      lifecycle_config_arns = [for lifecycle_config in aws_sagemaker_studio_lifecycle_config.kernel : lifecycle_config.arn]
    }
    sharing_settings {
      notebook_output_option = "Allowed"
      s3_output_path         = "s3://sagemaker-studio-${lower(var.domain_name)}-${random_pet.name.id}"
    }
    canvas_app_settings {
      model_register_settings {
        cross_account_model_register_role_arn = ""
        status                                = "DISABLED"
      }
    }
    jupyter_server_app_settings {
      default_resource_spec {
        instance_type               = "system"
        lifecycle_config_arn        = ""
        sagemaker_image_arn         = "arn:aws:sagemaker:eu-central-1:936697816551:image/jupyter-server-3"
        sagemaker_image_version_arn = ""
      }
    }
    studio_web_portal = "ENABLED"
    default_landing_uri = "app:JupyterServer:"
  }

  default_space_settings {
    execution_role = aws_iam_role.sagemaker_default_execution_role.arn
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type        = "ml.t3.medium"
        lifecycle_config_arn = aws_sagemaker_studio_lifecycle_config.kernel["pipenv"].arn
      }
      lifecycle_config_arns = [for lifecycle_config in aws_sagemaker_studio_lifecycle_config.kernel : lifecycle_config.arn]
    }    
  }

  retention_policy {
    home_efs_file_system = "Delete"
  }
}

resource "aws_iam_role" "sagemaker_default_execution_role" {
  name               = "${lower(var.domain_name)}-default"
  path               = "/sagemaker/"
  assume_role_policy = data.aws_iam_policy_document.role_trust_policies.json
}

resource "aws_secretsmanager_secret" "connection" {
  name                    = "sagemaker-bastion-connection"
  recovery_window_in_days = 0
}

resource "aws_iam_role_policy_attachment" "sagemaker_default_execution_role" {
  role       = aws_iam_role.sagemaker_default_execution_role.id
  policy_arn = each.value

  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])
}

resource "aws_iam_role_policy_attachment" "sagemaker_default_execution_role_ssm_policy" {
  role       = aws_iam_role.sagemaker_default_execution_role.id
  policy_arn = aws_iam_policy.sagemaker_default.arn
}

resource "aws_sagemaker_studio_lifecycle_config" "kernel" {
  for_each                         = fileset("kernel_lifecycle_configs", "*")
  studio_lifecycle_config_name     = "${lower(var.domain_name)}-${each.key}"
  studio_lifecycle_config_app_type = "KernelGateway"
  studio_lifecycle_config_content  = base64encode(file("kernel_lifecycle_configs/${each.key}"))
}

resource "aws_s3_bucket" "this" {
  bucket        = "sagemaker-studio-${lower(var.domain_name)}-${random_pet.name.id}"
  force_destroy = true
}

resource "aws_security_group" "efs" {
  name   = "sagemaker-efs"
  vpc_id = var.vpc
}

resource "aws_security_group" "bastion" {
  name   = "sagemaker-bastion"
  vpc_id = var.vpc

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "efs-bastion" {
  type                     = "ingress"
  description              = "NFS"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.efs.id
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion-efs" {
  type                     = "ingress"
  description              = "NFS"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.efs.id
}

resource "null_resource" "add_efs_security_group" {
  provisioner "local-exec" {
    command = "python add_efs_security_group.py ${var.profile} ${var.region} ${aws_sagemaker_domain.this.home_efs_file_system_id} ${aws_security_group.efs.id}"
  }

  depends_on = [
    aws_sagemaker_domain.this,
    aws_security_group.efs
  ]
}
