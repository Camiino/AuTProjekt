#! /usr/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (sudo)"
    exit 1
fi

VERSION_NODE="1.9.0"
VERSION_NVIDIA="1.1.0"
TEMP_DIR="/tmp/install"
EXPORTER_USER="prometheus"
EXPORTER_GROUP="prometheus"

# Systembenutzer und -gruppe erstellen
echo "Creating system user and group for exporters"
if ! getent group $EXPORTER_GROUP > /dev/null; then
    groupadd --system $EXPORTER_GROUP
fi

if ! getent passwd $EXPORTER_USER > /dev/null; then
    useradd --system --no-create-home --shell /bin/false --gid $EXPORTER_GROUP $EXPORTER_USER
fi

# NVIDIA-Unterstützung hinzufügen
echo "Configuring NVIDIA support for exporter user"
# Füge den Benutzer zur video-Gruppe hinzu (für GPU-Zugriff)
usermod -a -G video $EXPORTER_USER

# Erstelle udev-Regel für NVIDIA-Geräte
cat > /etc/udev/rules.d/99-nvidia-exporter.rules << EOF
# NVIDIA GPU-Geräte für prometheus-Benutzer zugänglich machen
SUBSYSTEM=="nvidia", OWNER="root", GROUP="video", MODE="0666"
EOF

# Lade udev-Regeln neu
udevadm control --reload-rules
udevadm trigger

mkdir -p $TEMP_DIR
cd $TEMP_DIR

echo "Downloading node-exporter, nvidia-node-exporter and exporter-merger"

wget https://github.com/prometheus/node_exporter/releases/download/v${VERSION_NODE}/node_exporter-${VERSION_NODE}.linux-amd64.tar.gz
wget https://github.com/utkuozdemir/nvidia_gpu_exporter/releases/download/v${VERSION_NVIDIA}/nvidia_gpu_exporter_${VERSION_NVIDIA}_linux_x86_64.tar.gz
wget https://github.com/rebuy-de/exporter-merger/releases/download/v0.4.0/exporter-merger-v0.4.0.dirty-linux-amd64

echo "Extracting downloaded binaries"
tar xvfz node_exporter-${VERSION_NODE}.linux-amd64.tar.gz
tar xvfz nvidia_gpu_exporter_${VERSION_NVIDIA}_linux_x86_64.tar.gz

echo "Installing binaries"

mkdir -p /opt/node_exporter/
mkdir -p /opt/nvidia_gpu_exporter
mkdir -p /opt/exporter_merger

mv node_exporter-${VERSION_NODE}.linux-amd64/node_exporter /opt/node_exporter/
mv nvidia_gpu_exporter /opt/nvidia_gpu_exporter/
mv exporter-merger-v0.4.0.dirty-linux-amd64 /opt/exporter_merger/

# Berechtigungen setzen
chown -R $EXPORTER_USER:$EXPORTER_GROUP /opt/node_exporter/
chown -R $EXPORTER_USER:$EXPORTER_GROUP /opt/nvidia_gpu_exporter/
chown -R $EXPORTER_USER:$EXPORTER_GROUP /opt/exporter_merger/

# Ausführungsrechte für Binärdateien sicherstellen
chmod +x /opt/node_exporter/node_exporter
chmod +x /opt/nvidia_gpu_exporter/nvidia_gpu_exporter
chmod +x /opt/exporter_merger/exporter-merger-v0.4.0.dirty-linux-amd64

echo "Generating system service files"

cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=$EXPORTER_USER
Group=$EXPORTER_GROUP
ExecStart=/opt/node_exporter/node_exporter --collector.netdev.address-info

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/nvidia_gpu_exporter.service << EOF
[Unit]
Description=NVIDIA Gpu Exporter
After=network.target

[Service]
Type=simple
User=$EXPORTER_USER
Group=$EXPORTER_GROUP
# Umgebungsvariablen für NVIDIA-Zugriff
Environment="NVIDIA_VISIBLE_DEVICES=all"
Environment="NVIDIA_DRIVER_CAPABILITIES=all"
ExecStart=/opt/nvidia_gpu_exporter/nvidia_gpu_exporter

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/exporter_merger.service << EOF
[Unit]
Description=Exporter Merger
After=network.target

[Service]
Type=simple
User=$EXPORTER_USER
Group=$EXPORTER_GROUP
ExecStart=/opt/exporter_merger/exporter-merger-v0.4.0.dirty-linux-amd64 --config-path /opt/exporter_merger/merger.yaml

[Install]
WantedBy=multi-user.target
EOF

cat > /opt/exporter_merger/merger.yaml << EOF
exporters:
- url: http://localhost:9100/metrics
- url: http://localhost:9835/metrics
EOF

echo "Cleaning temporary files"
cd $HOME
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
