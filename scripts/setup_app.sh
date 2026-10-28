#!/bin/bash
set -e

# Update and install Nginx
sudo apt update -y
sudo apt install nginx -y

# Format secondary EBS device if unformatted
if ! sudo blkid /dev/nvme1n1; then
  sudo mkfs.ext4 /dev/nvme1n1
fi

# Create mount directory and mount disk
sudo mkdir -p /production_data
sudo mount /dev/nvme1n1 /production_data

# Create symlink for Nginx to serve persistent data
sudo ln -sf /production_data/orders.txt /var/www/html/orders.txt

# Start and enable Nginx service
sudo systemctl enable nginx
sudo systemctl restart nginx
