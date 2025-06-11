terraform {

  backend "s3" {
    bucket         = "devops-kobi-tf-state"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_state_locking"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# EC2
resource "aws_instance" "ec2_example" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "Kobi-Key"
  user_data              = <<-EOF
              #!/bin/bash
              cd /home/ubuntu
              echo "Hello World 1" > index.html
              nohup python3 -m http.server 8080 > server.log 2>&1 &
              EOF



  tags = {
    Name = "MyEC2Server"
  }
}

resource "aws_instance" "ec2_instance_2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_security_group.id]
  key_name               = "Kobi-Key"
  user_data              = <<-EOF
              #!/bin/bash
              cd /home/ubuntu
              echo "Hello World 2" > index.html
              nohup python3 -m http.server 8080 > server.log 2>&1 &
              EOF


  tags = {
    Name = "MyEC2Server2"
  }
}

# EC2 - Security Group
resource "aws_security_group" "ec2_security_group" {
  name        = "allow inbound"
  description = "allow inboud traffic to EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP on port 8080"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "EC2AllowInbound"
  }

}

# VPC ID Lookup
data "aws_vpc" "default" {
  default = true
}

# Subnet Default (from vpc)
data "aws_subnet_ids" "default_subnet" {
  vpc_id = data.aws_vpc.default.id
}

# Load Balancer
resource "aws_lb" "load_balancer" {
  name               = "cloud-app-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default_subnet.ids
  security_groups    = [aws_security_group.alb.id]
}

# Load Balancer - listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn

  port = 80

  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# Load Balancer - target group (ec2 instances)
resource "aws_lb_target_group" "instances" {
  name     = "ec2-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = 200
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Load Balancer - attach groups to target group (ec2 instances)
resource "aws_lb_target_group_attachment" "instance_1" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.ec2_example.id
  port             = 8080
}


resource "aws_lb_target_group_attachment" "instance_2" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.ec2_instance_2.id
  port             = 8080
}

# Load Balancer - where to forward traffic (all to target group)
resource "aws_lb_listener_rule" "instances" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }
}

# Load Balancer - security group
resource "aws_security_group" "alb" {
  name = "alb-security-group"
}

# Load Balancer - security group rules
resource "aws_security_group_rule" "allow_alb_http_inbound" {
  type              = "ingress"
  security_group_id = aws_security_group.alb.id

  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

}

resource "aws_security_group_rule" "allow_alb_all_outbound" {
  type              = "egress"
  security_group_id = aws_security_group.alb.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

}

# Route 53 - creates zone for type of traffic
resource "aws_route53_zone" "primary" {
  name = var.domain
}

# Route 53 - routes ipv4 queries to load balancer zone
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain
  type    = "A" # maps dns query of type ipv4 (i.e, 192.168.0.1)

  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}

# RDS - postgres database
resource "aws_db_instance" "db_instance" {
  allocated_storage   = 20
  storage_type        = "standard"
  engine              = "postgres"
  engine_version      = "15.12"
  instance_class      = "db.t3.micro"
  username            = var.db_user
  password            = var.db_pass
  skip_final_snapshot = true
}
