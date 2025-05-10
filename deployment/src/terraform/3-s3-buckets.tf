# ┌──────────────────┐
# │   Image Bucket   │
# └──────────────────┘

# Image Store Bucket
resource "aws_s3_bucket" "image_store_bucket" {
  bucket = local.image_store_bucket_name
}

# Ensure public access is blocked for image store bucket
resource "aws_s3_bucket_public_access_block" "image_store_public_access_block" {
  bucket = aws_s3_bucket.image_store_bucket.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Enable versioning for the bucket
resource "aws_s3_bucket_versioning" "image_store_versioning" {
  bucket = aws_s3_bucket.image_store_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ┌─────────────────┐
# │   Code Bucket   │
# └─────────────────┘

# Lambda Code Bucket
resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = local.lambda_code_bucket_name
}

# Ensure public access is blocked for lambda code bucket
resource "aws_s3_bucket_public_access_block" "lambda_code_public_access_block" {
  bucket = aws_s3_bucket.lambda_code_bucket.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# Enable versioning for the bucket
resource "aws_s3_bucket_versioning" "lambda_code_versioning" {
  bucket = aws_s3_bucket.lambda_code_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Upload generated Lambda zip files to S3 bucket
resource "aws_s3_object" "lambda_zip_s3_objects" {
  count = length(local.subdirectories)
  bucket = aws_s3_bucket.lambda_code_bucket.id
  key = "${local.subdirectories[count.index]}.zip"
  source = data.archive_file.lambda_zip_files[count.index].output_path
  etag = filemd5(data.archive_file.lambda_zip_files[count.index].output_path)

  depends_on = [ 
    aws_s3_bucket.lambda_code_bucket,
    aws_s3_bucket_versioning.lambda_code_versioning 
  ]
}