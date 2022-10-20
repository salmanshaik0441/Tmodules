
resource "aws_eks_addon" "coredns" {
  count             = var.coredns_version != "" ? 1 : 0
  cluster_name      = data.aws_eks_cluster.eks_cluster.name
  addon_name        = "coredns"
  addon_version     = var.coredns_version
  resolve_conflicts = "OVERWRITE"
  depends_on = [
    aws_eks_addon.aws_node
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  count             = var.kube_proxy_version != "" ? 1 : 0
  cluster_name      = data.aws_eks_cluster.eks_cluster.name
  addon_name        = "kube-proxy"
  addon_version     = var.kube_proxy_version
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "aws_node" {
  count             = var.vpc_cni_version != "" ? 1 : 0
  cluster_name      = data.aws_eks_cluster.eks_cluster.name
  addon_name        = "vpc-cni"
  addon_version     = var.vpc_cni_version
  resolve_conflicts = "OVERWRITE"
  #   According to aws documentation not specifying a service account role arn,
  #   means that the addon will use the role used by the ec2 where pod runs 
  #   service_account_role_arn = aws_iam_role.vpccni_role[0].arn

  depends_on = [
    aws_eks_addon.kube_proxy
  ]
}
