resource "aws_s3_bucket" "app_s3_bucket" {
  bucket = "${var.bucket_name}"
  # acl    = "private"

  # server_side_encryption_configuration {
  #   rule {
  #     apply_server_side_encryption_by_default {
  #       sse_algorithm     = "AES256"
  #     }
  #   }
  # }

  tags = {
    Name = "${var.project_prefix}-S3-AppUI-StaticResources-Bucket"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.app_s3_bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
    bucket_key_enabled = true
  }
}

data "aws_iam_policy_document" "app_s3_bucket_bucket_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.app_s3_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn, var.cicd_userarn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role}"]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.app_s3_bucket.arn]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn, var.cicd_userarn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role}"]
    }
  }

  statement {
    actions   = ["s3:PutObjectTagging", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectAcl"]
    resources = ["${aws_s3_bucket.app_s3_bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [var.cicd_userarn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role}"]
    }
  }
}

resource "aws_s3_bucket_policy" "app_bucket_policy" {
    bucket = aws_s3_bucket.app_s3_bucket.id
    policy = data.aws_iam_policy_document.app_s3_bucket_bucket_policy.json
}