provider "aws" {
  region = "eu-west-2"
}

/*
TODO

resource "aws_dynamodb_table" "dynamodb-terraform-lock" {
   name = "terraform-lock"
   hash_key = "LockID"
   read_capacity = 20
   write_capacity = 20

   attribute {
      name = "LockID"
      type = "S"
   }

   tags {
     Name = "Terraform Lock Table"
   }
}

terraform {
  backend "s3" {
    bucket = "terraform-s3-tfstate"
    region = "us-east-2"
    key = "ec2-example/terraform.tfstate"
    dynamodb_table = "terraform-lock"
    encrypt = true
  }
}
*/
