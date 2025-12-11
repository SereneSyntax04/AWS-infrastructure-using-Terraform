<h1 align='center'> NOTES & TIPS </h1>

- When using AWS CLI with LocalStack, either pass `--region` every time or run `aws configure` with region `us-east-1` and fake creds `(test/test)`.
- If AWS CLI output is paged with `“-- More --”`, add `--no-cli-pager` or run:
```bash
aws configure set cli_pager ""
```
- Always run `terraform destroy` BEFORE deleting `.terraform` or stopping LocalStack — otherwise Terraform can’t reach the local provider to delete resources.


---


<h2 align = 'center'> 🚀 STEP-BY-STEP DEPLOYMENT </h2>

# STEP 1: Start LocalStack

### Remove existing LocalStack container if any

```
docker rm -f localstack
```

### Start LocalStack container

```
docker run -d --name localstack -p 4566:4566 localstack/localstack
```

### Check if container is running
```
docker ps
```

### Remove any prior .terraform folder (PowerShell)
```
Remove-Item -Recurse -Force .terraform -ErrorAction SilentlyContinue 
```

---

# STEP 2: RUN TERRAFORM

<b> Go to the environment folder:   cd  <folder-path>/envs/prod </b>

### Initialize Terraform:
```
terraform init
terraform validate
```

### Deploy the VPC and resources:
```
terraform apply -auto-approve
```

---

# STEP 3: VERIFY — AWS CLI (LocalStack)

### Configure the AWS CLI: 
```
aws configure
 AWS Access Key ID     : test
 AWS Secret Access Key : test
 Default region name   : us-east-1
 Default output format : json
```

### List VPCs to verify deployment:
```
aws ec2 describe-vpcs --endpoint-url=http://localhost:4566
```

<b> What to look for: </b>

- You should see two VPCs

- The default LocalStack VPC (usually 172.31.0.0/16), marked as "IsDefault": true.

- The VPC you created using Terraform, with the CIDR and Name you specified in your terraform.tfvars.

Focus on the "VpcId" that matches the one defined in your .tfvars file — this confirms your Terraform deployment succeeded.

---

# STEP 4:  VERIFY SUBNETS

### Command to list subnets:
```
aws ec2 describe-subnets --region us-east-1 --endpoint-url=http://localhost:4566
```
<b> What to look for: </b>

- You should see subnets corresponding to your Terraform deployment:

- Public subnets with the CIDRs you defined in terraform.tfvars.

- Private subnets with the CIDRs you defined in terraform.tfvars.

- Ignore the default LocalStack subnets.

Focus on the "SubnetId" and "CidrBlock" values to ensure they match your configuration.

---

# STEP 5:VERIFY NAT GATEWAYS

### Command to list NAT Gateways:
```
aws ec2 describe-nat-gateways --region us-east-1 --endpoint-url=http://localhost:4566
```

<b> What to look for: </b>

- Terraform should have created NAT Gateways in your public subnets (if configured).

- Each NAT Gateway will have:

1. A "NatGatewayId" (unique ID)

2. "SubnetId" indicating which public subnet it belongs to

3. "State" — should be "available" once deployed

- Focus on matching "SubnetId" with the public subnets you defined in your terraform.tfvars.

Ignore any default resources created by LocalStack.

---

# STEP 6: VERIFY ELASTIC IP ADDRESSES

### Command to list Elastic IPs:
```
aws ec2 describe-addresses --region us-east-1 --endpoint-url=http://localhost:4566
```

<b> What to look for: </b>

- Terraform should have allocated Elastic IPs (if used for NAT Gateways or other resources).

- Each address will show:

1. "PublicIp" — the Elastic IP assigned

2. "AllocationId" — the ID of the allocated EIP

3. "AssociationId" — if the EIP is associated with a resource like a NAT Gateway

- Focus on matching allocations with your NAT Gateways or resources defined in your terraform.tfvars.

Ignore any default or unrelated addresses that LocalStack may have.

---

# STEP 7: VERIFY ROUTE TABLES

###  Command to list route tables:
```
aws ec2 describe-route-tables --region us-east-1 --endpoint-url=http://localhost:4566
```

<b> What to look for: </b>

- Terraform should have created route tables for your VPC subnets.

- Each route table will include:

1. "RouteTableId" — unique ID of the route table

2. "VpcId" — should match your VPC from terraform.tfvars

3. "Associations" — shows which subnets are associated with the table

4. "Routes" — should include the default route (0.0.0.0/0) pointing to:

- IGW for public subnets

- NAT Gateway for private subnets

- Focus on verifying that the routes match your architecture and that subnets are associated correctly.

Ignore default route tables created by LocalStack.

---
---

<br><br>


---
---

# 🛠 STEPS TO FIX VALIDATION ERROR 
*(Use this when you corrected a typo in Terraform code but the same validation error still appears)*

## STEP 1 — COMPLETELY CLEAR TERRAFORM CACHE

### Delete cached providers & modules:
```
Remove-Item -Recurse -Force .terraform
```

### (Optional — if things are really stuck)
<b> Delete old state files: </b>
```
Remove-Item -Force terraform.tfstate
Remove-Item -Force terraform.tfstate.backup
```

## STEP 2 — RE-INITIALIZE TERRAFORM

### Re-download providers/modules from scratch:
```
terraform init -reconfigure
```

## STEP 3 — VALIDATE AGAIN

### Re-run validation:
```
terraform validate
```

## ✅ If no errors appear, the cache was the issue.


---
---

<br><br>


---
---

# 🧹 STEP-BY-STEP CLEANUP

## STEP 1 — Destroy Terraform infra

```
terraform destroy -auto-approve
```
<b>What this does: </b>

- Deletes your VPC

- Deletes subnets

- Deletes route tables

- Deletes Internet Gateway (IGW)

- Leaves LocalStack default resources untouched (expected)


## STEP 2 — Verify everything is gone

**Check VPCs:**
```
aws ec2 describe-vpcs --no-cli-pager --region us-east-1 --endpoint-url=http://localhost:4566
```
> You should now see ONLY ONE VPC: "IsDefault": true

**Check subnets:**
```
aws ec2 describe-subnets --no-cli-pager --region us-east-1 --endpoint-url=http://localhost:4566
```
> You should see ONLY default subnets (172.31.*.*)


## STEP 3 — Delete Terraform state + cache
```
Remove-Item -Recurse -Force .terraform
Remove-Item -Force terraform.tfstate
Remove-Item -Force terraform.tfstate.backup
```
<b>This wipes: </b>

1. Provider cache

2. Local state

3. Backup state

> ⚠️ Safe only after terraform destroy, because nothing remains to manage.


## STEP 4 — Stop & remove Docker LocalStack

### Check container name:
```
docker ps
```

### Stop the container:
```
docker stop localstack
```

### Remove the container:
```
docker rm localstack
```

### (Optional — remove image completely)
```
docker rmi localstack/localstack
```


## STEP 5 — Verify Docker is clean
```
docker ps
```
- No containers should show.
