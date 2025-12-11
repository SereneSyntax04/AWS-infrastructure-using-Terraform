<h1 align='center'> NOTES & TIPS </h1>

- When using AWS CLI with LocalStack, either pass `--region` every time or run `aws configure` with region `us-east-1` and fake creds `(test/test)`.
- If AWS CLI output is paged with `“-- More --”`, add `--no-cli-pager` or run:
```bash
aws configure set cli_pager ""
```
- Always run `terraform destroy` BEFORE deleting `.terraform` or stopping LocalStack — otherwise Terraform can’t reach the local provider to delete resources.


---


<h2 align = 'center'> 🚀 STEP-BY-STEP DEPLOYMENT </h2>

### STEP 1:

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
