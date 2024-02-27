# create application load balancer
resource "aws_lb" "application_load_balancer" {
  name                       = "wp-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ALB_SG.id]
  subnets                    = [aws_subnet.public_subnet_AZ1.id, aws_subnet.public_subnet_AZ2.id]
  enable_deletion_protection = false

  tags = {
    Name = "Wp-alb"
  }
}

# create target group
resource "aws_lb_target_group" "target_group" {
  name        = "wp-tg"
  target_type = "instance"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    enabled             = true
    interval            = 300
    path                = "/"
    timeout             = 60
    matcher             = 200
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }

  tags = {
    Name = "Wp-tg"
  }
}

# create a listener rule on port 80 with forward action
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.application_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# Attach webserver ASG to Target group
resource "aws_autoscaling_attachment" "webserver_asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.webserver_ASG.id
  lb_target_group_arn    = aws_lb_target_group.target_group.arn
}

