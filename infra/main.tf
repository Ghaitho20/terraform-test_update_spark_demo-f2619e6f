terraform {
  backend "s3" {
    bucket         = "tfstate-test-update-spark-demo-ce5a7kua"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tflock-test-update-spark-demo-ce5a7kua"
    encrypt        = true
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Remote backend — state stored in S3, locking via DynamoDB
# (Provisioned by the bootstrap/ folder)
# ─────────────────────────────────────────────────────────────────────────────


terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_region" "current" {}

resource "random_string" "suffix" {
  length  = 18
  special = false
  upper   = false
}

resource "aws_s3_bucket" "scripts" {
  bucket        = "${var.scripts_bucket_base_name}-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket" "output" {
  bucket        = "${var.output_bucket_base_name}-${random_string.suffix.result}"
  force_destroy = true
}

resource "aws_s3_bucket" "archive" {
  bucket        = "${var.archive_bucket_base_name}-${random_string.suffix.result}"
  force_destroy = true
}

resource "local_file" "glue_test_script" {
  filename = "${path.module}/glue_test_script.py"
  content  = <<EOF
import sys
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
print("Hello from TEST script")
print("This is a placeholder Glue script for Terraform provisioning.")
EOF
}

resource "local_file" "glue_archive_test_script" {
  filename = "${path.module}/glue_archive_test_script.py"
  content  = <<EOF
import sys
from awsglue.utils import getResolvedOptions

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
print("Hello from ARCHIVE TEST script")
print("This is a placeholder Glue script for the additional Glue job.")
EOF
}

resource "aws_s3_object" "glue_test_script" {
  bucket       = aws_s3_bucket.scripts.id
  key          = "scripts/glue_test_script.py"
  source       = local_file.glue_test_script.filename
  content_type = "text/x-python"
  etag         = local_file.glue_test_script.content_md5
}

resource "aws_s3_object" "glue_archive_test_script" {
  bucket       = aws_s3_bucket.scripts.id
  key          = "scripts/glue_archive_test_script.py"
  source       = local_file.glue_archive_test_script.filename
  content_type = "text/x-python"
  etag         = local_file.glue_archive_test_script.content_md5
}

resource "aws_iam_role" "glue" {
  name = "${var.glue_role_base_name}-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_admin" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "glue_archive" {
  name = "${var.glue_archive_role_base_name}-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_archive_service" {
  role       = aws_iam_role.glue_archive.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_archive_admin" {
  role       = aws_iam_role.glue_archive.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_glue_job" "count_numbers" {
  name              = "${var.glue_job_base_name}-${random_string.suffix.result}"
  role_arn          = aws_iam_role.glue.arn
  glue_version      = "5.0"
  max_retries       = 0
  timeout           = 10
  number_of_workers = 2
  worker_type       = "G.1X"

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_test_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--TempDir"                          = "s3://${aws_s3_bucket.scripts.bucket}/temp/"
    "--output_bucket"                    = aws_s3_bucket.output.bucket
  }

  execution_property {
    max_concurrent_runs = 1
  }

  depends_on = [
    aws_s3_object.glue_test_script,
    aws_iam_role_policy_attachment.glue_service,
    aws_iam_role_policy_attachment.glue_admin
  ]
}

resource "aws_glue_job" "archive_numbers" {
  name              = "${var.glue_archive_job_base_name}-${random_string.suffix.result}"
  role_arn          = aws_iam_role.glue_archive.arn
  glue_version      = "5.0"
  max_retries       = 0
  timeout           = 10
  number_of_workers = 2
  worker_type       = "G.1X"

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_archive_test_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = ""
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-continuous-log-filter"     = "true"
    "--TempDir"                          = "s3://${aws_s3_bucket.scripts.bucket}/temp/"
    "--output_bucket"                    = aws_s3_bucket.archive.bucket
  }

  execution_property {
    max_concurrent_runs = 1
  }

  depends_on = [
    aws_s3_object.glue_archive_test_script,
    aws_iam_role_policy_attachment.glue_archive_service,
    aws_iam_role_policy_attachment.glue_archive_admin
  ]
}
