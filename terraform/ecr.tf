resource "aws_ecr_repository" "hello_world" {
  name                 = "hello-world"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
