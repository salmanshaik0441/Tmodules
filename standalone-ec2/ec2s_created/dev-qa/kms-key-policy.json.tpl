{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow access for Key Administrators",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${account_id}:role/aws-service-role/trustedadvisor.amazonaws.com/AWSServiceRoleForTrustedAdvisor",
                    "arn:aws:iam::${account_id}:role/${account_role}",
                    "arn:aws:iam::${account_id}:role/aws-service-role/support.amazonaws.com/AWSServiceRoleForSupport"
                ]
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow use of the key",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${account_id}:role/${account_role}",
                    "arn:aws:iam::${account_id}:role/aws-service-role/support.amazonaws.com/AWSServiceRoleForSupport",
                    "arn:aws:iam::${account_id}:role/aws-service-role/trustedadvisor.amazonaws.com/AWSServiceRoleForTrustedAdvisor",
                    "arn:aws:iam::${account_id}:role/${application_role}"
                ]
            },
            "Action": [
                "kms:ReEncrypt*",
                "kms:GenerateDataKey*",
                "kms:Encrypt",
                "kms:DescribeKey",
                "kms:Decrypt"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow attachment of persistent resources",
            "Effect": "Allow",
            "Principal": {
                "AWS": [
                    "arn:aws:iam::${account_id}:role/${account_role}",
                    "arn:aws:iam::${account_id}:role/aws-service-role/support.amazonaws.com/AWSServiceRoleForSupport",
                    "arn:aws:iam::${account_id}:role/aws-service-role/trustedadvisor.amazonaws.com/AWSServiceRoleForTrustedAdvisor",
                    "arn:aws:iam::${account_id}:role/${application_role}"
                ]
            },
            "Action": [
                "kms:RevokeGrant",
                "kms:ListGrants",
                "kms:CreateGrant"
            ],
            "Resource": "*",
            "Condition": {
                "Bool": {
                    "kms:GrantIsForAWSResource": "true"
                }
            }
        }
    ]
}