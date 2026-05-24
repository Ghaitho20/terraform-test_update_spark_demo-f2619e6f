variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "scripts_bucket_base_name" {
  description = "Base name for the Glue scripts/artifacts bucket"
  type        = string
}

variable "output_bucket_base_name" {
  description = "Base name for the output CSV bucket"
  type        = string
}

variable "glue_role_base_name" {
  description = "Base name for the Glue IAM role"
  type        = string
}

variable "glue_job_base_name" {
  description = "Base name for the Glue job"
  type        = string
}
