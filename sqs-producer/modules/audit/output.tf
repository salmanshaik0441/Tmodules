output "sqs_push_queues" {
  value = "${aws_sqs_queue.db_audit_queue.name}, ${aws_sqs_queue.es_audit_queue.name}"
}
