#!/bin/bash
echo "Resetting kubeadm..."
kubeadm reset -f
rm -rf /etc/kubernetes/manifests /var/lib/etcd ~/.kube
systemctl restart containerd
echo "✅ Reset complete. Now run the init script."

