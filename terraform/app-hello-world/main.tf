resource "aws_cloudwatch_log_group" "hello_world" {
  name              = "hello_world"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "hello_world" {
  family = "hello_world"
  network_mode = "awsvpc"

  container_definitions = <<EOF
[
  {
    "name": "hello_world",
    "image": "454648136210.dkr.ecr.eu-west-2.amazonaws.com/hello-world:dev-20210228-2123",
    "cpu": 0,
    "memory": 128,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol": "tcp"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-region": "eu-west-2",
        "awslogs-group": "hello_world",
        "awslogs-stream-prefix": "checkout"
      }
    }
  }
]
EOF
}

resource "aws_ecs_service" "hello_world" {
  name            = "hello_world"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.hello_world.arn

  desired_count = 1

  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  network_configuration {
    subnets = var.subnet_ids
    security_groups = var.security_groups
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "hello_world"
    container_port   = 80
  }

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [
      desired_count,
      capacity_provider_strategy
    ]
  }
}
