variable "aws_region" {
  description = "AWS region for the provider and the AWS_REGION Actions variable."
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub owner/organization."
  type        = string
  default     = "samarthsharma-maker"
}

variable "github_repo" {
  description = "Repository to wire up."
  type        = string
  default     = "terraform-ai-project"
}

variable "short_name" {
  description = "Short slug for AWS resource naming."
  type        = string
  default     = "scalerapp"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "github_token" {
  description = "GitHub PAT for managing Actions secrets. Leave null and export GITHUB_TOKEN instead."
  type        = string
  sensitive   = true
  default     = null
}