resource "aws_kms_key" "s3_kms_key" {
  description              = "Key for ${var.audit_event_lamda_bucket_name} state"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  is_enabled               = "true"
  enable_key_rotation      = "true"
  policy                   = data.aws_iam_policy_document.s3_kms_key_document.json
  deletion_window_in_days  = 30

  tags = {
    Name = "${var.audit_event_lamda_bucket_name} s3 bucket key"
  }
}

resource "aws_kms_alias" "s3_kms_key_alias" {
  name          = "alias/${var.audit_event_lamda_bucket_name}"
  target_key_id = aws_kms_key.s3_kms_key.id
}

data "aws_iam_policy_document" "s3_kms_key_document" {
    statement {
        sid       = "Enable IAM User Permissions"
        effect    = "Allow"
        actions   = ["kms:*"]
        resources = ["*"]

        principals {
        type        = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
        }
    }

    statement {
        sid       = "Allow access for Key Administrators"
        effect    = "Allow"
        actions   = ["kms:*"]
        resources = ["*"]

        principals {
        type = "AWS"
        identifiers = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role}",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/support.amazonaws.com/AWSServiceRoleForSupport",
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/trustedadvisor.amazonaws.com/AWSServiceRoleForTrustedAdvisor"
        ]
        }
    }
}

data "aws_iam_policy_document" "s3-bucket-policy-document" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.b1.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role}"]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.b1.arn]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role}"]
    }
  }

  statement {
    actions   = ["s3:PutObjectTagging", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectAcl"]
    resources = ["${aws_s3_bucket.b1.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.account_role}"]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket-policy" {
    bucket = aws_s3_bucket.b1.id
    policy = data.aws_iam_policy_document.s3-bucket-policy-document.json
}
