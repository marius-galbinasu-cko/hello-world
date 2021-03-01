variable "cluster_id" {
  description = "The ECS cluster ID"
  type        = string
}

variable "target_group_arn" {
  description = "The ARN of the target group to register on"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet ids to which a service is deployed"
  default = []
}
