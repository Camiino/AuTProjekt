#!/bin/bash

# Prüfen, ob das Skript als Root ausgeführt wird
if [ "$EUID" -ne 0 ]; then 
    echo "Bitte als Root ausführen (mit sudo)"
    exit 1
fi

# Systemaktualisierung
echo "System wird aktualisiert..."
apt-get update
apt-get upgrade -y

# Installation der benötigten Pakete
echo "Installiere benötigte Pakete..."
apt-get install -y apt-transport-https software-properties-common wget

# Grafana Repository hinzufügen
echo "Füge Grafana Repository hinzu..."
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list

# Repository aktualisieren und Grafana installieren
echo "Installiere Grafana..."
apt-get update
apt-get install -y grafana

# Sicherstellen, dass die Konfiguration unter /etc liegt
echo "Stelle sicher, dass die Konfiguration unter /etc liegt..."
mkdir -p /etc/grafana
if [ ! -d "/etc/grafana" ]; then
    echo "Fehler: Konnte Verzeichnis /etc/grafana nicht erstellen oder finden."
    exit 1
fi

# Konfigurationsdatei anpassen, um sicherzustellen, dass alle Daten unter /etc gespeichert werden
cat > /etc/grafana/grafana.ini << EOF
[paths]
data = /etc/grafana/data
logs = /etc/grafana/logs
plugins = /etc/grafana/plugins
provisioning = /etc/grafana/provisioning
EOF

# Verzeichnisse erstellen
mkdir -p /etc/grafana/data
mkdir -p /etc/grafana/logs
mkdir -p /etc/grafana/plugins
mkdir -p /etc/grafana/provisioning

# Berechtigungen setzen
chown -R grafana:grafana /etc/grafana

# Grafana Service starten und aktivieren
echo "Starte Grafana Service..."
systemctl daemon-reload
systemctl start grafana-server
systemctl enable grafana-server

# Firewall-Regel hinzufügen (wenn UFW aktiv ist)
if command -v ufw >/dev/null 2>&1; then
    echo "Öffne Port 3000 in der Firewall..."
    ufw allow 3000/tcp
fi

# Statusüberprüfung
echo "Überprüfe Grafana Status..."
systemctl status grafana-server

echo "
==============================================
Installation abgeschlossen!

Wichtige Informationen:
----------------------
1. Grafana ist nun unter http://ihre-server-ip:3000 erreichbar
2. Standard Login-Daten:
   Benutzer: admin
   Passwort: admin
   (Sie werden beim ersten Login aufgefordert, das Passwort zu ändern)
3. Grafana-Konfiguration befindet sich unter /etc/grafana

Nächste Schritte:
----------------
1. Öffnen Sie Grafana im Browser
2. Fügen Sie Prometheus als Datenquelle hinzu:
   - Gehen Sie zu Configuration → Data Sources
   - Wählen Sie 'Add data source'
   - Wählen Sie Prometheus
   - URL: http://localhost:9090 (oder Ihre Prometheus-URL)

3. Dashboard importieren:
   - Gehen Sie zu Create → Import
   - Geben Sie die Dashboard-ID 1860 ein (Node Exporter Full)
   - Wählen Sie Ihre Prometheus-Datenquelle
   - Klicken Sie auf Import

Troubleshooting:
--------------
- Wenn der Service nicht startet: 
  sudo journalctl -u grafana-server.service
- Log-Dateien befinden sich in: 
  /etc/grafana/logs/grafana.log
==============================================
" 