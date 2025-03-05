#! /usr/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Bitte als root ausführen (sudo)"
    exit 1
fi

VERSION_NODE="1.9.0"
VERSION_NVIDIA="1.1.0"
TEMP_DIR="/tmp/install"

mkdir -p $TEMP_DIR
cd $TEMP_DIR

echo "Downloading node-exporter, nvidia-node-exporter and exporter-merger"

wget https://github.com/prometheus/node_exporter/releases/download/v${VERSION_NODE}/node_exporter-${VERSION_NODE}.linux-amd64.tar.gz
wget https://github.com/utkuozdemir/nvidia_gpu_exporter/releases/download/v${VERSION_NVIDIA}/nvidia_gpu_exporter_${VERSION_NVIDIA}_linux_x86_64.tar.gz
wget https://github.com/rebuy-de/exporter-merger/releases/download/v0.4.0/exporter-merger-v0.4.0.dirty-linux-amd64

mkdir $TEMP_DIR
cd $TEMP_DIR

echo "Extracting downloaded binaries"
tar xvfz node_exporter-${VERSION_NODE}.linux-amd64.tar.gz
tar nvidia_gpu_exporter_${VERSION_NVIDIA}_linux_x86_64.tar.gz

echo "Installing binaries"
mv node_exporter-${VERSION_NODE}.linux-amd64/node_exporter /etc
mv nvidia_gpu_exporter /etc
mv exporter-merger-v0.4.0.dirty-linux-amd64 /etc

echo "Generating system service files"

cat > /etc/systemd/system/node_exporter.service << EOF
[UNIT]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=/etc/node_exporter

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/nvidia_gpu_exporter.service << EOF
[UNIT]
Description=NVIDIA Gpu Exporter
After=network.target

[Service]
Type=simple
ExecStart=/etc/nvidia_gpu_exporter

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/exporter_merger.service << EOF
[UNIT]
Description=Exporter Merger
After=network.target

[Service]
Type=simple
ExecStart=/etc/exporter-merger-v0.4.0.dirty-linux-amd64

[Install]
WantedBy=multi-user.target
EOF

echo "Cleaning temporary files"
cd /
rm -rf $TEMP_DIR

echo "Starting Services"
systemctl daemon-reload
systemctl enable node_exporter
systemctl enable nvidia_gpu_exporter
systemctl enable exporter_merger
systemctl start node_exporter
systemctl start nvidia_gpu_exporter
systemctl start exporter_merger


echo "Finished Setup, run systemctl status <service> to check status"
