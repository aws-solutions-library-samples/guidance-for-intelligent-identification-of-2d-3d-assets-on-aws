# Image Store Bucket
resource "aws_s3_bucket" "image_store_bucket" {
  bucket = local.image_store_bucket_name
}

# Ensure public access is blocked for logging bucket
resource "aws_s3_bucket_public_access_block" "image_store_public_access_block" {
  bucket = aws_s3_bucket.image_store_bucket.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
