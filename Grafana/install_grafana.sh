#!/bin/bash

# Check if script is running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (with sudo)"
    exit 1
fi

# System update
echo "Updating system..."
apt-get update
apt-get upgrade -y

# Install required packages
echo "Installing required packages..."
apt-get install -y apt-transport-https software-properties-common wget

# Add Grafana repository
echo "Adding Grafana repository..."
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

# Update repository and install Grafana
echo "Installing Grafana..."
apt-get update
apt-get install -y grafana

# Ensure configuration is under /etc
echo "Ensuring configuration is under /etc..."
mkdir -p /etc/grafana
if [ ! -d "/etc/grafana" ]; then
    echo "Error: Could not create or find directory /etc/grafana"
    exit 1
fi

# Create directories
mkdir -p /etc/grafana/data
mkdir -p /etc/grafana/logs
mkdir -p /etc/grafana/plugins
mkdir -p /etc/grafana/provisioning

# Backup and modify existing configuration file
if [ -f "/etc/grafana/grafana.ini" ]; then
    cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.bak
    # Adjust paths in configuration file
    sed -i 's|^;\?data = .*$|data = /etc/grafana/data|g' /etc/grafana/grafana.ini
    sed -i 's|^;\?logs = .*$|logs = /etc/grafana/logs|g' /etc/grafana/grafana.ini
    sed -i 's|^;\?plugins = .*$|plugins = /etc/grafana/plugins|g' /etc/grafana/grafana.ini
    sed -i 's|^;\?provisioning = .*$|provisioning = /etc/grafana/provisioning|g' /etc/grafana/grafana.ini
else
    # If no configuration file exists, create one with paths
    cat > /etc/grafana/grafana.ini << EOF
[paths]
data = /etc/grafana/data
logs = /etc/grafana/logs
plugins = /etc/grafana/plugins
provisioning = /etc/grafana/provisioning
EOF
fi

# Set permissions
chown -R grafana:grafana /etc/grafana

# Start and enable Grafana service
echo "Starting Grafana service..."
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server

# Add firewall rule (if UFW is active)
if command -v ufw >/dev/null 2>&1; then
    echo "Opening port 3000 in firewall..."
    ufw allow 3000/tcp
fi

# Status check
echo "Checking Grafana status..."
systemctl status grafana-server

echo "
==============================================
Installation complete!

Important Information:
----------------------
1. Grafana is now accessible at http://your-server-ip:3000
2. Default login credentials:
   Username: admin
   Password: admin
   (You will be prompted to change the password on first login)
3. Grafana configuration is located at /etc/grafana

Next Steps:
----------------
1. Open Grafana in your browser
2. Add Prometheus as a data source:
   - Go to Configuration → Data Sources
   - Select 'Add data source'
   - Choose Prometheus
   - URL: http://localhost:9090 (or your Prometheus URL)

3. Import Dashboard:
   - Go to Create → Import
   - Enter Dashboard ID 1860 (Node Exporter Full)
   - Select your Prometheus data source
   - Click Import

Troubleshooting:
--------------
- If service fails to start: 
  sudo journalctl -u grafana-server.service
- Log files are located at: 
  /etc/grafana/logs/grafana.log
==============================================
" 