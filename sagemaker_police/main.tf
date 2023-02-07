resource "aws_ses_email_identity" "users" {
  count = length(var.users)
  email = var.users[count.index].gitlab_email
}

module "lambda_function" {
  source             = "terraform-aws-modules/lambda/aws"
  function_name      = "sagemaker-police"
  handler            = "sagemaker_police.lambda_handler"
  runtime            = "python3.8"
  timeout            = 30
  attach_policy_json = true

  environment_variables = {
    ADMIN_EMAIL  = var.admin_email
    EMAIL_DOMAIN = var.email_domain
  }

  source_path = [
    "${path.module}/src/sagemaker_police.py",
    {
      pip_requirements = "${path.module}/src/requirements.txt",
    }
  ]

  policy_json = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [{
      "Effect" = "Allow",
      "Action" = [
        "ses:SendEmail",
        "ses:SendRawEmail",
        "sagemaker:ListUserProfiles",
        "sagemaker:ListApps",
        "sagemaker:ListSpaces"
      ],
      "Resource" = "*"
    }]
  })

  create_current_version_allowed_triggers = false
  allowed_triggers = {
    ScanAmiRule = {
      principal  = "events.amazonaws.com"
      source_arn = module.eventbridge.eventbridge_rule_arns["sagemaker-police"]
    }
  }
}

module "eventbridge" {
  source     = "terraform-aws-modules/eventbridge/aws"
  role_name  = "sagemaker-police-eventbridge"
  create_bus = false

  rules = {
    "sagemaker-police" = {
      description         = "Check for long running SageMaker instances"
      schedule_expression = "rate(1 day)"
    }
  }

  targets = {
    "sagemaker-police" = [
      {
        name = "sagemaker-police"
        arn  = module.lambda_function.lambda_function_arn
      }
    ]
  }
}
