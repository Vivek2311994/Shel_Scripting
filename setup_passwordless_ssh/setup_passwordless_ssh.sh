###Project : Shell script to install sshpass in redhat & ubuntu VM then enable the passwordless authentication from master server to other servers. 
#Author: Vivekanandh K


#!/bin/bash

# Usage: ./setup_passwordless_ssh.sh <username> <password>
# Server list must be in "servers.txt" in the same directory.

USER=$1
PASSWORD=$2

if [ -z "$USER" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

SERVER_FILE="servers.txt"

if [ ! -f "$SERVER_FILE" ]; then
    echo "File '$SERVER_FILE' not found!"
    exit 1
fi

# Function: Install sshpass
install_sshpass() {
    echo "Installing sshpass..."

    if [ -f /etc/redhat-release ]; then
        sudo yum install -y epel-release
        sudo yum install -y sshpass
    elif [ -f /etc/debian_version ]; then
        sudo apt update
        sudo apt install -y sshpass
    else
        echo "Unsupported OS. Please install sshpass manually."
        exit 1
    fi

    if ! command -v sshpass >/dev/null 2>&1; then
        echo "sshpass installation failed."
        exit 1
    fi

    echo "sshpass installed successfully."
}

# Function: Generate SSH key if not present
generate_ssh_key() {
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo "Generating SSH key..."
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    else
        echo "SSH key already exists."
    fi
}

# Function: Set up passwordless SSH using for loop
setup_passwordless_ssh() {
    echo "🚀 Starting password-less SSH setup..."

    for SERVER in $(cat "$SERVER_FILE"); do
        echo "Setting up SSH key for $USER@$SERVER..."
        sshpass -p "$PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no "$USER@$SERVER"

        if [ $? -eq 0 ]; then
            echo "Password-less SSH configured for $SERVER"
        else
            echo "Failed to copy key to $SERVER"
        fi
    done
}

# Main Execution
install_sshpass
generate_ssh_key
setup_passwordless_ssh
