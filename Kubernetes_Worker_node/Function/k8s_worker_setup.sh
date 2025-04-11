#!/bin/bash

#########################################################################################
# 											#
# Script Name   : k8s_worker_setup.sh							#
# Description   : Prepares a Linux node to join a Kubernetes cluster as a worker node.	#
#                 Performs OS configuration, installs containerd runtime, and 		#
#                 Kubernetes components (kubelet, kubeadm, kubectl).			#
# Author        : Vivekanandh K								#
# Created Date  : 2025-04-11								#
# Modified Date : 2025-04-11								#
# Version       : 1.0.0									#
# Usage         : sudo ./k8s_worker_setup.sh						#
# Arguments     : None									#
# Requirements  :									#
#   - Ubuntu 20.04+ / Debian 10+							#
#   - Internet connection								#
#   - Must be run with root or sudo privileges						#
# Exit Codes    :									#
#   0 => Success									#
#   1 => General failure								#
# Notes         :									#
#   - After running this script, use the `kubeadm join` command from the master node	#
#     to join this worker node to the cluster.						#
# 											#
#########################################################################################


set -euo pipefail

# ------------------------ CONFIGURATION ------------------------
MASTER_IP="Server_IP"
TOKEN="<Token>"
DISCOVERY_HASH="sha256:****************************************************"
# ----------------------------------------------------------------

log() {
    echo -e "\n  $1"
}

# ========================== Step 1: OS Prerequisites ==========================

setup_os_prereqs() {
    log "STEP 1: OS Configuration (Disabling swap & setting kernel params)..."

    swapoff -a
    sed -i '/swap/d' /etc/fstab

    cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
    modprobe br_netfilter

    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
    sysctl --system

    log "✅ STEP 1 complete."
}

# ========================== Step 2: Install containerd ==========================

install_containerd() {
    log "STEP 2: Installing containerd runtime..."

    apt update
    apt install -y containerd

    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    systemctl restart containerd
    systemctl enable containerd

    log "✅ STEP 2 complete."
}

# ========================== Step 3: Install Kubernetes tools ==========================

install_k8s_tools() {
    log "STEP 3: Installing Kubernetes tools..."

    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg

    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
        tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    systemctl enable --now kubelet

    log "✅ STEP 3 complete. Kubernetes prerequisites are installed."
}

# ========================== Step 4: Reset Node ==========================

reset_worker_node() {
    log "🚨 Resetting Kubernetes configuration on this node..."
    kubeadm reset -f

    log "🧹 Cleaning up leftover Kubernetes directories..."
    rm -rf /etc/cni/net.d /etc/kubernetes /var/lib/etcd /var/lib/kubelet /var/lib/cni/

    log "🔁 Restarting containerd and kubelet services..."
    systemctl restart containerd
    systemctl restart kubelet
}

# ========================== Step 5: Join Cluster ==========================

join_cluster() {
    log "🔗 Rejoining the Kubernetes cluster..."
    if kubeadm join "${MASTER_IP}:6443" --token "${TOKEN}" --discovery-token-ca-cert-hash "${DISCOVERY_HASH}"; then
        log "✅ Successfully joined the cluster!"
    else
        echo "❌ Failed to join the cluster. Please check the error above."
        exit 1
    fi
}

# ========================== MAIN EXECUTION ==========================

main() {
    case "${1:-}" in
        setup-os)
            setup_os_prereqs
            ;;
        install-containerd)
            install_containerd
            ;;
        install-k8s)
            install_k8s_tools
            ;;
        reset)
            reset_worker_node
            ;;
        join)
            join_cluster
            ;;
        all)
            setup_os_prereqs
            install_containerd
            install_k8s_tools
            ;;
        reset-and-join)
            reset_worker_node
            join_cluster
            ;;
        *)
            echo "Usage: $0 {setup-os|install-containerd|install-k8s|reset|join|all|reset-and-join}"
            exit 1
            ;;
    esac
}

main "$@"

