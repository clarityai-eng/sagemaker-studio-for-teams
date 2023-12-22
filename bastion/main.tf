resource "tls_private_key" "this" {
  algorithm = "RSA"
}

resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.this.private_key_pem
  filename        = var.key_filename
  file_permission = "0600"
}

module "key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  key_name   = var.key_name
  public_key = tls_private_key.this.public_key_openssh
}

resource "null_resource" "bootstrap" {
  triggers = {
    sha1 = filesha1("${path.module}/bootstrap.tftpl")
  }
}

data "aws_subnet" "this" {
  id = var.subnet
}

data "external" "efs" {
  program = [
    "python",
    "${path.module}/get_efs_ip.py",
    var.profile,
    var.region,
    var.sagemaker_domain_name,
    data.aws_subnet.this.availability_zone
  ]
}

resource "aws_instance" "ec2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.security_group]
  subnet_id              = var.subnet
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_type = "gp2"
    volume_size = var.volume_size
  }

  user_data = templatefile("${path.module}/bootstrap.tftpl", {
    efs_ip = data.external.efs.result.ip
  })

  lifecycle {
    replace_triggered_by = [
      null_resource.bootstrap
    ]
  }

  depends_on = [
    local_sensitive_file.private_key
  ]
}

resource "aws_secretsmanager_secret_version" "connection" {
  secret_id     = var.connection_secret
  secret_string = <<EOF
    {
      "instance_id": "${aws_instance.ec2.id}",
      "private_key": "${base64encode(tls_private_key.this.private_key_pem)})"
    }
  EOF
}

resource "aws_iam_instance_profile" "ec2" {
  name = "ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_iam_role" "ec2" {
  name        = "ec2-ssm"
  description = "Access EC2 with SSM"

  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = {
      "Effect" = "Allow",
      "Principal" = {
        "Service" = "ec2.amazonaws.com"
      },
      "Action" = "sts:AssumeRole"
    }
  })
}

resource "aws_iam_role_policy_attachment" "ec2" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
