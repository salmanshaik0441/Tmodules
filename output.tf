output "audit_event_rds_username" {
    value = jsondecode(aws_secretsmanager_secret_version.audits_secret.secret_string)["username"]
}

output "audit_event_rds_password" {
    sensitive = true
    value = jsondecode(aws_secretsmanager_secret_version.audits_secret.secret_string)["password"]
}

output "audit_event_connection_string" {
    value = "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${aws_db_instance.audits_oracle_primary.address})(PORT=${aws_db_instance.audits_oracle_primary.port}))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=${aws_db_instance.audits_oracle_primary.name})))"
}

output "business_event_rds_username" {
    value = var.combine_audit_and_be_databases ? jsondecode(aws_secretsmanager_secret_version.audits_secret.secret_string)["username"] : jsondecode(aws_secretsmanager_secret_version.business_events_secret[0].secret_string)["username"]
}

output "business_event_rds_password" {
    sensitive = true
    value = var.combine_audit_and_be_databases ? jsondecode(aws_secretsmanager_secret_version.audits_secret.secret_string)["password"] : jsondecode(aws_secretsmanager_secret_version.business_events_secret[0].secret_string)["password"]
}

output "business_event_connection_string" {
    value = var.combine_audit_and_be_databases ? "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${aws_db_instance.audits_oracle_primary.address})(PORT=${aws_db_instance.audits_oracle_primary.port}))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=${aws_db_instance.audits_oracle_primary.name})))" : "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${aws_db_instance.business_events_oracle_primary[0].address})(PORT=${aws_db_instance.business_events_oracle_primary[0].port}))(CONNECT_DATA=(SERVER=DEDICATED)(SERVICE_NAME=${aws_db_instance.business_events_oracle_primary[0].name})))"
}