# Create a vault server

data "template_file" "vault_setup" {
    template = "${file("${path.module}/scripts/vault_install.sh")}"

    vars = {
        AWS_ACCESS_KEY = var.aws_access_key
        AWS_SECRET_KEY = var.aws_secret_key
        AWS_REGION = var.aws_region
        AMI_ID = data.aws_ami.ubuntu.id
        AWS_KMS_KEY_ID = var.kms_key_id
        VAULT_URL = var.vault_dl_url
        VAULT_LICENSE = var.vault_license
    }
}

resource "aws_instance" "vault-server" {
    ami = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    key_name = var.key_pair
    vpc_security_group_ids = [aws_security_group.vault-snow-sg.id]
    user_data = data.template_file.vault_setup.rendered
    iam_instance_profile = aws_iam_instance_profile.vault-snow.id
    
    tags = {
        Name = "${var.prefix}-vault-unseal-demo"
    }
}

resource "aws_security_group" "vault-snow-sg" {
    name = "${var.prefix}-vault-snow-sg"
    description = "webserver security group"
    vpc_id = "${data.aws_vpc.primary-vpc.id}"

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 8200
        to_port = 8200
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "vault-snow" {
  statement {
    sid       = "VaultKMSUnseal"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
  }
}

resource "aws_iam_role" "vault-snow" {
  name               = "${var.prefix}-vault-demo-snow"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy" "vault-snow" {
  name   = "${var.prefix}-vault-demo-snow"
  role   = aws_iam_role.vault-snow.id
  policy = data.aws_iam_policy_document.vault-snow.json
}

resource "aws_iam_instance_profile" "vault-snow" {
  name = "${var.prefix}-vault-demo-snow"
  role = aws_iam_role.vault-snow.name
}
