#!/bin/bash

# Prüfen ob Script als root läuft
if [ "$EUID" -ne 0 ]; then 
    echo "Bitte als root ausführen (sudo)"
    exit 1
fi

# Variablen definieren
VERSION="3.2.1"
DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v${VERSION}/prometheus-${VERSION}.linux-amd64.tar.gz"
PROMETHEUS_HOME="/ect/prometheus"
TEMP_DIR="/tmp/prometheus"

# Benutzer erstellen
echo "Erstelle prometheus Benutzer..."
useradd --no-create-home --shell /bin/false prometheus

# Verzeichnisse erstellen
echo "Erstelle Verzeichnisse..."
mkdir -p $PROMETHEUS_HOME
mkdir -p $PROMETHEUS_HOME/data
mkdir -p $TEMP_DIR

# Prometheus herunterladen und entpacken
echo "Lade Prometheus herunter..."
cd $TEMP_DIR
wget $DOWNLOAD_URL
tar xvfz prometheus-${VERSION}.linux-amd64.tar.gz

# Dateien verschieben
echo "Installiere Prometheus..."
cp prometheus-${VERSION}.linux-amd64/prometheus $PROMETHEUS_HOME/
cp prometheus-${VERSION}.linux-amd64/promtool $PROMETHEUS_HOME/
cp -r prometheus-${VERSION}.linux-amd64/consoles $PROMETHEUS_HOME/
cp -r prometheus-${VERSION}.linux-amd64/console_libraries $PROMETHEUS_HOME/

# Basis-Konfiguration erstellen
echo "Erstelle Prometheus Konfiguration..."
cat > $PROMETHEUS_HOME/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'local-server'
EOF

# Berechtigungen setzen
echo "Setze Berechtigungen..."
chown -R prometheus:prometheus $PROMETHEUS_HOME

# Systemd Service erstellen
echo "Erstelle Systemd Service..."
cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/opt/prometheus/prometheus \
    --config.file=/opt/prometheus/prometheus.yml \
    --storage.tsdb.path=/opt/prometheus/data \
    --web.console.templates=/opt/prometheus/consoles \
    --web.console.libraries=/opt/prometheus/console_libraries
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Aufräumen
echo "Räume temporäre Dateien auf..."
cd /
rm -rf $TEMP_DIR

# Service aktivieren und starten
echo "Aktiviere und starte Prometheus Service..."
systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

echo "Installation abgeschlossen!"
echo "Status überprüfen mit: systemctl status prometheus"
echo "Prometheus UI ist erreichbar unter: http://localhost:9090" 