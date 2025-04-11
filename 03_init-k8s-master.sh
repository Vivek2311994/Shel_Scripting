#!/bin/bash

set -e

echo "🚀 Initializing Kubernetes control plane..."

# Initialize the Kubernetes cluster with the specified pod network CIDR
kubeadm init --pod-network-cidr=192.168.0.0/16

echo "✅ Kubernetes control plane initialized."

echo "🔧 Setting up kubeconfig for the current user..."
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

echo "🌐 Installing Calico CNI plugin..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/calico.yaml

echo "✅ Master setup complete!"
echo "ℹ️ To join worker nodes, run the join command from above or regenerate with:"
echo "   kubeadm token create --print-join-command"

