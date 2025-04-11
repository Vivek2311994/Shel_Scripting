#!/bin/bash


#########################################################################################
#                                                                                       #                                                        
#  Script Name   : k8s_master_setup.sh                                                  #                          
#  Description   : Prepares a system to act as the Kubernetes Control Plane node.  	#
#                 Performs OS tuning, installs containerd, and Kubernetes tools.        #      
#  Author        : Vivekanandh K                                                        #                                   
#  Created Date  : 2025-04-11                                                           #                                 
#  Modified Date : 2025-04-11								#
#  Version       : 1.0.0								#
#  Usage         : sudo ./k8s_master_setup.sh						#
#  Arguments     : None									#
#  Requirements  : 									#
#    - Ubuntu/Debian-based OS								#
#    - Internet connection								#
#    - Run as root or with sudo privileges						#
#  Exit Codes    :									#
#    0 => Success									#
#    1 => General failure								#
#											#  
#########################################################################################

#################################################
# Usage Examples:				#
#						#
# chmod +x k8s_master_setup.sh			#
#						#
# Run individual stages:			#
# ./k8s_master_setup.sh setup-os		#
# ./k8s_master_setup.sh install-containerd	#
# ./k8s_master_setup.sh install-k8s		#
# ./k8s_master_setup.sh init-master		#
# ./k8s_master_setup.sh reset			#
#             [OR]				#
#  run everything end-to-end:			#
# ./k8s_master_setup.sh all			#
#################################################




set -euo pipefail

# =========================== Utility Functions ===========================

log() {
    echo -e "\n👉 $1"
}

# =========================== Step 1: OS Pre-configuration ===========================

setup_os_basics() {
    log "Disabling swap..."
    swapoff -a
    sed -i '/swap/d' /etc/fstab

    log "Loading kernel modules..."
    cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
    modprobe br_netfilter

    log "Applying sysctl settings..."
    cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
    sysctl --system
}

# =========================== Step 2: Install Containerd ===========================

install_containerd() {
    log "Installing containerd..."
    apt update
    apt install -y containerd

    log "Configuring containerd..."
    mkdir -p /etc/containerd
    containerd config default | tee /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

    systemctl restart containerd
    systemctl enable containerd
}

# =========================== Step 3: Install Kubernetes Tools ===========================

install_k8s_tools() {
    log "Installing Kubernetes components..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg

    log "Adding Kubernetes signing key..."
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    log "Adding Kubernetes APT repo..."
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | \
        tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update
    apt-get install -y kubelet kubeadm kubectl
    apt-mark hold kubelet kubeadm kubectl

    log "Enabling kubelet..."
    systemctl enable --now kubelet
}

# =========================== Step 4: Init Kubernetes Master ===========================

init_k8s_master() {
    log "Initializing Kubernetes master..."
    kubeadm init --pod-network-cidr=192.168.0.0/16

    log "Setting up kubeconfig for current user..."
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config

    log "Installing Calico CNI plugin..."
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/calico.yaml

    log "Master setup complete!"
    echo "➡️ To join worker nodes, run:"
    kubeadm token create --print-join-command
}

# =========================== Step 5: Reset Kubernetes (if needed) ===========================

reset_k8s_node() {
    log "Resetting Kubernetes installation..."
    kubeadm reset -f
    rm -rf /etc/kubernetes/manifests /var/lib/etcd ~/.kube
    systemctl restart containerd
    log "Reset complete. You can now re-run the init function."
}

# =========================== Execution Control ===========================

main() {
    case "${1:-}" in
        setup-os)
            setup_os_basics
            ;;
        install-containerd)
            install_containerd
            ;;
        install-k8s)
            install_k8s_tools
            ;;
        init-master)
            init_k8s_master
            ;;
        reset)
            reset_k8s_node
            ;;
        all)
            setup_os_basics
            install_containerd
            install_k8s_tools
            init_k8s_master
            ;;
        *)
            echo "Usage: $0 {setup-os|install-containerd|install-k8s|init-master|reset|all}"
            exit 1
            ;;
    esac
}

main "$@"

