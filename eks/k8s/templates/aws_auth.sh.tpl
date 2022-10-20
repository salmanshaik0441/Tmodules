#!/bin/bash

set -ex

aws eks update-kubeconfig --region "${region}" --name "${cluster_name}" --alias "${context_alias}"
if [ "${eks_masters_in_private_range}" = "true" ]; then
  CLUSTER_ARN=$(aws eks describe-cluster --name=${cluster_name} | grep arn | head -n1 | cut -d':' -f2- | tr -d '", ')
  kubectl config set-cluster $CLUSTER_ARN --server=https://${master_balancer_server}:443
fi
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapAccounts: |
      []
  mapRoles: |
    - "groups":
      - "system:bootstrappers"
      - "system:nodes"
      "rolearn": "${worker-instances}"
      "username": "system:node:{{EC2PrivateDNSName}}"
    - "groups":
      - "system:masters"
      "rolearn": "${admin-role}"
      "username": "admin"
    - "groups":
      - "system:masters"
      "rolearn": "${role-cicd-cross-account-arn}"
      "username": "admin"      
    - "groups":
      - "${devops-group}"
      "rolearn": "${devops-role}"
      "username": "devopsuser"
    - "groups":
      - "${dev-group}"
      "rolearn": "${dev-role}"
      "username": "developeruser"
  mapUsers: |
    - "groups":
      - "system:masters"
      "userarn": "${cicd-role}"
      "username": "admin"
EOF
