#  Create Launch Template
resource "aws_launch_template" "webserver_template" {
  name_prefix            = "webserver"
  image_id               = "ami-0cf10cdf9fcd62d37"
  instance_type          = "t2.micro"
  key_name               = "server-key"
  vpc_security_group_ids = [aws_security_group.Webserver_SG.id]
  tags = {
    Name = "Webserver-tpl"
  }
  user_data = base64encode(<<-EOF
                              #!/bin/bash
                              yum update -y
                              sudo yum install -y httpd httpd-tools mod_ssl
                              sudo systemctl enable httpd 
                              sudo systemctl start httpd
                              sudo amazon-linux-extras enable php7.4
                              sudo yum clean metadata
                              sudo yum install php php-common php-pear -y
                              sudo yum install php-{cgi,curl,mbstring,gd,mysqlnd,gettext,json,xml,fpm,intl,zip} -y
                              sudo rpm -Uvh https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm
                              sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
                              sudo yum install mysql-community-server -y
                              sudo systemctl enable mysqld
                              sudo systemctl start mysqld
                              echo "${aws_efs_mount_target.efs_mnt_1.ip_address}:/ /var/www/html nfs4" >> /etc/fstab
                              mount -a
                              chown apache:apache -R /var/www/html
                              sudo service httpd restart
                              EOF
  )
}

resource "aws_autoscaling_group" "webserver_ASG" {
  name                      = "Webserver-ASG"
  max_size                  = 4
  min_size                  = 1
  desired_capacity          = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  vpc_zone_identifier       = [aws_subnet.private_app_subnet_AZ1.id, aws_subnet.private_app_subnet_AZ2.id]
  target_group_arns         = [aws_lb_target_group.target_group.arn]

  launch_template {
    id = aws_launch_template.webserver_template.id
  }

}

# Scale out (horizontal)
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "asg-scale-out"
  autoscaling_group_name = aws_autoscaling_group.webserver_ASG.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1" # increase instance by 1
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

# Scale in (horizontal)
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "asg-scale-in"
  autoscaling_group_name = aws_autoscaling_group.webserver_ASG.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1" # decrease instance by 1
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

# Scale out alarm 
# Alarm triggers ASG scaling policy based on metric (CPU-Utilization)
resource "aws_cloudwatch_metric_alarm" "scale_out_alarm" {
  alarm_name          = "webserver-asg-scale-out-alarm"
  alarm_description   = "asg-cpu-scale-out-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30" # New insctance creater if CPU is higher than 30%
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.webserver_ASG.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_out.arn]

}

# Scale in alarm 
resource "aws_cloudwatch_metric_alarm" "scale_in_alarm" {
  alarm_name          = "websever-asg-scale-in-alarm"
  alarm_description   = "asg-cpu-scale-in-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "5" # No instances will scale in when CPU is lower than 5%
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.webserver_ASG.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_in.arn]

}
