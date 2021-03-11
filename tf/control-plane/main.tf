module "tags" {
  source      = "git::https://github.com/cloudposse/terraform-null-label.git"
  namespace   = var.name
  environment = var.env
  name        = format("%s.%s", var.name, var.env)
  delimiter   = "_"

  tags = {
    owner     = var.owner
    project   = var.project
    env       = var.env
    workspace = var.workspace
    comments  = "control plane"
  }
}

resource "aws_subnet" "control_plane" {
  vpc_id                  = var.vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.az[0]
  tags                    = module.tags.tags
}

resource "aws_security_group" "control_plane" {
  vpc_id = var.vpc.id
  tags   = module.tags.tags

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "TCP"
    security_groups = [var.bastion_sg_id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "TCP"
    security_groups = [var.bastion_sg_id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "TCP"
    security_groups = [var.bastion_sg_id]
  }

  ingress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "TCP"
    security_groups = [var.workers_sg_id]
  }

  ingress {
    from_port       = 8472
    to_port         = 8472
    protocol        = "UDP"
    security_groups = [var.workers_sg_id]
    self            = true
  }

  ingress {
    from_port       = 10250
    to_port         = 10250
    protocol        = "TCP"
    security_groups = [var.workers_sg_id]
    self            = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "control_plane" {
  key_name   = format("%s%s", var.name, "_keypair_control_plane")
  public_key = file(var.public_key_path)
}

data "aws_ami" "latest_control_plane" {
  most_recent = true
  owners      = ["self"]
  name_regex  = "^${var.name}-sandbox-\\d*$"

  filter {
    name   = "name"
    values = ["${var.name}-sandbox-*"]
  }
}

resource "aws_instance" "control_plane" {
  ami                         = data.aws_ami.latest_control_plane.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.control_plane.id
  vpc_security_group_ids      = [aws_security_group.control_plane.id]
  key_name                    = aws_key_pair.control_plane.id
  associate_public_ip_address = false

  root_block_device {
    volume_size = 100
    volume_type = "gp2"
  }

  tags = module.tags.tags
}

resource "aws_route53_record" "control_plane" {
  zone_id = var.zone.zone_id
  name    = format("%s.%s", "cp", var.zone.name)
  type    = "A"
  ttl     = "300"
  records = [aws_instance.control_plane.private_ip]
}
