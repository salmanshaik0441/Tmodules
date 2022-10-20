# This mount is for the cluster to mount to the EFS so that multiple EKS clusters can access a shared EFS
resource "aws_efs_mount_target" "alpha" {
  count             = length(var.efs_subnets)
  file_system_id    = var.efs_file_system_id
  subnet_id         = length(var.efs_subnets) > 0 ? var.efs_subnets[count.index] : var.subnets[count.index]
  security_groups   = [aws_security_group.cluster_sg.id, aws_security_group.eks_worker_sg.id]
}
