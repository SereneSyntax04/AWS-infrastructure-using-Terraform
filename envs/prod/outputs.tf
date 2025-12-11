
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}


/*

After terraform apply:

To Show everything:
> terraform output

Show only VPC id:
> terraform output vpc_id

JSON format (used in pipelines):
> terraform output -json

*/
