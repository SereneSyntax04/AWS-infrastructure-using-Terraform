
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



