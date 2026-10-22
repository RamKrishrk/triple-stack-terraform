variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "triple-stack"
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (cheaper, dev) instead of one per AZ (HA, prod)"
  type        = bool
  default     = true
}

variable "allowed_http_cidrs" {
  description = "CIDRs allowed to reach the public web load balancer"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------- Web tier ----------
variable "web_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "web_asg_min" {
  type    = number
  default = 2
}

variable "web_asg_desired" {
  type    = number
  default = 2
}

variable "web_asg_max" {
  type    = number
  default = 4
}

# ---------- App tier ----------
variable "app_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "app_asg_min" {
  type    = number
  default = 2
}

variable "app_asg_desired" {
  type    = number
  default = 2
}

variable "app_asg_max" {
  type    = number
  default = 4
}

# ---------- Database tier ----------
variable "db_engine_version" {
  type    = string
  default = "8.0"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appadmin"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS (recommended for prod)"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on destroy (set false for prod)"
  type        = bool
  default     = true
}
