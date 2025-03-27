# AuTProjekt
# Anlegen eines neuen PCs in der Überwachung
1) installation der Node-Exporter auf neuen Rechner:
    ```
   $ wget https://raw.githubusercontent.com/Camiino/AuTProjekt/refs/heads/main/Prometheus/exporter_setup_system_user.sh
   $ sudo chmod +x exporter_setup_system_user.sh
   $ sudo ./exporter_setup_system_user.sh
   ```
2) Ermitteln der MAC-Addresses:
   ```
   $ ifconfig
   ```
3) Festlegung des gewünschten PC-Namens:
   Anlegung eines neuen Jobs in Prometheus.yml unter scrape_configs:
   ```
   - job_name: "<name>"
    file_sd_configs:
    - files:
      - "/opt/prometheus/<name>.json"
    relabel_configs:
     - source_labels: [__adress__]
       target_label: instance
       replacement: "<name>"
   ```
   Hinzufügen der MAC-Addresse und des Namens in der Liste bekannter Hostnames in dynamic_ips.py:
   ```
   hostnames = {<MAC-ADDRESS>:<NAME>}
   ```
4) Aktualisierung der entsprechenden Dienste:
   ```
   $ sudo systemctl daemon-reload
   $ sudo systemctl restart prometheus.service
   $ sudo systemctl restart dynamic_ips.service
   ```


  
