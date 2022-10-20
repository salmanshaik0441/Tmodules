output "eks_efs_file_system_arn" {
  description = "The arn of the created EFS"
  value       = aws_efs_file_system.eks_efs_file_system.arn
}

output "eks_efs_file_system_id" {
  description = "EFS id"
  value       = aws_efs_file_system.eks_efs_file_system.id
}