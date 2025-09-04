output "bucket_name" { value = aws_s3_bucket.tf_state.id }
output "bucket_arn" { value = aws_s3_bucket.tf_state.arn }
output "dynamodb_table_name" { value = aws_dynamodb_table.locks.name }
