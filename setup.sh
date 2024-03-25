#!/bin/bash
set -e

KUBECTL=kubectl

kind create cluster --name=issue-213
kubectx kind-issue-213

kubectl create namespace upbound-system

helm install uxp --namespace upbound-system upbound-stable/universal-crossplane --version 1.15.0-up.1 --wait
kubectl -n upbound-system wait deploy crossplane --for condition=Available --timeout=60s

cat <<EOF | "${KUBECTL}" apply -f -
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.4.0
EOF

cat <<EOF | "${KUBECTL}" apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.17.0
  runtimeConfigRef:
    apiVersion: pkg.crossplane.io/v1beta1
    kind: DeploymentRuntimeConfig
    name: provider-helm
EOF

cat <<EOF | "${KUBECTL}" apply -f -
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-helm
spec:
  serviceAccountTemplate:
    metadata:
      name: provider-helm
EOF

cat <<EOF | "${KUBECTL}" apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-helm-cluster-admin
subjects:
  - kind: ServiceAccount
    name: provider-helm
    namespace: upbound-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

sleep 10

cat <<EOF | "${KUBECTL}" apply -f -
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

"${KUBECTL}" apply -f apis/definition.yaml
"${KUBECTL}" apply -f apis/composition.yaml

sleep 30
"${KUBECTL}" apply -f claim.yaml