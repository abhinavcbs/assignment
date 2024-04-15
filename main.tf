provider "aws" {
  region     = "us-east-1"
  access_key = "XXXXXXXXXXXXXXXXXXXXX"
  secret_key = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
}

resource "aws_vpc" "prod_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Environment = "production"
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "prod_gw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "production"
  }
}

resource "aws_route_table" "prod_rtb" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_gw.id
  }

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "prod-rtb"
  }
}

resource "aws_main_route_table_association" "vpc_rtb" {
  vpc_id         = aws_vpc.prod_vpc.id
  route_table_id = aws_route_table.prod_rtb.id
}

resource "aws_route_table" "prod_private_rtb" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.prod_nat.id
  }

  tags = {
    Name = "prod-private-rtb"
  }
}

resource "aws_route_table_association" "rtb_association_private" {
  subnet_id      = aws_subnet.prod_subnet_private.id
  route_table_id = aws_route_table.prod_private_rtb.id
}

resource "aws_eip" "nat_eip" {
  domain   = "vpc"
}

resource "aws_subnet" "prod_subnet_public" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = var.public_subnet_cidr
  availability_zone = var.subnet_availability_zone_1
  tags = {
    Name = var.public_subnet_name
  }
}

resource "aws_subnet" "prod_subnet_public2" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = var.public_subnet_cidr2
  availability_zone = var.subnet_availability_zone_2
  tags = {
    Name = var.public_subnet_name2
  }
}

resource "aws_subnet" "prod_subnet_private" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = var.private_subnet_cidr
  availability_zone = var.subnet_availability_zone_1
  tags = {
    Name = var.private_subnet_name
  }
}

locals {
  sg_names = ["external", "internal"]
}

resource "aws_security_group" "production_sg" {
  for_each    = toset(local.sg_names)
  name        = each.value
  description = each.value
  vpc_id = aws_vpc.prod_vpc.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "egress_all" {
  for_each          = aws_security_group.production_sg
  from_port         = 0
  protocol          = "-1"
  security_group_id = each.value.id
  to_port           = 0
  type              = "egress"
  cidr_blocks      = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ssh_internal" {
  for_each          = aws_security_group.production_sg
  from_port         = 22
  protocol          = "-1"
  security_group_id = each.value.id
  to_port           = 22
  type              = "ingress"
  cidr_blocks      = [aws_vpc.prod_vpc.cidr_block]
}

resource "aws_security_group_rule" "ssh_external" {
  security_group_id = aws_security_group.production_sg["external"].id  
  from_port         = 22
  protocol          = "tcp"
  to_port           = 22
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_internet" {
  security_group_id = aws_security_group.production_sg["external"].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_internet" {
  security_group_id = aws_security_group.production_sg["external"].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_internal" {
  security_group_id = aws_security_group.production_sg["internal"].id
  cidr_ipv4         = aws_vpc.prod_vpc.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_internal" {
  security_group_id = aws_security_group.production_sg["internal"].id
  cidr_ipv4         = aws_vpc.prod_vpc.cidr_block
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_acm_certificate" "application_certificate" {
  private_key        = file("key.pem")
  certificate_body   = file("cert.pem")
}

###TARGET GROUP###

resource "aws_lb_target_group" "application_tg" {
  name     = var.tg_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.prod_vpc.id
}

###LOAD BALANCER###

resource "aws_lb" "prod_lb" {
  name               = var.application_lb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.production_sg["external"].id]
  subnets            = [aws_subnet.prod_subnet_public.id,aws_subnet.prod_subnet_public2.id]
  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "application_listener" {
  load_balancer_arn = aws_lb.prod_lb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.application_certificate.arn

  default_action {
    target_group_arn = aws_lb_target_group.application_tg.arn
    type             = "forward"
  }
}

###IAM ROLE###

resource "aws_iam_role" "application" {
  name               = var.lt_iam_profile
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ssm_policy" {
  name        = "ssm-policy"
  description = "Allows full access to SSM"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "ssm:*",
      Resource  = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.application.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_nat_gateway" "prod_nat" {
  connectivity_type = "public"
  subnet_id         = aws_subnet.prod_subnet_public.id
  allocation_id     = aws_eip.nat_eip.id
}

###LAUNCH TEMPLATE###

resource "aws_launch_template" "prod_lt" {
  name = var.lt_name
  network_interfaces {
    subnet_id = aws_subnet.prod_subnet_private.id
    associate_public_ip_address = false
    security_groups = [aws_security_group.production_sg["internal"].id]
  }

  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = var.lt_ebs_root_size
      encrypted = true
    }
  }
  
  block_device_mappings {
    device_name = "/dev/sdg"

    ebs {
      volume_size = var.lt_ebs_secondary_size
      encrypted = true
    }
  }
  
  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }

  cpu_options {
    core_count       = 1
    threads_per_core = 2
  }

  credit_specification {
    cpu_credits = "standard"
  }

  disable_api_stop        = true
  disable_api_termination = true
  ebs_optimized = true

  image_id = var.lt_image

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t3.micro"

  monitoring {
    enabled = true
  }

  placement {
    availability_zone = "us-east-1a"
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "production"
    }
  }

  user_data = filebase64("userdata.sh")
}

###ASG###

resource "aws_autoscaling_group" "prod_asg" {
  name                      = var.asg_name
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 2
  force_delete              = true
  launch_template {
    id      = aws_launch_template.prod_lt.id
    version = "1"
  }
  
  vpc_zone_identifier       = [aws_subnet.prod_subnet_private.id]

  instance_maintenance_policy {
    min_healthy_percentage = 90
    max_healthy_percentage = 120
  }

  tag {
    key             = "Environment"
    value           = "production"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }
}

resource "aws_route53_zone" "private" {
  name = "example.com"
  vpc {
    vpc_id     = aws_vpc.prod_vpc.id
    vpc_region = "us-east-1" 
  }
}

resource "aws_route53_record" "test_example_com" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "test.example.com"
  type    = "A"

  alias {
    name                   = aws_lb.prod_lb.dns_name 
    zone_id                = aws_lb.prod_lb.zone_id   
    evaluate_target_health = true
  }
}

resource "aws_autoscaling_attachment" "prod_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.prod_asg.id
  lb_target_group_arn    = aws_lb_target_group.application_tg.arn
}

resource "aws_autoscaling_policy" "cpu_scaling_policy" {
  name                   = var.autoscaling_policy_name
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.prod_asg.name
  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

resource "aws_cloudwatch_metric_alarm" "target_conn_err_alarm" {
  alarm_name          = var.tg_error_alarm_name
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "TargetConnectionErrorCount"
  namespace           = "AWS/ELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  insufficient_data_actions = []
  treat_missing_data = "notBreaching"


  dimensions = {
    LoadBalancerName = aws_lb.prod_lb.name
    TargetGroup = aws_lb_target_group.application_tg.arn_suffix
  }
  tags = {
    Name = "tg_connection_error"
  }
}


resource "aws_instance" "bastion_host" {
  ami           = var.lt_image
  instance_type = "t3.micro"
  associate_public_ip_address = true
  key_name = var.ssh_key_name
  subnet_id = aws_subnet.prod_subnet_public.id
  security_groups = [aws_security_group.production_sg["external"].id]
  availability_zone = var.subnet_availability_zone_1
  user_data = filebase64("bastion_userdata.sh")
  tags = {
    Name = "bastion"
  }
}
