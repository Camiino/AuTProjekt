# AuTProjekt
# Anlegen eines neuen PCs in der überwachung
1) installation der Node-Exporter:
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


  
