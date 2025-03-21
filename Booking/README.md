# Booking-System für Computer-Reservierungen

Dieses System ermöglicht die Verwaltung und Buchung von Computern über eine Weboberfläche. Es besteht aus einer PHP-Webseite mit Kalenderansicht und einer Python-Flask-API für die Datenbankoperationen.

## Deployment-Anleitung

### Voraussetzungen

- Linux-Server (getestet auf Ubuntu/Debian)
- Root-Zugriff oder sudo-Berechtigung
- Internetverbindung für die Installation von Paketen

### Installation

1. **Vorbereitung:**
   - Kopieren Sie den gesamten Booking-Ordner auf das Zielsystem
   - Stellen Sie sicher, dass das Deployment-Skript ausführbar ist:
     ```
     chmod +x deploy_booking.sh
     ```

2. **Ausführung des Deployment-Skripts:**
   - Führen Sie das Skript als Root aus:
     ```
     sudo ./deploy_booking.sh
     ```
   - Das Skript installiert alle notwendigen Abhängigkeiten und richtet die Komponente ein
   - Am Ende des Skripts werden wichtige Informationen angezeigt (Datenbank-Zugangsdaten, URLs)

3. **Nach der Installation:**
   - Die Booking-Webseite ist unter http://SERVER_IP/booking erreichbar
   - Die API läuft auf Port 5000 (http://SERVER_IP:5000)
   - Notieren Sie sich die Datenbank-Zugangsdaten für zukünftige Wartungsarbeiten

### Integration mit Grafana

Um die Booking-Seite in Ihr Grafana-Dashboard zu integrieren:

1. Öffnen Sie Ihr Grafana-Dashboard
2. Fügen Sie ein Text-Panel hinzu
3. Aktivieren Sie die Markdown-Formatierung
4. Fügen Sie folgenden Link ein:
   ```
   [Rechner buchen](http://SERVER_IP/booking)
   ```
   (Ersetzen Sie SERVER_IP durch die IP-Adresse Ihres Servers)

## Funktionen des Booking-Systems

- Kalenderansicht mit Buchungsübersicht
- Auswahl verfügbarer Computer
- Buchung für bestimmte Zeiträume
- Anzeige von Buchungsdetails
- Vermeidung von Buchungskonflikten

## Fehlerbehebung

Bei Problemen können Sie folgende Logs überprüfen:

- **API-Logs:** `journalctl -u booking-api.service`
- **Apache-Logs:** `/var/log/apache2/booking-error.log`
- **Datenbank-Verbindung testen:** `mysql -u bookinguser -p computer_booking`

## Systemkomponenten

Das Deployment-Skript richtet folgende Komponenten ein:

- Webserver (Apache)
- PHP für die Webseite
- Python-Flask für die API
- MySQL-Datenbank mit Beispieldaten
- Systemd-Service für die API

## Sicherheitshinweise

- Das Skript generiert ein zufälliges Passwort für den Datenbankbenutzer
- Für Produktivumgebungen empfehlen wir zusätzliche Sicherheitsmaßnahmen wie HTTPS
- Ändern Sie die Standardeinstellungen für erhöhte Sicherheit 