resource "aws_instance" "main" {
  ami           = local.ami_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.sg_id]
  subnet_id  = local.private_subnet_id
  
  tags = merge(local.common_tags ,
  {
    Name = "${var.project}-${var.environment}-${var.component}"
  }
  
  )
}

resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id
  ]

  
    connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     =  aws_instance.main.private_ip
  }

  provisioner "file" {
  source = "bootstrap.sh"
  destination = "/tmp/bootstrap.sh"
}


  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/bootstrap.sh",
      "sudo sh /tmp/bootstrap.sh ${var.component} ${var.environment} ${var.app_version} "
    ]
  }
}

resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on = [terraform_data.main]
}

resource "aws_ami_from_instance" "main" {
  name               = "${var.project}-${var.environment}-${var.component}-ami"
  source_instance_id = aws_instance.main.id
  depends_on = [aws_ec2_instance_state.main]
  tags = merge(
  {
    Name = "${var.project}-${var.environment}-${var.component}-ami"
  },
  local.common_tags
  )
}

resource "aws_lb_target_group" "main" {
  name        = "${var.project}-${var.environment}-${var.component}"
  port        = local.port_number
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  deregistration_delay = 60

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval  = 10
    matcher = "200-299"
    path  = local.health_check_path
    timeout  = 2
    port        = local.port_number
    protocol    = "HTTP"
  }
}

resource "aws_launch_template" "main" {
  name = "${var.project}-${var.environment}-${var.component}"
  image_id = aws_ami_from_instance.main.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  update_default_version = true
  vpc_security_group_ids = [local.sg_id]
   # tags for instances created by launch template through
  tag_specifications {
    resource_type = "instance"
    tags = merge(
        {
      Name = "${var.project}-${var.environment}-${var.component}"
    },
    local.common_tags
    )
  }
     # tags for volumes created by launch template through
     tag_specifications {
    resource_type = "volume"
    tags = merge(
        {
      Name = "${var.project}-${var.environment}-${var.component}"
    },
   local.common_tags
    )
  }
  
   # tags for  launch template 
  tags = merge(
  {
    Name = "${var.project}-${var.environment}-${var.component}"
  },
  local.common_tags
  )

}


resource "aws_autoscaling_group" "main" {
  name                      = "${var.project}-${var.environment}-${var.component}"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 120
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  vpc_zone_identifier       = [local.private_subnet_id]

  target_group_arns = [aws_lb_target_group.main.arn]
  timeouts {
    delete = "15m"
  }

  dynamic "tag" {
    for_each = merge(
        {
            Name = "${var.project}-${var.environment}-${var.component}"
        },
        local.common_tags
    )

    content {
      key                 = tag.key
      propagate_at_launch = true
      value               = tag.value
    }
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }
}

resource "aws_autoscaling_policy" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  name                   = "${var.project}-${var.environment}-${var.component}"
  policy_type            = "TargetTrackingScaling"
    estimated_instance_warmup = 120
  target_tracking_configuration {
     predefined_metric_specification {
        predefined_metric_type = "ASGAverageCPUUtilization"
      }
        target_value = 70.0
    }
  }

resource "aws_lb_listener_rule" "main" {
  listener_arn =  local.alb_listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
  condition {
    host_header {
      values = [local.host_header]
    }
  }
}

resource "terraform_data" "main_delete" {
  triggers_replace = [
    aws_instance.main.id
  ]
  depends_on = [aws_autoscaling_policy.main]
  
 provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }
}
