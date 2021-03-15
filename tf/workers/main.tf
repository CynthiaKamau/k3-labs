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
    comments  = "workers"
  }
}

resource "aws_subnet" "workers" {
  vpc_id                  = var.vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.az[0]
  tags                    = module.tags.tags
}

resource "aws_security_group" "workers" {
  vpc_id = var.vpc.id
  tags   = module.tags.tags

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "TCP"
    security_groups = [var.bastion_sg_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "workers" {
  key_name   = format("%s%s", var.name, "_keypair_workers")
  public_key = file(var.public_key_path)
}

data "aws_ami" "latest_workers" {
  most_recent = true
  owners      = ["self"]
  name_regex  = "^${var.name}-k3s-agent-\\d*$"

  filter {
    name   = "name"
    values = ["${var.name}-k3s-agent-*"]
  }
}

resource "aws_launch_configuration" "workers" {
  name            = "workers"
  image_id        = data.aws_ami.latest_workers.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.workers.id]
}

resource "aws_autoscaling_group" "workers" {
  name                      = "workers"
  max_size                  = 5
  min_size                  = 3
  desired_capacity          = 3
  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.workers.id]
  launch_configuration      = aws_launch_configuration.workers.name

  tag {
    key                 = "owner"
    value               = var.owner
    propagate_at_launch = true
  }

  tag {
    key                 = "name"
    value               = var.name
    propagate_at_launch = true
  }

  tag {
    key                 = "project"
    value               = var.project
    propagate_at_launch = true
  }

  tag {
    key                 = "env"
    value               = var.env
    propagate_at_launch = true
  }

  tag {
    key                 = "workspace"
    value               = var.workspace
    propagate_at_launch = true
  }

  tag {
    key                 = "comments"
    value               = "worker"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
