# ┌───────────────────┐
# │   Handle Labels   │
# └───────────────────┘

# IAM Role for handleLabels Lambda function
resource "aws_iam_role" "handle_labels_role" {
  name = "handle_labels_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for handleLabels Lambda function
resource "aws_iam_role_policy" "handle_labels_policy" {
  name = "handle_labels_lambda_policy"
  role = aws_iam_role.handle_labels_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.subdirectories[0]}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectAttributes", "s3:GetObjectTagging"]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.image_store_bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.image_store_bucket.id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.dynamodb_table_name}"
        ]
      }
    ]
  })
}

# Create handleLabels Lambda function
resource "aws_lambda_function" "handle_labels_lambda_function" {
  filename = data.archive_file.lambda_zip_files[0].output_path
  function_name = local.subdirectories[0]
  role = aws_iam_role.handle_labels_role.arn
  handler = "index.handler"
  source_code_hash = data.archive_file.lambda_zip_files[0].output_base64sha256
  runtime = "nodejs18.x"
  memory_size = 128
  timeout = 60

  environment {
    variables = {
      LABEL_DATA_TABLE = local.dynamodb_table_name
    }
  }
}

# ┌───────────────────┐
# │   Process Image	  │
# └───────────────────┘

# IAM Role for processImage Lambda function
resource "aws_iam_role" "process_image_role" {
  name = "process_image_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for processImage Lambda function
resource "aws_iam_role_policy" "process_image_policy" {
  name = "process_image_lambda_policy"
  role = aws_iam_role.process_image_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = local.logging_permissions
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.subdirectories[1]}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = local.process_s3_permissions
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.image_store_bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.image_store_bucket.id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rekognition:DetectLabels"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create processImage Lambda function
resource "aws_lambda_function" "process_image_lambda_function" {
  filename = data.archive_file.lambda_zip_files[1].output_path
  function_name = local.subdirectories[1]
  role = aws_iam_role.process_image_role.arn
  handler = "index.handler"
  source_code_hash = data.archive_file.lambda_zip_files[1].output_base64sha256
  runtime = "nodejs18.x"
  memory_size = 128
  timeout = 60

  environment {
    variables = {
      IMAGE_STORE_BUCKET = aws_s3_bucket.image_store_bucket.id
    }
  }
}

# Lambda permission for S3 to invoke processImage function
resource "aws_lambda_permission" "process_image_s3_permission" {
  statement_id  = "AllowS3Invoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_image_lambda_function.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.image_store_bucket.arn
}

# Lambda permission for S3 to invoke processObject function
resource "aws_lambda_permission" "process_object_s3_permission" {
  statement_id  = "AllowS3Invoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_object_lambda_function.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.image_store_bucket.arn
}

# Lambda permission for S3 to invoke handleLabels function
resource "aws_lambda_permission" "handle_labels_s3_permission" {
  statement_id  = "AllowS3Invoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.handle_labels_lambda_function.arn
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.image_store_bucket.arn
}

# S3 bucket notification configuration to react to events that will invoke either 
# processImage or handleLabels Lambda functions
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_store_bucket.id

  # For 3D objects
  lambda_function {
    lambda_function_arn = aws_lambda_function.process_object_lambda_function.arn
    events = local.s3_creation_events
    filter_suffix = ".fbx"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_object_lambda_function.arn
    events = local.s3_creation_events
    filter_suffix = ".obj"
  }

  # For images
  lambda_function {
    lambda_function_arn = aws_lambda_function.process_image_lambda_function.arn
    events = local.s3_creation_events
    filter_suffix = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_image_lambda_function.arn
    events = local.s3_creation_events
    filter_suffix = ".jpeg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_image_lambda_function.arn
    events = local.s3_creation_events
    filter_suffix = ".png"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_image_lambda_function.arn
    events = local.s3_creation_events
    filter_suffix = ".gif"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.handle_labels_lambda_function.arn
    events = ["s3:ObjectTagging:Put"]
  }

  depends_on = [
    aws_lambda_permission.process_image_s3_permission,
    aws_lambda_permission.handle_labels_s3_permission
    ]
}

# ┌────────────────────┐
# │   Process Object   │
# └────────────────────┘

# IAM Role for processObject Lambda function
resource "aws_iam_role" "process_object_role" {
  name = "process_object_lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for processObject Lambda function
resource "aws_iam_role_policy" "process_object_policy" {
  name = "process_object_lambda_policy"
  role = aws_iam_role.process_object_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = local.logging_permissions
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.subdirectories[2]}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = local.process_s3_permissions
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.image_store_bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.image_store_bucket.id}/*"
        ]
      }
    ]
  })
}

# Create processObject Lambda function
resource "aws_lambda_function" "process_object_lambda_function" {
  filename = data.archive_file.lambda_zip_files[2].output_path
  function_name = local.subdirectories[2]
  role = aws_iam_role.process_object_role.arn
  handler = "index.handler"
  source_code_hash = data.archive_file.lambda_zip_files[2].output_base64sha256
  runtime = "nodejs18.x"
  memory_size = 128
  timeout = 60

  environment {
    variables = {
      IMAGE_STORE_BUCKET = aws_s3_bucket.image_store_bucket.id
      LABEL_DATA_TABLE = local.dynamodb_table_name
    }
  }
}