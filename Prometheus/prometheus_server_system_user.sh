#!/bin/bash

# Check if script is running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi

# Define variables
VERSION="3.2.1"
DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v${VERSION}/prometheus-${VERSION}.linux-amd64.tar.gz"
PROMETHEUS_HOME="/etc/prometheus"
TEMP_DIR="/tmp/prometheus"

# Create user
echo "Creating prometheus user..."
useradd --no-create-home --shell /bin/false prometheus

# Create directories
echo "Creating directories..."
mkdir -p $PROMETHEUS_HOME
mkdir -p $PROMETHEUS_HOME/data
mkdir -p $TEMP_DIR

# Download and extract Prometheus
echo "Downloading Prometheus..."
cp prometheus.yml $PROMETHEUS_HOME/
cp node1.json $PROMETHEUS_HOME/
cp node2.json $PROMETHEUS_HOME/
cd $TEMP_DIR
wget $DOWNLOAD_URL
tar xvfz prometheus-${VERSION}.linux-amd64.tar.gz

# Move files
echo "Installing Prometheus..."
cp prometheus-${VERSION}.linux-amd64/prometheus $PROMETHEUS_HOME/
cp prometheus-${VERSION}.linux-amd64/promtool $PROMETHEUS_HOME/
cp -r prometheus-${VERSION}.linux-amd64/consoles $PROMETHEUS_HOME/
cp -r prometheus-${VERSION}.linux-amd64/console_libraries $PROMETHEUS_HOME/

# Create base configuration
# Set permissions
echo "Setting permissions..."
chown -R prometheus:prometheus $PROMETHEUS_HOME

# Create systemd service
echo "Creating Systemd Service..."
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/etc/prometheus/prometheus \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.path=/etc/prometheus/data \
    --storage.tsdb.retention.time=8w
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Cleanup
echo "Cleaning up temporary files..."
cd /
rm -rf $TEMP_DIR

# Enable and start service
echo "Enabling and starting Prometheus service..."
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

echo "Installation complete!"
echo "Check status with: systemctl status prometheus"
echo "Prometheus UI available at: http://localhost:9090"
