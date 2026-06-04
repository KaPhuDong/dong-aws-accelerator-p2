# K8s on AWS - Terraform 1-Click

Terraform lab for the Thursday Kubernetes challenge:

- Creates an EC2 instance in the default VPC.
- Generates an SSH key with the `tls` provider and saves a `.pem` locally.
- Installs Docker, `kubectl`, and `minikube` on EC2.
- Starts minikube with the Docker driver.
- Deploys a static portfolio site on nginx inside Kubernetes as a fixed NodePort service.
- Exposes the app through an AWS Application Load Balancer.

## Run

```powershell
cd cloud\w8\thu\k8s-aws-challenge
copy terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and replace `ssh_allowed_cidr` with your public IP in `/32` form.

```powershell
terraform init
terraform apply
```

Open the `alb_url` output after apply finishes. ALB health checks may take 1-2 minutes to become healthy.

## How ALB reaches minikube

The lab starts minikube with `--driver=docker --ports=30080:30080`. That Docker port mapping publishes the fixed Kubernetes NodePort on the EC2 host, allowing the ALB target group to use target type `instance`.

## Cleanup

```powershell
terraform destroy
```
