### To set a hostname to all the servers from the master server

#!/bin/bash

# Usage: ./set_hostname_remotely.sh <username> <password>

USER=$1
PASSWORD=$2
HOSTNAME="hostname.txt"

if [ -z "$USER" ] || [ -z "$PASSWORD" ]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

if [ ! -f "$HOSTNAME" ]; then
    echo "File '$HOSTNAME' not found!"
    exit 1
fi

# Read all lines from hostmap.txt into an array
mapfile -t HOSTS < "$HOSTNAME"

# Loop using for
for server in "${HOSTS[@]}"; do
    # Skip empty lines or lines starting with #
    [[ -z "$server" || "$server" =~ ^# ]] && continue

    # Split line into IP and HOSTNAME
    SERVER_IP=$(echo "$server" | awk '{print $1}')
    NEW_HOSTNAME=$(echo "$server" | awk '{print $2}')

    echo "Connecting to $SERVER_IP to set hostname as '$NEW_HOSTNAME'..."

    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no "$USER@$SERVER_IP" "
        echo '$PASSWORD' | sudo -S hostnamectl set-hostname $NEW_HOSTNAME &&
        echo '$SERVER_IP $NEW_HOSTNAME' | sudo tee -a /etc/hosts &&
        echo 'Hostname set to $NEW_HOSTNAME on $SERVER_IP' "

    if [ $? -eq 0 ]; then
        echo "Successfully set hostname on $SERVER_IP"
    else
        echo "Failed to set hostname on $SERVER_IP"
    fi
done
