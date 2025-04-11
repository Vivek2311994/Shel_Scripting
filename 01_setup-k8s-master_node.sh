#!/bin/bash

set -e

echo "🚀 Starting Kubernetes setup on $(hostname)..."

### STEP 1: Basic OS Configuration
echo "🔧 Disabling swap..."
swapoff -a
sed -i '/swap/d' /etc/fstab

echo "🔧 Loading kernel modules..."
cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

modprobe br_netfilter

echo "🔧 Applying sysctl settings..."
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

### STEP 2: Install Containerd
echo "📦 Installing containerd..."
apt update
apt install -y containerd

echo "⚙️  Configuring containerd..."
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

### STEP 3: Install Kubernetes tools
echo "📦 Installing Kubernetes tools..."

apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg

echo "🔑 Adding Kubernetes signing key..."
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "📦 Adding Kubernetes APT repo..."
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

echo "🔁 Enabling kubelet..."
systemctl enable --now kubelet

echo "✅ Base Kubernetes setup complete!"
echo "➡️ Run kubeadm init (master only) or join command (worker node) next."

