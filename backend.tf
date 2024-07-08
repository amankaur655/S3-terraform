terraform {
  backend "s3" {
    bucket         = "aman5189"
    key            = "terraform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_locks"
    encrypt        = true
  }
}
