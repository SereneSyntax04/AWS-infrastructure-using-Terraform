# This tells Terraform:
# "Run the reusable VPC module to create networking for this environment (prod)"

module "vpc" {
  source = "../../modules/vpc" # Path to the module source code

  env = var.env

  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  availability_zone = var.availability_zone
}

/*
This block is NOT creating AWS resources directly.
It is telling Terraform:
“Run that VPC blueprint from /modules/vpc using these values.”
*/
