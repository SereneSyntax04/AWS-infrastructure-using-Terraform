
provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  # These prevent Terraform from contacting real AWS services to validate identity.
  # Stops Terraform from:
  skip_credentials_validation = true # stop from Calling AWS STS to check credentials
  skip_metadata_api_check     = true # stop from Trying to call EC2 instance metadata service (happens on AWS EC2 machines)
  skip_requesting_account_id  = true # stop from Calling AWS to get the account ID

  endpoints {
    ec2 = "http://localhost:4566"
    # Instead of calling: https://ec2.us-east-1.amazonaws.com
    # Terraform calls: http://localhost:4566
    elbv2       = "http://localhost:4566"
    autoscaling = "http://localhost:4566"
    iam         = "http://localhost:4566"
    sts         = "http://localhost:4566"
  }
}




/*steps to execute this infra:
STEP 1:
START LOCALSTACK (Docker)
> docker run -d --name localstack -p 4566:4566 localstack/localstack
Check container is running:
> docker ps

STEP 2
RUN TERRAFORM
Go to env folder: cd terraform-infra/envs/prod
Initialize Terraform:
> terraform init
> terraform validate
Deploy VPC:
> terraform apply -auto-approve

STEP 3
VERIFY — AWS CLI (LocalStack)
Configure the AWS CLI:
aws configure
AWS Access Key ID     : test
AWS Secret Access Key: test
Default region name  : us-east-1
Default output format: json

List VPCs:
aws ec2 describe-vpcs --endpoint-url=http://localhost:4566
this was the output::
PS C:\Users\sshrivastav\OneDrive - Scitara Technologies Private Limited\TFscitara\terraform-infra\envs\prod> aws ec2 describe-vpcs --endpoint-url=http://localhost:4566
{
    "Vpcs": [
        {
            "OwnerId": "000000000000",
            "InstanceTenancy": "default",
            "Ipv6CidrBlockAssociationSet": [],
            "CidrBlockAssociationSet": [
                {
                    "AssociationId": "vpc-cidr-assoc-3e52a22dc91b15542",
                    "CidrBlock": "172.31.0.0/16",
                    "CidrBlockState": {
                        "State": "associated"
                    }
                }
            ],
            "IsDefault": true,
            "Tags": [],
            "VpcId": "vpc-7f893f36b371ca000",
            "State": "available",
            "CidrBlock": "172.31.0.0/16",
            "DhcpOptionsId": "default"
        },
        {
            "OwnerId": "000000000000",
            "InstanceTenancy": "default",
            "Ipv6CidrBlockAssociationSet": [],
            "CidrBlockAssociationSet": [
                {
                    "AssociationId": "vpc-cidr-assoc-864267d939885135c",
                    "CidrBlock": "10.0.0.0/16",
                    "CidrBlockState": {
                        "State": "associated"
                    }
                }
            ],
            "IsDefault": false,
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "prod-vpc"
                }
            ],
            "VpcId": "vpc-19b85f255584df2ea",
            "State": "available",
            "CidrBlock": "10.0.0.0/16",
            "DhcpOptionsId": "default"
        }
    ]
}


in case you see : -- More  -- at the end just hit space tab and further content will load once your desired thing is visible you can quit using 'q'.

STEP 4
Verify Subnets
aws ec2 describe-subnets --region us-east-1 --endpoint-url=http://localhost:4566
{
    "Subnets": [
        {
            "AvailabilityZoneId": "use1-az6",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-4ae4d77a19548728d",
            "Ipv6Native": false,
            "SubnetId": "subnet-4ae4d77a19548728d",
            "State": "available",
            "VpcId": "vpc-7f893f36b371ca000",
            "CidrBlock": "172.31.0.0/20",
            "AvailableIpAddressCount": 4091,
            "AvailabilityZone": "us-east-1a",
            "DefaultForAz": true,
            "MapPublicIpOnLaunch": true
        },
        {
            "AvailabilityZoneId": "use1-az6",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "prod-PrivateSubnet-1"
                }
            ],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-d996b1b4cf158b670",
            "Ipv6Native": false,
            "PrivateDnsNameOptionsOnLaunch": {
                "HostnameType": "ip-name"
            },
            "SubnetId": "subnet-d996b1b4cf158b670",
            "State": "available",
            "VpcId": "vpc-19b85f255584df2ea",
            "CidrBlock": "10.0.101.0/24",
            "AvailableIpAddressCount": 251,
            "AvailabilityZone": "us-east-1a",
            "DefaultForAz": false,
            "MapPublicIpOnLaunch": false
        },
        {
            "AvailabilityZoneId": "use1-az6",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "prod-PublicSubnet-1"
                }
            ],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-87608b57be9f990eb",
            "Ipv6Native": false,
            "PrivateDnsNameOptionsOnLaunch": {
                "HostnameType": "ip-name"
            },
            "SubnetId": "subnet-87608b57be9f990eb",
            "State": "available",
            "VpcId": "vpc-19b85f255584df2ea",
            "CidrBlock": "10.0.1.0/24",
            "AvailableIpAddressCount": 251,
            "AvailabilityZone": "us-east-1a",
            "DefaultForAz": false,
            "MapPublicIpOnLaunch": true
        },
        {
            "AvailabilityZoneId": "use1-az1",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-65cd27aa5910effc0",
            "Ipv6Native": false,
            "SubnetId": "subnet-65cd27aa5910effc0",
            "State": "available",
            "VpcId": "vpc-7f893f36b371ca000",
            "CidrBlock": "172.31.16.0/20",
            "AvailableIpAddressCount": 4091,
            "AvailabilityZone": "us-east-1b",
            "DefaultForAz": true,
            "MapPublicIpOnLaunch": true
        },
        {
            "AvailabilityZoneId": "use1-az1",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "prod-PrivateSubnet-2"
                }
            ],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-af3f69600d2db2d9f",
            "Ipv6Native": false,
            "PrivateDnsNameOptionsOnLaunch": {
                "HostnameType": "ip-name"
            },
            "SubnetId": "subnet-af3f69600d2db2d9f",
            "State": "available",
            "VpcId": "vpc-19b85f255584df2ea",
            "CidrBlock": "10.0.102.0/24",
            "AvailableIpAddressCount": 251,
            "AvailabilityZone": "us-east-1b",
            "DefaultForAz": false,
            "MapPublicIpOnLaunch": false
        },
        {
            "AvailabilityZoneId": "use1-az1",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "prod-PublicSubnet-2"
                }
            ],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-a2d114171fe71c559",
            "Ipv6Native": false,
            "PrivateDnsNameOptionsOnLaunch": {
                "HostnameType": "ip-name"
            },
            "SubnetId": "subnet-a2d114171fe71c559",
            "State": "available",
            "VpcId": "vpc-19b85f255584df2ea",
            "CidrBlock": "10.0.2.0/24",
            "AvailableIpAddressCount": 251,
            "AvailabilityZone": "us-east-1b",
            "DefaultForAz": false,
            "MapPublicIpOnLaunch": true
        },
        {
            "AvailabilityZoneId": "use1-az2",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-a9dddb8ef596271f4",
            "Ipv6Native": false,
            "SubnetId": "subnet-a9dddb8ef596271f4",
            "State": "available",
            "VpcId": "vpc-7f893f36b371ca000",
            "CidrBlock": "172.31.32.0/20",
            "AvailableIpAddressCount": 4091,
            "AvailabilityZone": "us-east-1c",
            "DefaultForAz": true,
            "MapPublicIpOnLaunch": true
        },
        {
            "AvailabilityZoneId": "use1-az4",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-488ddd3316d14dfb2",
            "Ipv6Native": false,
            "SubnetId": "subnet-488ddd3316d14dfb2",
            "State": "available",
            "VpcId": "vpc-7f893f36b371ca000",
            "CidrBlock": "172.31.48.0/20",
            "AvailableIpAddressCount": 4091,
            "AvailabilityZone": "us-east-1d",
            "DefaultForAz": true,
            "MapPublicIpOnLaunch": true
        },
        {
            "AvailabilityZoneId": "use1-az3",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-372afc9f091d1f066",
            "Ipv6Native": false,
            "SubnetId": "subnet-372afc9f091d1f066",
            "State": "available",
            "VpcId": "vpc-7f893f36b371ca000",
            "CidrBlock": "172.31.64.0/20",
            "AvailableIpAddressCount": 4091,
            "AvailabilityZone": "us-east-1e",
            "DefaultForAz": true,
            "MapPublicIpOnLaunch": true
        },
        {
            "AvailabilityZoneId": "use1-az5",
            "OwnerId": "000000000000",
            "AssignIpv6AddressOnCreation": false,
            "Ipv6CidrBlockAssociationSet": [],
            "Tags": [],
            "SubnetArn": "arn:aws:ec2:us-east-1:000000000000:subnet/subnet-3a3ad4ccc2a7605c9",
            "Ipv6Native": false,
            "SubnetId": "subnet-3a3ad4ccc2a7605c9",
            "State": "available",
            "VpcId": "vpc-7f893f36b371ca000",
            "CidrBlock": "172.31.80.0/20",
            "AvailableIpAddressCount": 4091,
            "AvailabilityZone": "us-east-1f",
            "DefaultForAz": true,
            "MapPublicIpOnLaunch": true
        }
    ]
}

*/

/*  use this when there was a typo error , you fixed that but still same error appears. 
Completely clear Terraform cache:
>Remove-Item -Recurse -Force .terraform
after that command 
> terraform init -reconfigure (Re-initialize modules + providers)
> terraform validate (validate again)

*/
