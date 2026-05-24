output "aws_region" {
  value = data.aws_region.current.name
}

output "random_suffix" {
  value = random_string.suffix.result
}

output "scripts_bucket_name" {
  value = aws_s3_bucket.scripts.bucket
}

output "scripts_bucket_arn" {
  value = aws_s3_bucket.scripts.arn
}

output "scripts_bucket_domain_name" {
  value = aws_s3_bucket.scripts.bucket_domain_name
}

output "scripts_bucket_regional_domain_name" {
  value = aws_s3_bucket.scripts.bucket_regional_domain_name
}

output "output_bucket_name" {
  value = aws_s3_bucket.output.bucket
}

output "output_bucket_arn" {
  value = aws_s3_bucket.output.arn
}

output "output_bucket_domain_name" {
  value = aws_s3_bucket.output.bucket_domain_name
}

output "output_bucket_regional_domain_name" {
  value = aws_s3_bucket.output.bucket_regional_domain_name
}

output "glue_test_script_s3_uri" {
  value = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_test_script.key}"
}

output "glue_test_script_arn" {
  value = aws_s3_object.glue_test_script.arn
}

output "glue_test_script_etag" {
  value     = aws_s3_object.glue_test_script.etag
  sensitive = true
}

output "glue_role_name" {
  value = aws_iam_role.glue.name
}

output "glue_role_arn" {
  value = aws_iam_role.glue.arn
}

output "glue_job_name" {
  value = aws_glue_job.count_numbers.id
}

output "glue_job_arn" {
  value = aws_glue_job.count_numbers.arn
}
