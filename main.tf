provider "aws" {
  region = "eu-north-1"
}

# IAM ROLE
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role-fresh-v2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# LAMBDA
resource "aws_lambda_function" "notes" {
  function_name = "notes-api-v2"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.9"

  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")
}

# API GATEWAY
resource "aws_apigatewayv2_api" "api" {
  name          = "notes-api"
  protocol_type = "HTTP"
}

# INTEGRATION (IMPORTANT FIX INCLUDED)
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.notes.invoke_arn
  payload_format_version = "2.0"
}

# ROUTES
resource "aws_apigatewayv2_route" "post_notes" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /notes"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_route" "get_notes" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /notes"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# STAGE
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# LAMBDA PERMISSION
resource "aws_lambda_permission" "api" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notes.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# OUTPUT
output "api_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

resource "aws_dynamodb_table" "notes" {
  name         = "notes-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_iam_role_policy" "dynamo_policy" {
  name = "lambda-dynamo-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "dynamodb:PutItem",
        "dynamodb:Scan"
      ],
      Resource = aws_dynamodb_table.notes.arn
    }]
  })
}