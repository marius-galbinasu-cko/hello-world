locals {
  name        = "hello-world-ecs"
  environment = "dev"

  # This is the convention we use to know what belongs to each other
  ec2_resources_name = "${local.name}-${local.environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name = local.name

  cidr = "10.1.0.0/16"

  azs             = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.11.0/24", "10.1.12.0/24"]

  # false is just faster, but it doesn't allow EC2 instances to join the cluster
  # as they cannot talk to the ECS api endpoint (or anything really)
  enable_nat_gateway = true
  single_nat_gateway = true

  # TODO: set VPC endpoints for ecs
  # enable_ecs_endpoint = true

  tags = {
    Environment = local.environment
    Name        = local.name
  }
}

resource "aws_security_group" "private_http" {
  name        = "private_allow_http"
  description = "Allow HTTP inbound traffic inside VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.1.11.0/24", "10.1.12.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "private-http"
  }
}

resource "aws_security_group" "public_http" {
  name        = "public_allow_http"
  description = "Allow HTTP inbound traffic from internet"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
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
    Name = "public-http"
  }
}

data "aws_kms_alias" "aws_s3" {
  name = "alias/aws/s3"
}

resource "aws_s3_bucket" "hello_world" {
  bucket = "application-hello-world-logs"
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
    Environment = "Dev"
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

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.hello_world.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "hello-world-alb"

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
    Environment = "Dev"
  }
}

resource "aws_alb_target_group" "main" {
  name        = "hello-world-tg-dev"
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

#----- ECS --------
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
 
  name               = local.name
  container_insights = true

  capacity_providers = ["FARGATE", "FARGATE_SPOT", aws_ecs_capacity_provider.prov1.name]

  default_capacity_provider_strategy = [{
    capacity_provider = aws_ecs_capacity_provider.prov1.name # "FARGATE_SPOT"
    weight            = "1"
  }]

  tags = {
    Environment = local.environment
  }
}

module "ec2_profile" {
  source  = "terraform-aws-modules/ecs/aws//modules/ecs-instance-profile"

  name = local.name

  tags = {
    Environment = local.environment
  }
}

resource "aws_ecs_capacity_provider" "prov1" {
  name = "prov1"

  auto_scaling_group_provider {
    auto_scaling_group_arn = module.asg.this_autoscaling_group_arn
  }

}

#----- ECS  Services--------
module "hello_world" {
  source = "./app-hello-world"

  cluster_id = module.ecs.this_ecs_cluster_id
  target_group_arn = aws_alb_target_group.main.arn
  subnet_ids = module.vpc.private_subnets
}

#----- ECS  Resources--------

#For now we only use the AWS ECS optimized ami <https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html>
data "aws_ami" "amazon_linux_ecs" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-*-amazon-ecs-optimized"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"

  name = local.ec2_resources_name

  # Launch configuration
  lc_name = local.ec2_resources_name

  image_id             = data.aws_ami.amazon_linux_ecs.id
  instance_type        = "t2.micro"
  security_groups      = [aws_security_group.private_http.id]
  iam_instance_profile = module.ec2_profile.this_iam_instance_profile_id
  user_data            = data.template_file.user_data.rendered

  # Auto scaling group
  asg_name                  = local.ec2_resources_name
  vpc_zone_identifier       = module.vpc.private_subnets
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 2
  desired_capacity          = 1
  wait_for_capacity_timeout = 0

  tags = [
    {
      key                 = "Environment"
      value               = local.environment
      propagate_at_launch = true
    },
    {
      key                 = "Cluster"
      value               = local.name
      propagate_at_launch = true
    },
  ]
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user-data.sh")

  vars = {
    cluster_name = local.name
  }
}

###################
# Disabled cluster
###################
module "disabled_ecs" {
  source  = "terraform-aws-modules/ecs/aws"

  create_ecs = false
}
