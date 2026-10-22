# triple-stack-terraform

A 3-tier AWS architecture in Terraform.

```
Internet
   |
[ Public ALB ]                      public subnets (2 AZ)
   |
[ Web tier: nginx ASG ]             private subnets
   |
[ Internal ALB ]                    private subnets
   |
[ App tier: ASG, port 8080 ]        private subnets
   |
[ RDS MySQL (encrypted) ]           isolated DB subnets (no internet route)
```

## Layout

| File | Purpose |
|------|---------|
| `versions.tf` | Terraform/provider versions, default tags |
| `variables.tf` | All inputs |
| `network.tf` | VPC, subnets, IGW, NAT, route tables |
| `security.tf` | Security groups chained tier to tier |
| `compute.tf` | IAM (SSM), ALBs, launch templates, ASGs |
| `database.tf` | RDS MySQL, password in Secrets Manager |
| `outputs.tf` | URL, endpoints, secret ARN |

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
curl $(terraform output -raw web_url)
```

Access instances with SSM Session Manager (no SSH keys or open port 22).

## Cost notes

NAT gateways, ALBs and RDS are billed hourly. Run `terraform destroy` when done testing.

## Before production

- Use remote state (S3 + DynamoDB lock) via a backend block.
- Add HTTPS: ACM certificate and a 443 listener on the public ALB.
- Set `single_nat_gateway = false`, `db_multi_az = true`, `db_deletion_protection = true`, `db_skip_final_snapshot = false`.
- Replace the placeholder app with your real service or container image.
- Add CloudWatch alarms and ASG scaling policies.
