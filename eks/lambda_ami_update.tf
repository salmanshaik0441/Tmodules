locals {
  lambda_name = "${var.cluster_name}-codebuild-ami-update"
}

data "aws_caller_identity" "current" {}

data "archive_file" "trigger_codebuild" {
  count       = var.code_pipeline != "" ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/functions/update_ami.py"
  output_path = "${path.module}/functions/update_ami.zip"
}

resource "aws_cloudwatch_log_group" "ami_update" {
  count             = var.code_pipeline != "" ? 1 : 0
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 3
}

resource "aws_iam_role" "lambda_role" {
  count = var.code_pipeline != "" ? 1 : 0
  name  = "${var.cluster_name}-codebuild-ami-update-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lamda_role_policy_read" {
  count = var.code_pipeline != "" ? 1 : 0
  name  = "${var.cluster_name}-codebuild-ami-update-role-policy"
  role  = aws_iam_role.lambda_role[0].id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Resource": "arn:aws:iam::019523953090:role/${var.cross_account_role}"
      },
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Resource": "arn:aws:iam::971731176829:role/AMI_ID_Role"
      },
      {
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": [
            "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lambda_name}:*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeLaunchTemplateVersions"
        ],
        "Resource": [
            "*"
        ]
      }
    ]
  }
  EOF
}


resource "aws_lambda_function" "check_for_new_ami" {
  count    = var.code_pipeline != "" ? 1 : 0
  filename = data.archive_file.trigger_codebuild[0].output_path

  function_name    = local.lambda_name
  handler          = "update_ami.lambda_handler"
  role             = aws_iam_role.lambda_role[0].arn
  runtime          = "python3.8"
  timeout          = 60
  source_code_hash = data.archive_file.trigger_codebuild[0].output_base64sha256
  depends_on       = [aws_launch_template.asg_lt]

  description = "Triggers codebuild for ${var.cluster_name} cluster when new AMI is released"

  environment {
    variables = {
      CLUSTER_AWS_REGION  = var.aws_region
      LAUNCH_TEMPLATE_IDS = join(",", [for asg_lt in aws_launch_template.asg_lt : asg_lt.id])
      CROSS_ACCOUNT_ID    = var.cross_account_id
      CROSS_ACCOUNT_ROLE  = var.cross_account_role
      STS_EXTERNAL_ID     = var.sts_external_id
      PIPELINE_TO_EXECUTE = var.code_pipeline
      AMI_ROLE_ARN        = var.ami_arn_role
      AMI_TYPE            = var.latest-ami ? "latestAMI" : "PreviousAMI"
      K8_VERSION          = var.k8s_version.minor
    }
  }

}

resource "aws_cloudwatch_event_rule" "ami_update_rule" {
  count               = var.code_pipeline != "" ? 1 : 0
  name                = "${var.cluster_name}-new-AMI-Checker"
  description         = "Checking for new AMI releases for ${var.cluster_name} k8 cluster so as to trigger codebuild"
  schedule_expression = var.check_for_new_ami_cron
}

resource "aws_cloudwatch_event_target" "check_for_new_ami" {
  count = var.code_pipeline != "" ? 1 : 0
  rule  = aws_cloudwatch_event_rule.ami_update_rule[0].id
  arn   = aws_lambda_function.check_for_new_ami[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_events" {
  count         = var.code_pipeline != "" ? 1 : 0
  statement_id  = "AllowCloudWatchEventsInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.check_for_new_ami[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ami_update_rule[0].arn
}
