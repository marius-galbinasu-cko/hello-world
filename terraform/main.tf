locals {
  service_name = "hello-world-ecs"
  environment  = "dev"

  # This is the convention we use to know what belongs to each other
  full_service_name = "${local.service_name}-${local.environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name = local.full_service_name

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
    Name        = local.full_service_name
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

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.hello_world.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"

  name = local.full_service_name

  # Launch configuration
  lc_name = local.full_service_name

  image_id             = data.aws_ami.amazon_linux_ecs.id
  instance_type        = "t2.nano"
  security_groups      = [aws_security_group.private_http.id]
  iam_instance_profile = module.ec2_profile.this_iam_instance_profile_id
  user_data            = data.template_file.user_data.rendered

  # Auto scaling group
  asg_name                  = local.full_service_name
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
      value               = local.full_service_name
      propagate_at_launch = true
    },
  ]
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user-data.sh")

  vars = {
    cluster_name = local.full_service_name
  }
}

