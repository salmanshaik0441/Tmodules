#!/bin/bash

set -ex

cat <<EOF | kubectl apply -f -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations: {}
  name: system:node-drainer
rules:
- apiGroups:
  - ''
  resources:
  - pods/eviction
  verbs:
  - create
- apiGroups:
  - ''
  resources:
  - pods
  verbs:
  - get
  - list
- apiGroups:
  - ''
  resources:
  - nodes
  verbs:
  - get
  - patch
- apiGroups:
  - apps
  resources:
  - statefulsets
  - daemonsets
  verbs:
  - get
  - list
- apiGroups:
  - extensions
  resources:
  - daemonsets
  - replicasets
  verbs:
  - get
  - list

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations: {}
  labels:
    eks.amazonaws.com/component: node
  name: system:node-drainer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:node-drainer
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:nodes
EOF