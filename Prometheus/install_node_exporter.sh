#!/bin/bash

# Prüfen ob Script als root läuft
if [ "$EUID" -ne 0 ]; then 
    echo "Bitte als root ausführen (sudo)"
    exit 1
fi

# Variablen definieren
VERSION="1.6.1"
DOWNLOAD_URL="https://github.com/prometheus/node_exporter/releases/download/v${VERSION}/node_exporter-${VERSION}.linux-amd64.tar.gz"
TEMP_DIR="/tmp/node_exporter"

# Benutzer erstellen
echo "Erstelle node_exporter Benutzer..."
useradd --no-create-home --shell /bin/false node_exporter

# Temporäres Verzeichnis erstellen und hinein wechseln
mkdir -p $TEMP_DIR
cd $TEMP_DIR

# Node Exporter herunterladen
echo "Lade Node Exporter herunter..."
wget $DOWNLOAD_URL

# Entpacken
echo "Entpacke Node Exporter..."
tar xvfz node_exporter-${VERSION}.linux-amd64.tar.gz

# Binary verschieben
echo "Installiere Node Exporter..."
mv node_exporter-${VERSION}.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Systemd Service erstellen
echo "Erstelle Systemd Service..."
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Aufräumen
echo "Räume temporäre Dateien auf..."
cd /
rm -rf $TEMP_DIR

# Service aktivieren und starten
echo "Aktiviere und starte Node Exporter Service..."
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

echo "Installation abgeschlossen!"
echo "Status überprüfen mit: systemctl status node_exporter" 