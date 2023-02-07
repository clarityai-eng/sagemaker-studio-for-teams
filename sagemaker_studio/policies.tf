data "aws_iam_policy_document" "role_trust_policies" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole",
      "sts:SetSourceIdentity"
    ]
  }

  statement {
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "connection_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.connection.arn]
  }
}

data "aws_iam_policy_document" "gitlab_secret" {
  count = length(var.users)

  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue"
    ]
    resources = [aws_secretsmanager_secret.gitlab[count.index].arn]
  }
}

data "aws_iam_policy_document" "default_ssm" {
  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.sagemaker_default_execution_role.arn]
  }

  statement {
    actions   = ["ssm:AddTagsToResource"]
    resources = [aws_iam_role.sagemaker_default_execution_role.arn]
  }

  statement {
    actions = [
      "ssm:CreateActivation",
      "ssm:DescribeInstanceInformation",
      "ssm:SendCommand",
      "ssm:ListCommandInvocations",
      "ssm:StartSession",
      "ssm:TerminateSession"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "user_ssm" {
  count = length(var.users)

  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.sagemaker_user_execution_role[count.index].arn]
  }

  statement {
    actions   = ["ssm:AddTagsToResource"]
    resources = [aws_iam_role.sagemaker_user_execution_role[count.index].arn]
  }

  statement {
    actions = [
      "ssm:CreateActivation",
      "ssm:DescribeInstanceInformation",
      "ssm:SendCommand",
      "ssm:ListCommandInvocations",
      "ssm:StartSession",
      "ssm:TerminateSession"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "default_sagemaker" {
  statement {
    effect = "Deny"
    actions = [
      "sagemaker:CreatePresignedDomainUrl",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "user_sagemaker" {
  count = length(var.users)

  statement {
    actions = [
      "sagemaker:ListDomains",
      "sagemaker:ListApps",
      "sagemaker:ListSpaces",
      "sagemaker:DescribeSpace",
      "sagemaker:ListUserProfiles",
      "sagemaker:DescribeUserProfile",
      "sagemaker:CreateSpace",
      "sagemaker:DeleteSpace"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "sagemaker:CreatePresignedDomainUrl",
    ]
    resources = [var.users[count.index].is_admin ? "*" : aws_sagemaker_user_profile.user[count.index].arn]
  }

  statement {
    effect = "Deny"
    actions = [
      "sagemaker:CreatePresignedDomainUrl",
    ]
    not_resources = [var.users[count.index].is_admin ? "*" : aws_sagemaker_user_profile.user[count.index].arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "sagemaker:DeleteApp"
    ]
    resources = [
      var.users[count.index].is_admin ? "*" :
      "arn:aws:sagemaker:*:*:app/${aws_sagemaker_domain.this.id}/${aws_sagemaker_user_profile.user[count.index].user_profile_name}/*"
    ]
  }

  statement {
    effect = "Deny"
    actions = [
      "sagemaker:DeleteApp"
    ]
    not_resources = [
      var.users[count.index].is_admin ? "*" :
      "arn:aws:sagemaker:*:*:app/${aws_sagemaker_domain.this.id}/${aws_sagemaker_user_profile.user[count.index].user_profile_name}/*"
    ]
  }
}

data "aws_iam_policy_document" "sagemaker_default" {
  source_policy_documents = [
    data.aws_iam_policy_document.connection_secret.json,
    data.aws_iam_policy_document.default_sagemaker.json,
    data.aws_iam_policy_document.default_ssm.json
  ]
}

data "aws_iam_policy_document" "sagemaker_user" {
  count = length(var.users)

  source_policy_documents = [
    data.aws_iam_policy_document.connection_secret.json,
    data.aws_iam_policy_document.gitlab_secret[count.index].json,
    data.aws_iam_policy_document.user_sagemaker[count.index].json,
    data.aws_iam_policy_document.user_ssm[count.index].json
  ]
}

resource "aws_iam_policy" "sagemaker_default" {
  policy = data.aws_iam_policy_document.sagemaker_default.json
}

resource "aws_iam_policy" "sagemaker_user" {
  count  = length(var.users)
  policy = data.aws_iam_policy_document.sagemaker_user[count.index].json
}
