variable "aws_region" {
  description = "AWS region used for the lab."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for AWS resource names."
  type        = string
  default     = "k8s-aws-challenge"
}

variable "instance_type" {
  description = "EC2 size for Docker + minikube. t3.medium is recommended."
  type        = string
  default     = "t3.medium"
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH to the EC2 instance. Replace with your public IP, for example 203.0.113.10/32."
  type        = string
  default     = "0.0.0.0/0"
}

variable "node_port" {
  description = "Fixed Kubernetes NodePort exposed through the ALB target group."
  type        = number
  default     = 30080

  validation {
    condition     = var.node_port >= 30000 && var.node_port <= 32767
    error_message = "node_port must be in the Kubernetes NodePort range 30000-32767."
  }
}

variable "app_replicas" {
  description = "Number of nginx demo Pods."
  type        = number
  default     = 3
}
