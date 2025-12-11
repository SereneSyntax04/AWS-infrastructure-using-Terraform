variable "env" {
  type = string
}
variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(string) # - We can define MULTIPLE subnet ranges , eg:["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  # ✅ VALIDATION RULE
  validation {
    condition     = length(var.public_subnets) == length(var.availability_zone)
    error_message = "Number of public_subnets must match number of availability_zones. "
  }
}

variable "availability_zone" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
  validation {
    condition     = length(var.private_subnets) == length(var.availability_zone)
    error_message = "Number of public_subnets must match number of availability_zones. "
  }
}



# 0812-------------------------------------------------------------------------------------------
# Create NAT gateway(s)? (set false to skip)
variable "create_nat" {
  type    = bool
  default = true
}

# If true, create one NAT gateway per public subnet (recommended for AZ fault tolerance).
# If false, create a single NAT gateway in the first public subnet.
variable "nat_high_availability" {
  type    = bool
  default = false # << THIS = cost optimized mode
}



# 0912-------------------------------------------------------------------------------------------
