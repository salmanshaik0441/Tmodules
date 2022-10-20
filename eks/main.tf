terraform {
  required_version = ">= 0.13.5"

  required_providers {
    aws = ">= 3.48.0"
  }
}

provider "aws" {
  region  = var.aws_region
  # profile = var.aws_profile
  default_tags {
    tags = var.cluster_tags
  }
}

provider "aws" {
  alias       = "ami"
  region      = var.aws_region
  assume_role {
    role_arn  = "arn:aws:iam::971731176829:role/AMI_ID_Role"
  }
}

data "aws_eks_cluster" "eks_cluster" {
  name        = aws_eks_cluster.eks_cluster.id
}

data "aws_iam_policy_document" "cluster_elb_sl_role_creation" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeAddresses"
    ]
    resources = ["*"]
  }
}

resource "aws_cloudwatch_log_group" "cluster_log_group" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30
}

resource "aws_eks_cluster" "eks_cluster" {
  name                      = var.cluster_name
  enabled_cluster_log_types = var.kube_logs_to_enable
  role_arn                  = var.use_default_roles ? module.roles[0].aws_iam_role_cluster_arn : var.cluster_role_arn
  version                   = "${var.k8s_version.major}.${var.k8s_version.minor}"

  vpc_config {
    security_group_ids      = compact([aws_security_group.cluster_sg.id])
    subnet_ids              = var.subnets
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  timeouts {
    create = "30m"
    delete = "15m"
  }

  depends_on = [
    aws_security_group_rule.cluster_egress_internet,
    aws_security_group_rule.cluster_https_worker_ingress,
    aws_cloudwatch_log_group.cluster_log_group
  ]
}

resource "local_file" "aws_auth" {
  count                 = var.use_default_aws_auth ? 1 : 0
  depends_on            = [aws_eks_addon.aws_node, aws_eks_cluster.eks_cluster, local_file.secondary_cidr_script]
  content = templatefile("${path.module}/k8s/templates/aws_auth.sh.tpl", {
    region              = var.aws_region
    cluster_name        = var.cluster_name
    context_alias       = var.kubeconfig_name
    worker-instances    = var.use_default_roles ? module.roles[0].role_workers_profile.arn : var.worker_role_arn
    admin-role          = var.role-admin-arn
    devops-role         = var.role-devops-arn
    devops-group        = var.group-devops-name
    dev-role            = var.role-developer-arn
    dev-group           = var.group-developer-name
    cicd-role           = var.role-cicd-arn
    eks_masters_in_private_range = var.eks_masters_in_private_range
    master_balancer_server = length(aws_lb.eks_master_alb) > 0 ? aws_lb.eks_master_alb[0].dns_name : ""
    role-cicd-cross-account-arn = var.role-cicd-cross-account-arn
  })
  filename              = "${path.module}/k8s/temp/aws_auth.sh"

  provisioner "local-exec" {
    command             = "sh ${local_file.aws_auth[0].filename}"
  }

}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc.0.issuer
  tags            = { Name = "${var.cluster_name}-eks-irsa" }
}

############# Adding crossplane if requested
module "install_crossplane" {
  count                 = var.install_crossplane ? 1 : 0
  source                = "./modules/crossplane"
  oidc_provider_arn     = aws_iam_openid_connect_provider.oidc_provider.arn
  oidc_issue_url        = data.aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  cluster_name_prefix   = var.cluster_name_prefix
  cluster_name          = var.cluster_name
  cluster_id            = data.aws_eks_cluster.eks_cluster.id
  depends_on            = [aws_eks_cluster.eks_cluster]
  cluster_tags          = var.cluster_tags
}

############# AWS Roles
module "roles" {
  count                 = var.use_default_roles ? 1 : 0
  source                = "./modules/roles"
  s3_setup_bucket       = var.s3_setup_bucket
  aws_region            = var.aws_region
  cluster_name          = var.cluster_name
  cluster_name_prefix   = var.cluster_name_prefix
  elb_sl_role_policy    = data.aws_iam_policy_document.cluster_elb_sl_role_creation.json
}

###

resource "aws_eks_identity_provider_config" "dex_oidc_provider" {
  count = var.dex_oidc_provider.is_online_in_cluster == true ? 1 : 0

  cluster_name = aws_eks_cluster.eks_cluster.name

  oidc {
    client_id                     = var.dex_oidc_provider.client_id
    identity_provider_config_name = var.dex_oidc_provider.identity_provider_config_name
    issuer_url                    = var.dex_oidc_provider.issuer_url
    username_claim                = "name"
    groups_claim                  = "groups"
  }
}
