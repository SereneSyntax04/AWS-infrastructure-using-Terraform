# VPC = main private network container where all AWS resources live
resource "aws_vpc" "myvpc" {
  cidr_block = var.vpc_cidr # IP range for entire VPC (parent range for all subnets)

  enable_dns_support = true # Enable internal AWS DNS resolution
  # Required for instances to resolve: - AWS service endpoints (ec2.amazonaws.com, etc.)

  enable_dns_hostnames = true # Give EC2 public DNS names, Without this, EC2 instances with public IPs will NOT get:
  # ec2-xx-xx-xx-xx.compute.amazonaws.com

  tags = {
    Name = "${var.env}-vpc" # Human-readable name of the VPC , Example: "prod-vpc", "dev-vpc"
  }
}



# IGW is attached to the VPC — it is the VPC’s "door" to the internet
# Subnets do NOT connect directly to the internet; they route traffic via IGW
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id # Attach IGW to our VPC

  tags = {
    Name = "${var.env}-igw"
  }
}


# 0912-----------------------------------------------------------------------------------------
/*
security wall that makes your “public → private” design safe.
This code creates 2 security doors (Security Groups):
Internet ──▶ [ ALB Security Group ] ──▶ ALB ──▶ [ APP Security Group ] ──▶ EC2 (private)
Think: alb_sg = Front door, app_sg = Inner vault door
No one reaches your private EC2 without passing both.
*/
# Public ALB Security Group
resource "aws_security_group" "alb_sg" {
  name   = "${var.env}-alb-sg"
  vpc_id = aws_vpc.myvpc.id #Create SG in VPC so vpc resources can use it 

  ingress {
    from_port   = 80 #(HTTP)
    to_port     = 80 #(HTTP)
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } # Public User → ALB ✅

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } /*Allow this resource to open outbound connections
      - On ANY port
      - Using ANY protocol
      - To ANY destination IP
      basically: ALB → Private EC2 instances ✅ (alb -- alb listener -- target group -- ec2) */
}

# This SG is applied to EC2 instances inside PRIVATE SUBNETS — your microservices
# Private EC2 Application SG
resource "aws_security_group" "app_sg" {
  name   = "${var.env}-app-sg"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] #Allow traffic to port 80 ONLY if that traffic comes from something that uses the ALB Security Group.
  } /*This guarantees:
      - Nobody bypasses the ALB
      - Your private servers remain invisible*/

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } # EC2 → NAT → Internet 
}
# ---------------------------------------------------------------------------------------------


# SUBNETS - smaller IP ranges created inside the VPC.
# "Public" subnet means: instances CAN reach the internet, (via route table → internet gateway) AND can get public IPs.
resource "aws_subnet" "public" {
  /* count is not a normal argument like vpc_id or cidr_block. It is a meta-argument — Terraform uses it to decide:
    Should this resource run once or multiple times? , How many instances should be created?
    count = How many copies of this resource Terraform should create
  Terraform must know that before it reads the rest of the block. so meta-arguments always come first.*/

  # Create multiple subnets using a list of CIDR blocks
  # Example: var.public_cidr = ["10.0.1.0/24", "10.0.2.0/24"] → This resource runs twice (once per CIDR)
  count = length(var.public_subnets) # Meta-argument MUST come first (count), length() = Counts number of items in a list

  vpc_id     = aws_vpc.myvpc.id                # Attach each subnet inside our VPC (normal argument)
  cidr_block = var.public_subnets[count.index] # Assign subnet IP range based on the current index (0,1,2...)

  # Automatically give EC2 instances a public IP when launched here, (Required for direct internet access)
  map_public_ip_on_launch = true

  # Place each subnet in a different Availability Zone, AZ list index matches subnet index for proper pairing
  availability_zone = var.availability_zone[count.index]

  tags = {
    Name = "${var.env}-PublicSubnet-${count.index + 1}"
  }
}


# PRIVATE SUBNETS
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id     = aws_vpc.myvpc.id
  cidr_block = var.private_subnets[count.index]

  availability_zone = var.availability_zone[count.index]
  /*
  If private_subnets length > availability_zones length this will error (index out-of-range). If you want more subnets than AZs, use modulo cycling:
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  (That re-uses AZs in round-robin.)
  */
  tags = {
    Name = "${var.env}-PrivateSubnet-${count.index + 1}"
  }
}




# PUBLIC ROUTE TABLE
# Holds routing rules used by public subnets (example: 0.0.0.0/0 → Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "${var.env}-public-rt"
  }
} # A route table by itself does nothing until you add routes (rules) and associations (which subnets use it).


# Right now your VPC + IGW + public subnets exist… but without below two blocks, nothing is actually public yet
# Default Internet Route: "Send all unknown traffic (0.0.0.0/0) to the Internet Gateway"
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id  # Which route table this rule belongs to
  destination_cidr_block = "0.0.0.0/0"                #Means: “This route matches ALL possible IPv4 addresses.” This is effectively “the entire internet”
  gateway_id             = aws_internet_gateway.gw.id #Means: “Send matched traffic to the Internet Gateway.”
}                                                     #If destination = anything not in my VPC → send packets to IGW 
/*This rule sends all internet-bound traffic from subnets that use this RT to the Internet Gateway (IGW).
Without this route, subnets are not public even if instances have public IPs.*/


# Associate Public Subnets with RT
# Attach the public route table to EVERY public subnet, so those subnets actually become "public"
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)         # Loop through all public subnets created earlier
  subnet_id      = aws_subnet.public[count.index].id # Pick each subnet by index
  route_table_id = aws_route_table.public.id         # Attach them to the public route table
}
# This attaches the route table to each public subnet so they inherit the routing rules.

/*A route table is a list of traffic rules that decides where packets leaving a subnet should go. 
For public subnets you usually add a rule that says “send internet traffic to the Internet Gateway.” 
You then attach that route table to the public subnets so instances there can reach the internet.*/




# 0812 --------------------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  # This controls how MANY EIPs are created.
  count = var.create_nat ? (var.nat_high_availability ? length(aws_subnet.public) : 1) : 0
  /*
  var.create_nat -- 
true → NAT system ON
false → NAT system OFF

  var.nat_high_availability (Decides NAT strategy)
true → NAT in every AZ (HA)
false → single cheap NAT

  length(aws_subnet.public)-- Counts how many public subnets exist.(1 subnet per AZ)

  */
  domain = "vpc"

  tags = {
    Name = "${var.env}-nat-eip-${count.index + 1}"
  }

}

# Create NAT gateway(s) in public subnet(s)
resource "aws_nat_gateway" "nat" {
  count         = var.create_nat ? (var.nat_high_availability ? length(aws_subnet.public) : 1) : 0 #COUNT how many NAT gateways?
  allocation_id = aws_eip.nat[count.index].id                                                      # EIP ATTACHMENT - This is how NAT gets its public IP address.

  # This decides: Which public subnet the NAT gateway is created in
  subnet_id = var.nat_high_availability ? aws_subnet.public[count.index].id : aws_subnet.public[0].id
  /*
  Case 1 — SINGLE NAT
  When nat_high_availability = false:
  subnet_id = aws_subnet.public[0].id\
  Result:
    NAT lives in first public subnet
    ALL private subnets route to it
  
  Case 2 — HA NAT
  When nat_high_availability = true:
  subnet_id = aws_subnet.public[count.index].id
  Result:
    NAT[0] → public-subnet[0]
    NAT[1] → public-subnet[1]
    NAT[2] → public-subnet[2]
  One NAT per AZ = true high availability
  */

  tags = {
    Name = "${var.env}-nat-${count.index + 1}"
  }

  # Terraform ordering
  depends_on = [aws_internet_gateway.gw]
}

# Private route table (all private subnets will be associated to this)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "${var.env}-private-rt"
  }
}

# Route: 0.0.0.0/0 -> NAT
# If single NAT then create one route; if HA we still create single route pointing to the NAT allocated for this module.
resource "aws_route" "private_nat_route" {
  count = var.create_nat ? 1 : 0 # If create_nat = true → create 1 route, If create_nat = false → create 0 routes (skip entirely, cause nat is 0)

  route_table_id         = aws_route_table.private.id #Insert this route into the private route table we created earlier.
  destination_cidr_block = "0.0.0.0/0"                # ALL IPv4 traffic going anywhere outside the VPC, Every outbound request heading out of a private subnet hits this rule.

  nat_gateway_id = aws_nat_gateway.nat[0].id # Send ALL internet-bound traffic to this NAT Gateway.
  #Since this design uses ONE route table, it chooses: Only the first NAT gateway [0]

  depends_on = [aws_nat_gateway.nat]
}

# Associate every private subnet with the private route table
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private) #Create one association PER PRIVATE SUBNET (eg: private subnets = 3 → 3 associations created)

  subnet_id      = aws_subnet.private[count.index].id #Subnet binding-- Each private subnet gets attached to the same table
  route_table_id = aws_route_table.private.id         #Route table reference-- Use THIS route table for THIS subnet.

}



# 0912-------------------------------------------------------------------------------------------
# TARGET GROUP
/*A Target Group is:
The list of backend servers that an ALB is allowed to forward traffic to.

ALB = traffic receiver
Target Group = traffic dispatcher

Target Group is the internal directory telling ALB exactly which private servers can receive traffic and whether they are healthy.*/
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.env}-tg"
  port     = 80               # EC2 SG: allow port 80 from ALB 
  protocol = "HTTP"           # ALB will communicate with the backend using plain HTTP.
  vpc_id   = aws_vpc.myvpc.id #Find backend targets inside THIS VPC only

  health_check {
    path     = "/"
    protocol = "HTTP"
    matcher  = "200"
  } /*
  Health Check = ALB’s automated fitness test for your servers.
It keeps pinging each instance, sends traffic only to those returning 200, 
and instantly removes unhealthy ones to ensure zero-downtime and automatic failover.
  */
}

/*
short flow 
User → IGW → ALB:80
ALB Listener → Target Group
ALB checks Target Group-- Which instances are healthy?
ALB picks one healthy target
ALB opens NEW outbound connection
EC2 accepts inbound , EC2 allows port 80 FROM ALB SG 
Response flows back , EC2 → ALB → User
*/


# ALB
resource "aws_lb" "alb" {
  name               = "${var.env}-alb"
  load_balancer_type = "application" #Create an Layer 7 HTTP/HTTPS load balancer
  internal           = false
  /*ALB gets public IP addresses, Routes via IGW, Internet users can reach it
  Public user → Internet → IGW → ALB 
  IF:
  internal = true (used for : Private ALB (internal=true) Bastion → Internal ALB → Internal services)
  ALB would be PRIVATE ONLY, No public IPs, Only reachable inside VPC, No internet traffic allowed*/

  subnets = aws_subnet.public[*].id #Deploy ALB nodes into ALL public subnets.
  # why mandatory? ALB must: Run in at least 2 Availability Zones, Provide high availability
  security_groups = [aws_security_group.alb_sg.id] #Your ALB security group allows:INBOUND:Port 80 from 0.0.0.0/0 (Anyone on internet can reach ALB)

}


# ALB LISTENER - the “brain” of the ALB.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn #Attach this listener to your ALB (created earlier). (No ARN = listener would have nowhere to live.)
  port              = 80             #ALB will listen for: HTTP connections on port 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  } #Any request received by ALB on:80 → forward to this target group.
}

/*
User → IGW → ALB:80
                ↓
        Listener rule fires
                ↓
      Target Group picks healthy EC2
                ↓
     ALB opens new TCP connection
                ↓
      EC2 receives request on :80

*/


# EC2 LAUNCH TEMPLATE
/*
this block is where your “private service machines” are defined.
*/
resource "aws_launch_template" "app_lt" {
  name_prefix   = "${var.env}-app-lt-"
  image_id      = "ami-12345678" # Fake acceptable AMI for LocalStack , In real AWS:Ubuntu 22.04, Amazon Linux 2023 AMI ID
  instance_type = "t2.micro"     #machine size.

  vpc_security_group_ids = [
    aws_security_group.app_sg.id
    /*Every EC2 instance launched from this template:
        - Will attach to app_sg
        - No public exposure
        - Accepts only traffic explicitly allowed by app_sg*/
  ]

  user_data = base64encode(<<EOF
#!/bin/bash
yum install -y nginx
systemctl enable nginx
systemctl start nginx
EOF
  ) #"First-time setup script"
  # AWS API requires user_data to be base64 encoded, Terraform won’t auto-handle it, so you must wrap your script with:base64encode(...)
}


# Auto Scaling Group — which actually creates these EC2s automatically
resource "aws_autoscaling_group" "app_asg" {
  name = "${var.env}-asg"
  #CAPACITY RULES-
  min_size         = 1
  desired_capacity = 2
  max_size         = 6
  # So at boot:ASG creates → 2 EC2 instances, If one dies:ASG launches another → back to 2

  # SUBNET PLACEMENT: Create these EC2 instances ONLY in private subnets.
  vpc_zone_identifier = aws_subnet.private[*].id

  # INSTANCE CREATION BLUEPRINT: This links the ASG to your Launch Template. So ASG does not decide configuration — it obeys the Launch Template.
  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  # TARGET GROUP REGISTRATION
  /*It says:
      Every EC2 created by this ASG:
      - Automatically registers into Target Group
      - ALB can now see it
      - ALB can health-check it
      - ALB can route traffic to it*/
  target_group_arns = [
    aws_lb_target_group.app_tg.arn
  ] # ASG → Target Group → ALB → Users


  tag {
    key                 = "Name"
    value               = "${var.env}-app"
    propagate_at_launch = true
  }
}



# Launch Template → HOW to build EC2
# ASG              → WHEN / HOW MANY to build
# ALB + TG         → WHERE traffic goes
