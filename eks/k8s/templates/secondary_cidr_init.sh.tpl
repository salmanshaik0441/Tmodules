#!/bin/bash

set -ex

aws eks update-kubeconfig --region ${region} --name ${cluster_name} --alias ${context_alias}
if [ "${eks_masters_in_private_range}" = "true" ]; then
  CLUSTER_ARN=$(aws eks describe-cluster --name=${cluster_name} | grep arn | head -n1 | cut -d':' -f2- | tr -d '", ')
  kubectl config set-cluster $CLUSTER_ARN --server=https://${master_balancer_server}:443
fi

cat <<EOF | kubectl apply -f -
---
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: ${az-name-1}
spec:
  securityGroups:
    - ${worker-node-sg-id}
  subnet: ${subnet-az1-id}
---
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
  name: ${az-name-2}
spec:
  securityGroups:
    - ${worker-node-sg-id}
  subnet: ${subnet-az2-id}
EOF

#if [ ! -z "${az-name-2}" ];
#then
#    cat <<EOF | kubectl apply --insecure-skip-tls-verify -f -
#    ---
#    apiVersion: crd.k8s.amazonaws.com/v1alpha1
#    kind: ENIConfig
#    metadata:
#      name: ${az-name-2}
#    spec:
#      securityGroups:
#        - ${worker-node-sg-id}
#      subnet: ${subnet-az2-id}
#EOF
#fi

kubectl set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
kubectl set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=failure-domain.beta.kubernetes.io/zone
kubectl rollout restart daemonset aws-node -n kube-system
