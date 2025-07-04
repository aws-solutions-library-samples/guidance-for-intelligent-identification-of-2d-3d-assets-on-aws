locals {
  # AWS region to operate in
  region = "us-east-2"

  # Customize if needed
  subnet_ids = data.aws_subnets.default.ids

  # Local variable containing the subdirectories containing the Lambda functions to package
  # Note that order matters as each position is processed differently in the lambdas.tf file
  subdirectories = [
    "handleLabels", 
    "processImage", 
    "processObject"
    ]
  
  s3_creation_events = [
    "s3:ObjectCreated:Put", 
    "s3:ObjectCreated:Post", 
    "s3:ObjectCreated:CompleteMultipartUpload"
    ]

  logging_permissions = [
    "logs:CreateLogGroup", 
    "logs:CreateLogStream", 
    "logs:PutLogEvents"
    ]

  process_s3_permissions = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:CopyObject",
          "s3:GetObjectAttributes",
          "s3:PutObjectMetadata",
          "s3:GetObjectTagging"
        ]

  # Random common suffix to apply to resources
  random_suffix = "${random_string.bucket_suffix.result}" 

  # S3 bucket to store images to be processed
  image_store_bucket_name = "image-store-bucket-${local.random_suffix}"

  # S3 bucket to store signed/unsigned Lambda code
  lambda_code_bucket_name = "lambda-code-bucket-${local.random_suffix}"

  # Concurrent execution limits for Lambdas
  # Choose the limit based on expected usage to prevent the functions from consuming all available concurrent executions in your account
  handle_labels_concurrent_exec = 50
  process_image_concurrent_exec = 50
  process_object_concurrent_exec = 50

  # DynamoDB table name
  dynamodb_table_name = "LabelMetadata-${local.random_suffix}"

  # DynamoDB table hash key
  dynamodb_table_hash_key = "LabelId"

  # Lambda runtime
  lambda_runtime = "nodejs22.x"
}

# Create ZIP files for each Lambda function
data "archive_file" "lambda_zip_files" {
  count = length(local.subdirectories)
  type = "zip"
  source_dir = "../${local.subdirectories[count.index]}"
  output_path = "../${local.subdirectories[count.index]}/${local.subdirectories[count.index]}.zip"
}

# Generate a random string
resource "random_string" "bucket_suffix" {
  length = 8
  special = false
  upper = false
}

# Data sources to get current AWS region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_route_tables" "selected" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# ┌─────────────────────────────────────────────────────────────────┐
# │   Adding guidance solution ID via AWS CloudFormation resource   │
# └─────────────────────────────────────────────────────────────────┘
resource "aws_cloudformation_stack" "this" {
    name = "tracking-stack"
    template_body = <<STACK
    {
        "AWSTemplateFormatVersion": "2010-09-09",
        "Description": "Guidance For AIML-powered 2D 3D Asset Identification And Management (SO9411)",
        "Resources": {
            "EmptyResource": {
                "Type": "AWS::CloudFormation::WaitConditionHandle"
            }
        }
    }
    STACK
}