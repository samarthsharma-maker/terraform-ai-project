# ec2.tf — admin / management host on Ubuntu, accessed via EC2 Instance Connect (browser)

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---- IP range the browser Instance Connect service connects FROM (this region) ----
data "aws_ip_ranges" "ec2_instance_connect" {
  regions  = [local.region]
  services = ["ec2_instance_connect"]
}

# ---- IAM: admin role + instance profile ----
data "aws_iam_policy_document" "admin_ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "admin_ec2" {
  name               = join("-", [local.cluster_name, "admin", "ec2", "role"])
  assume_role_policy = data.aws_iam_policy_document.admin_ec2_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "admin_ec2_admin" {
  role       = aws_iam_role.admin_ec2.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "admin_ec2" {
  name = join("-", [local.cluster_name, "admin", "ec2", "profile"])
  role = aws_iam_role.admin_ec2.name
}

# ---- Security group: SSH only from the Instance Connect service range ----
resource "aws_security_group" "admin_ec2" {
  name        = join("-", [local.cluster_name, "admin", "ec2", "sg"])
  description = "Admin/management EC2 host for ${local.cluster_name}"
  vpc_id      = aws_vpc.retail_store_vpc.id
  tags        = merge(local.common_tags, { Name = join("-", [local.cluster_name, "admin", "ec2", "sg"]) })

  ingress {
    description = "SSH from EC2 Instance Connect service (browser)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = data.aws_ip_ranges.ec2_instance_connect.cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---- The instance ----
resource "aws_instance" "admin" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.public_1.id
  associate_public_ip_address = true # browser Instance Connect hits the public IP
  iam_instance_profile        = aws_iam_instance_profile.admin_ec2.name
  vpc_security_group_ids      = [aws_security_group.admin_ec2.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # enforce IMDSv2 — important with an admin role attached
  }

  # Ubuntu does NOT ship the Instance Connect agent; install it or the browser
  # Connect button fails with "unable to push SSH key".
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y ec2-instance-connect
  EOF

  tags = merge(local.common_tags, { Name = join("-", [local.cluster_name, "admin"]) })
}

# ---- Outputs ----
output "admin_instance_id" {
  value = aws_instance.admin.id
}

output "admin_public_ip" {
  value = aws_instance.admin.public_ip
}