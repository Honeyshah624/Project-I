#!/bin/bash
set -e
echo "==== Updating system ===="
sudo apt update -y && sudo apt upgrade -y
echo "==== Installing prerequisites ===="
sudo apt install -y wget curl tar
# -----------------------------
# Install Node Exporter
# -----------------------------
echo "==== Installing Node Exporter ===="
cd /tmp
NODE_EXPORTER_VERSION="1.8.2"
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo mv node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*
# Create service
sudo bash -c 'cat <<EOF >/etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target
[Service]
ExecStart=/usr/local/bin/node_exporter
Restart=always
User=nobody
[Install]
WantedBy=multi-user.target
EOF'
sudo systemctl daemon-reexec
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
# -----------------------------
# Install Prometheus
# -----------------------------

echo ">>> Downloading Prometheus..."
PROM_VERSION="2.55.1"
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROM_VERSION}.linux-amd64

echo ">>> Installing Prometheus..."
sudo useradd --no-create-home --shell /bin/false prometheus || true
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo cp prometheus promtool /usr/local/bin/
sudo cp -r consoles console_libraries /etc/prometheus
sudo cp prometheus.yml /etc/prometheus/prometheus.yml
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

echo ">>> Creating Prometheus systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

# ========= INSTALL ALERTMANAGER =========
echo ">>> Downloading Alertmanager..."
AM_VERSION="0.27.0"
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v${AM_VERSION}/alertmanager-${AM_VERSION}.linux-amd64.tar.gz
tar xvf alertmanager-${AM_VERSION}.linux-amd64.tar.gz
cd alertmanager-${AM_VERSION}.linux-amd64

echo ">>> Installing Alertmanager..."
sudo useradd --no-create-home --shell /bin/false alertmanager || true
sudo mkdir -p /etc/alertmanager /var/lib/alertmanager
sudo cp alertmanager amtool /usr/local/bin/
sudo cp alertmanager.yml /etc/alertmanager/alertmanager.yml
sudo chown -R alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager

echo ">>> Creating Alertmanager systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target
[Service]
User=alertmanager
Group=alertmanager
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager

[Install]
WantedBy=multi-user.target
EOF

# ========= START SERVICES =========
echo ">>> Reloading systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo ">>> Enabling and starting Prometheus & Alertmanager..."
sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl enable alertmanager
sudo systemctl start alertmanager

echo ">>> Checking status..."
systemctl status prometheus --no-pager
systemctl status alertmanager --no-pager

# -----------------------------
# Install Grafana
# -----------------------------
sudo apt-get install -y apt-transport-https software-properties-common wget
sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com beta main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
# Updates the list of available packages
sudo apt-get update
# Installs the latest OSS release:
sudo apt-get install grafana
sudo systemctl enable grafana-server.service
sudo systemctl start  grafana-server.service

echo "Installation Complete"





