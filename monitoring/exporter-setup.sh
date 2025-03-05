#! /usr/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

wget https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-amd64.tar.gz
wget https://github.com/utkuozdemir/nvidia_gpu_exporter/releases/download/v1.1.0/nvidia_gpu_exporter_1.1.0_linux_x86_64.tar.gz
wget https://github.com/rebuy-de/exporter-merger/releases/download/v0.4.0/exporter-merger-v0.4.0.dirty-linux-amd64

tar xvfz $SCRIPT_DIR/node_exporter-1.9.0.linux-amd64.tar.gz
tar xvfz $SCRIPT_DIR/nvidia_gpu_exporter_1.1.0_linux_x86_64.tar.gz

rm -rf $SCRIPT_DIR/node_exporter-1.9.0.linux-amd64.tar.gz
rm -rf $SCRIPT_DIR/nvidia_gpu_exporter_1.1.0_linux_x86_64.tar.gz
