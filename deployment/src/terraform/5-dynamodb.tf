resource "aws_dynamodb_table" "label_metadata_table" {
  name = local.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key = local.dynamodb_table_hash_key

  attribute {
    name = local.dynamodb_table_hash_key
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}