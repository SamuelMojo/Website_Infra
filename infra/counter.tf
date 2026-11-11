# Serverless visitor counter: Lambda Function URL + DynamoDB atomic ADD.

resource "aws_dynamodb_table" "stats" {
  name         = "cloud-resume-stats"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

data "archive_file" "counter" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda/counter.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "counter" {
  name               = "portfolio-visitor-counter"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "counter_logs" {
  role       = aws_iam_role.counter.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "counter_table" {
  name = "update-visitor-count"
  role = aws_iam_role.counter.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:UpdateItem"]
      Resource = aws_dynamodb_table.stats.arn
    }]
  })
}

resource "aws_lambda_function" "counter" {
  function_name    = "portfolio-visitor-counter"
  role             = aws_iam_role.counter.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = data.archive_file.counter.output_path
  source_code_hash = data.archive_file.counter.output_base64sha256
  timeout          = 5
  memory_size      = 128

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.stats.name
      ALLOWED_ORIGIN = "https://${var.domain}"
    }
  }
}

# CORS is answered by the Function URL itself, so the handler only returns JSON.
resource "aws_lambda_function_url" "counter" {
  function_name      = aws_lambda_function.counter.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["https://${var.domain}", "https://www.${var.domain}"]
    allow_methods = ["GET"]
    max_age       = 3600
  }
}

# A public Function URL needs BOTH permissions, or callers get 403 Forbidden.
resource "aws_lambda_permission" "url_public" {
  statement_id           = "AllowPublicInvokeFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.counter.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "url_invoke" {
  statement_id  = "AllowPublicInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.counter.function_name
  principal     = "*"
}

output "visitor_counter_url" {
  description = "Put this in counter.js (COUNTER_URL)"
  value       = aws_lambda_function_url.counter.function_url
}
