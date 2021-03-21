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
    comments  = "agents"
  }
}

resource "aws_subnet" "agents" {
  vpc_id                  = var.vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.az[0]
  tags                    = module.tags.tags
}

resource "aws_security_group" "agents" {
  vpc_id = var.vpc.id
  tags   = module.tags.tags

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = [var.control_plane_sg_id]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "agents" {
  key_name   = format("%s%s", var.name, "_keypair_agents")
  public_key = file(var.public_key_path)
}

data "aws_ami" "latest_agents" {
  most_recent = true
  owners      = ["self"]
  name_regex  = "^${var.name}-k3s-agent-\\d*$"

  filter {
    name   = "name"
    values = ["${var.name}-k3s-agent-*"]
  }
}

resource "aws_launch_configuration" "agents" {
  name            = "agents"
  image_id        = data.aws_ami.latest_agents.id
  instance_type   = var.instance_type
  security_groups = [aws_security_group.agents.id]
  key_name        = aws_key_pair.agents.id
}

variable "ports" {
  type = map(number)
  default = {
    http  = 80
    https = 443
  }
}

resource "aws_lb" "agents" {
  name               = "basic-load-balancer"
  load_balancer_type = "network"
  subnets            = [aws_subnet.agents.id]
}

resource "aws_lb_listener" "agents_80" {
  load_balancer_arn = aws_lb.agents.arn

  protocol = "TCP"
  port     = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agents_80.arn
  }
}
resource "aws_lb_listener" "agents_443" {
  load_balancer_arn = aws_lb.agents.arn

  protocol = "TCP"
  port     = 443

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.agents_443.arn
  }
}


resource "aws_lb_target_group" "agents_80" {
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc.id

  stickiness {
    type    = "source_ip"
    enabled = false
  }

  health_check {
    path                = "/"
    healthy_threshold   = 10
    unhealthy_threshold = 10
    interval            = 30
  }

  depends_on = [
    aws_lb.agents
  ]

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb_target_group" "agents_443" {
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc.id

  stickiness {
    type    = "source_ip"
    enabled = false
  }

  health_check {
    path                = "/"
    healthy_threshold   = 10
    unhealthy_threshold = 10
    interval            = 30
  }

  depends_on = [
    aws_lb.agents
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_attachment" "agents_80" {
  autoscaling_group_name = aws_autoscaling_group.agents.name
  alb_target_group_arn   = aws_lb_target_group.agents_80.arn
}

resource "aws_autoscaling_attachment" "agents_443" {
  autoscaling_group_name = aws_autoscaling_group.agents.name
  alb_target_group_arn   = aws_lb_target_group.agents_443.arn
}

resource "aws_autoscaling_group" "agents" {
  name                      = "agents"
  max_size                  = 5
  min_size                  = 3
  desired_capacity          = 3
  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  vpc_zone_identifier       = [aws_subnet.agents.id]
  launch_configuration      = aws_launch_configuration.agents.name

  lifecycle {
    ignore_changes        = [load_balancers, target_group_arns]
    create_before_destroy = true
  }

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
    value               = "agent"
    propagate_at_launch = true
  }

}
