#!/bin/bash

# -------------------------------
# Script: reset-and-join-worker.sh
# Purpose: Reset a Kubernetes Worker Node & Rejoin the Cluster
# Usage: sudo ./reset-and-join-worker.sh
# -------------------------------

# Customize these values based on your cluster's kubeadm join command:
MASTER_IP="192.168.1.6"
TOKEN="gs1yhs.wbhcdwe47ekh6pga"
DISCOVERY_HASH="sha256:6e71335dbfa154028f2c9360ce0c0bb0718702e92bdf476f928ac3595ce752c3"

echo "🚨 Resetting Kubernetes configuration on this node..."
sudo kubeadm reset -f

echo "🧹 Cleaning up leftover Kubernetes directories..."
sudo rm -rf /etc/cni/net.d \
            /etc/kubernetes \
            /var/lib/etcd \
            /var/lib/kubelet \
            /var/lib/cni/

echo "🔁 Restarting containerd and kubelet services..."
sudo systemctl restart containerd
sudo systemctl restart kubelet

echo "🔗 Rejoining the Kubernetes cluster..."
sudo kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash ${DISCOVERY_HASH}

if [ $? -eq 0 ]; then
    echo "✅ Successfully joined the cluster!"
else
    echo "❌ Failed to join the cluster. Please check the error above."
fi

