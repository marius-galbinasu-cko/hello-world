resource "aws_s3_bucket" "hello_world" {
  bucket = "${local.full_service_name}-logs"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = data.aws_kms_alias.aws_s3.arn
        sse_algorithm     = "aws:kms"
        // Not available yet: https://github.com/hashicorp/terraform-provider-aws/pull/16581/files
        // bucket_key_enabled
      }
    }
  }

  tags = {
    Name        = "Bucket for logs from application hello-world"
    Environment = local.environment
  }

  lifecycle_rule {
    id      = "alb"
    enabled = true

    prefix = "alb/"

    tags = {
      rule      = "alb"
      autoclean = "true"
    }

    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    expiration {
      days = 60
    }
  }
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = local.full_service_name

  load_balancer_type = "application"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.public_http.id]

/*
  # needed?
  depends_on = [
    aws_s3_bucket.hello_world
  ]

  access_logs = {
    bucket = aws_s3_bucket.hello_world.id
    prefix = "alb"
  }
*/

  tags = {
    Environment = local.environment
  }
}

resource "aws_alb_target_group" "main" {
  name        = local.full_service_name
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
   healthy_threshold   = "3"
   interval            = "30"
   protocol            = "HTTP"
   matcher             = "200"
   timeout             = "3"
   path                = "/"
   unhealthy_threshold = "2"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = module.alb.this_lb_arn
  port              = 80
  protocol          = "HTTP"

   default_action {
    target_group_arn = aws_alb_target_group.main.id
    type             = "forward"
  }
}
