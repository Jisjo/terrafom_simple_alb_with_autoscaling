resource "aws_alb_target_group" "tg_grp" {
  name     = "${var.project}-tg-grp"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc
  load_balancing_algorithm_type = "round_robin"
  stickiness {
    type = "lb_cookie"
  }
  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/index.html"
    port = 80
  }
}




resource "aws_launch_configuration" "lb-lc" {
  name_prefix   = "${var.project}-lc"
  image_id      = "ami-052cef05d01020f1d"
  security_groups = [ var.sg ]
  instance_type = "t2.micro"
  key_name      = "mumbai_webserver"
  user_data     = file("setup.sh")
  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_autoscaling_group" "asg" {
  name                 = "${var.project}-ag"
  launch_configuration = aws_launch_configuration.lb-lc.name
  availability_zones      =  ["ap-south-1a" , "ap-south-1b"]
  min_size             = "2"
  max_size             = "2"
  desired_capacity     = "2"
  

  health_check_type    = "EC2"
  health_check_grace_period = "160"
  target_group_arns     = [ aws_alb_target_group.tg_grp.arn ]
  tag {
    key = "Name"
    propagate_at_launch = true
    value = "myapp"
  }
  lifecycle {
    create_before_destroy = true
  }

  
}


# ALB for the web servers
resource "aws_lb" "alb" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [ var.sg ]
  subnets            = [ "subnet-0ea2e45685a51c7e1", "subnet-000a158f4bd4701af" ]
  enable_http2       = false
  enable_deletion_protection = false
lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${var.project}-alb"
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.tg_grp.arn
  }
}