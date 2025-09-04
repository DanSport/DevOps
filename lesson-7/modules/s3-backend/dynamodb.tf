resource "aws_dynamodb_table" "locks" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge({ Name = var.table_name, Purpose = "terraform-locks" }, var.tags)
}
