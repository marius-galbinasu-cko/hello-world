#----- ECS --------
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
 
  name               = local.full_service_name
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

  name = local.service_name

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

###################
# Disabled cluster
###################
module "disabled_ecs" {
  source  = "terraform-aws-modules/ecs/aws"

  create_ecs = false
}