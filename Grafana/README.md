# Grafana Installation und Konfiguration

## Inhaltsverzeichnis
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
- [Erste Schritte nach der Installation](#erste-schritte-nach-der-installation)
- [Dashboard-Import](#dashboard-import)
- [Troubleshooting](#troubleshooting)
- [Nützliche Befehle](#nützliche-befehle)

## Voraussetzungen
- Ein Linux-System (Ubuntu/Debian empfohlen)
- Root-Zugriff oder sudo-Berechtigung
- Prometheus bereits installiert und laufend
- Node Exporter auf den zu überwachenden Systemen

## Installation

### Automatische Installation
1. Laden Sie das Installationsskript herunter:
   ```bash
   wget https://raw.githubusercontent.com/your-repo/install_grafana.sh
   ```
2. Machen Sie das Skript ausführbar:
   ```bash
   chmod +x install_grafana.sh
   ```
3. Führen Sie das Skript aus:
   ```bash
   sudo ./install_grafana.sh
   ```

## Erste Schritte nach der Installation
1. Öffnen Sie Grafana im Browser:
   - URL: `http://ihre-server-ip:3000`
2. Melden Sie sich mit den Standard-Login-Daten an:
   - Benutzer: `admin`
   - Passwort: `admin`
   - Sie werden aufgefordert, das Passwort beim ersten Login zu ändern.

## Dashboard-Import
1. Fügen Sie Prometheus als Datenquelle hinzu:
   - Gehen Sie zu `Configuration → Data Sources`
   - Wählen Sie `Add data source`
   - Wählen Sie `Prometheus`
   - URL: `http://localhost:9090` (oder Ihre Prometheus-URL)
2. Importieren Sie ein Dashboard:
   - Gehen Sie zu `Create → Import`
   - Geben Sie die Dashboard-ID `1860` ein (Node Exporter Full)
   - Wählen Sie Ihre Prometheus-Datenquelle
   - Klicken Sie auf `Import`

## Troubleshooting
- Wenn der Service nicht startet:
  ```bash
  sudo journalctl -u grafana-server.service
  ```
- Log-Dateien befinden sich in:
  ```bash
  /var/log/grafana/grafana.log
  ```

## Nützliche Befehle
- Grafana Service starten:
  ```bash
  sudo systemctl start grafana-server
  ```
- Grafana Service stoppen:
  ```bash
  sudo systemctl stop grafana-server
  ```
- Grafana Service neu starten:
  ```bash
  sudo systemctl restart grafana-server
  ```
- Grafana Service Status überprüfen:
  ```bash
  sudo systemctl status grafana-server
  ```