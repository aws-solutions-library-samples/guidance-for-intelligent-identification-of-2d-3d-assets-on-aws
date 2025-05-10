# ┌───────────────┐
# │   Endpoints   │
# └───────────────┘

# DynamoDB VPC Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id = data.aws_vpc.default.id
  service_name = "com.amazonaws.${local.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids = data.aws_route_tables.selected.ids

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowDynamoDBAccess"
        Effect = "Allow"
        Principal = "*"
        Action = ["dynamodb:PutItem"]
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${local.dynamodb_table_name}"
        ]
      }
    ]
  })

  tags = {
    Name = "DynamoDB VPC Endpoint"
  }
}

# Rekognition VPC endpoint for Lambda functions
resource "aws_vpc_endpoint" "rekognition" {
  vpc_id = data.aws_vpc.default.id
  service_name = "com.amazonaws.${local.region}.rekognition"
  vpc_endpoint_type  = "Interface"
  
  security_group_ids = [aws_security_group.vpce_sg.id]
  subnet_ids = data.aws_subnets.default.ids

  private_dns_enabled = true
}

# Security group for the Rekognition VPC endpoint
resource "aws_security_group" "vpce_sg" {
  name = "rekognition-vpce-sg"
  description = "Security group for Rekognition VPC endpoint"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"

    # Allow access from Lambda security group
    security_groups = [aws_security_group.lambda_sg.id] 
  }
}

# S3 VPC endpoint for Lambda functions
resource "aws_vpc_endpoint" "s3" {
  vpc_id = data.aws_vpc.default.id
  service_name = "com.amazonaws.${local.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = data.aws_route_tables.selected.ids
}

# Associate the S3 endpoint with the route table
resource "aws_vpc_endpoint_route_table_association" "s3_endpoint" {
  route_table_id  = data.aws_vpc.default.main_route_table_id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

# Security group for Lambda functions
resource "aws_security_group" "lambda_sg" {
  name = "lambda_sg"
  description = "Security group for Lambda functions"
  vpc_id = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress rules here if needed

  lifecycle {
    create_before_destroy = true
  }
}

# ┌──────────────────┐
# │   Code Signing   │
# └──────────────────┘

# Signing Profile
resource "aws_signer_signing_profile" "lambda_signing_profile" {
  platform_id = "AWSLambda-SHA384-ECDSA"
  name_prefix = "lambda_signing_profile"
}

# Signing Config
resource "aws_lambda_code_signing_config" "lambda_code_signing" {
  description = "Code signing configuration for Lambda functions"
  
  allowed_publishers {
    #signing_profile_version_arns = [aws_signer_signing_profile.lambda_signing_profile.arn]
    signing_profile_version_arns = [aws_signer_signing_profile.lambda_signing_profile.version_arn]
  }

  policies {
    untrusted_artifact_on_deployment = "Enforce"
  }
}

# Sign Lambda code
resource "aws_signer_signing_job" "sign_lambda" {
  count = length(local.subdirectories)
  profile_name = aws_signer_signing_profile.lambda_signing_profile.name
  
  source {
    s3 {
      bucket = aws_s3_bucket.lambda_code_bucket.id
      key = aws_s3_object.lambda_zip_s3_objects[count.index].key
      version = aws_s3_object.lambda_zip_s3_objects[count.index].version_id
    }
  }
  destination {
    s3 {
      bucket = aws_s3_bucket.lambda_code_bucket.id
      prefix = "signed-${local.subdirectories[count.index]}-"
    }
  }

  depends_on = [ 
    aws_s3_object.lambda_zip_s3_objects 
  ]
}

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
        Action = ["s3:ListBucket", "s3:GetObject", "s3:GetObjectAttributes", "s3:GetObjectTagging"]
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

# Policy attachment for VPC access for handleLabels Lambda function
resource "aws_iam_role_policy_attachment" "handle_labels_lambda_vpc_access" {
  role = aws_iam_role.handle_labels_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Create handleLabels Lambda function
resource "aws_lambda_function" "handle_labels_lambda_function" {
  function_name = local.subdirectories[0]
  role = aws_iam_role.handle_labels_role.arn
  handler = "index.handler"
  runtime = local.lambda_runtime
  memory_size = 128
  timeout = 60
  reserved_concurrent_executions = local.handle_labels_concurrent_exec
  code_signing_config_arn = aws_lambda_code_signing_config.lambda_code_signing.arn

  s3_bucket = aws_s3_bucket.lambda_code_bucket.id
  s3_key = aws_signer_signing_job.sign_lambda[0].signed_object[0].s3[0].key

  vpc_config {
    subnet_ids = local.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }

  environment {
    variables = {
      LABEL_DATA_TABLE = local.dynamodb_table_name
    }
  }

  depends_on = [
    aws_vpc_endpoint.s3,
    aws_signer_signing_job.sign_lambda
  ]
}

# ┌───────────────────┐
# │   Process Image   │
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

# Policy attachment for VPC access for processImage Lambda function
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role = aws_iam_role.process_image_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Create processImage Lambda function
resource "aws_lambda_function" "process_image_lambda_function" {
  function_name = local.subdirectories[1]
  role = aws_iam_role.process_image_role.arn
  handler = "index.handler"
  source_code_hash = data.archive_file.lambda_zip_files[1].output_base64sha256
  runtime = local.lambda_runtime
  memory_size = 128
  timeout = 60
  reserved_concurrent_executions = local.process_image_concurrent_exec
  code_signing_config_arn = aws_lambda_code_signing_config.lambda_code_signing.arn

  s3_bucket = aws_s3_bucket.lambda_code_bucket.id
  s3_key = aws_signer_signing_job.sign_lambda[1].signed_object[0].s3[0].key

  vpc_config {
    subnet_ids = local.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }

  environment {
    variables = {
      IMAGE_STORE_BUCKET = aws_s3_bucket.image_store_bucket.id
    }
  }

  depends_on = [
    aws_vpc_endpoint.s3,
    aws_signer_signing_job.sign_lambda
  ]
}

# Lambda permission for S3 to invoke processImage function
resource "aws_lambda_permission" "process_image_s3_permission" {
  statement_id = "AllowS3Invoke"
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

# Policy attachment for VPC access for processObject Lambda function
resource "aws_iam_role_policy_attachment" "process_object_lambda_vpc_access" {
  role = aws_iam_role.process_object_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Create processObject Lambda function
resource "aws_lambda_function" "process_object_lambda_function" {
  function_name = local.subdirectories[2]
  role = aws_iam_role.process_object_role.arn
  handler = "index.handler"
  source_code_hash = data.archive_file.lambda_zip_files[2].output_base64sha256
  runtime = local.lambda_runtime
  memory_size = 128
  timeout = 60
  reserved_concurrent_executions = local.process_object_concurrent_exec
  code_signing_config_arn = aws_lambda_code_signing_config.lambda_code_signing.arn

  s3_bucket = aws_s3_bucket.lambda_code_bucket.id
  s3_key = aws_signer_signing_job.sign_lambda[2].signed_object[0].s3[0].key

  vpc_config {
    subnet_ids = local.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  lifecycle {
    create_before_destroy = true
  }

  environment {
    variables = {
      IMAGE_STORE_BUCKET = aws_s3_bucket.image_store_bucket.id
      LABEL_DATA_TABLE = local.dynamodb_table_name
    }
  }

  depends_on = [
    aws_vpc_endpoint.s3,
    aws_signer_signing_job.sign_lambda
  ]
}