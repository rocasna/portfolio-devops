#!/bin/bash
set -e

LOG_FILE="/startup-script.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Startup script iniciado: $(date) ==="

echo "--- Actualizando índice de paquetes ---"
if apt-get update; then
  echo "[OK] apt-get update: $(date)"
else
  echo "[ERROR] apt-get update falló: $(date)"
  exit 1
fi

echo "--- Instalando cliente MySQL ---"
if apt-get install -y default-mysql-client; then
  echo "[OK] Cliente MySQL instalado: $(date)"
else
  echo "[ERROR] Fallo instalando cliente MySQL: $(date)"
  exit 1
fi

echo "--- Instalando Docker ---"
if apt-get install -y docker.io; then
  echo "[OK] Docker instalado: $(date)"
else
  echo "[ERROR] Fallo instalando Docker: $(date)"
  exit 1
fi

if systemctl enable docker && systemctl start docker; then
  echo "[OK] Docker arrancado: $(date)"
else
  echo "[ERROR] Fallo arrancando Docker: $(date)"
  exit 1
fi

echo "--- Lanzando contenedor Flask ---"
if docker run -d \
  --name portfolio-backend \
  --restart unless-stopped \
  -p 80:5000 \
  rcastro95/portfolio-backend:v4; then
  echo "[OK] Contenedor Flask lanzado: $(date)"
else
  echo "[ERROR] Fallo lanzando contenedor Flask: $(date)"
  exit 1
fi

echo "--- Instalando Cloud SQL Auth Proxy ---"
if curl -o /usr/local/bin/cloud-sql-proxy \
  https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.0/cloud-sql-proxy.linux.amd64; then
  chmod +x /usr/local/bin/cloud-sql-proxy
  echo "[OK] Cloud SQL Auth Proxy descargado: $(date)"
else
  echo "[ERROR] Fallo descargando Cloud SQL Auth Proxy: $(date)"
  exit 1
fi

echo "--- Configurando servicio systemd para el proxy ---"
cat > /etc/systemd/system/cloud-sql-proxy.service <<'EOF'
[Unit]
Description=Cloud SQL Auth Proxy
After=network.target

[Service]
ExecStart=/usr/local/bin/cloud-sql-proxy --auto-iam-authn --private-ip fase-a-504618:europe-west1:dev-terraform-module-db
Restart=always
RestartSec=5
User=root
StandardOutput=append:/var/log/cloud-sql-proxy.log
StandardError=append:/var/log/cloud-sql-proxy.log

[Install]
WantedBy=multi-user.target
EOF

if systemctl daemon-reload && systemctl enable cloud-sql-proxy && systemctl start cloud-sql-proxy; then
  echo "[OK] Servicio cloud-sql-proxy arrancado: $(date)"
else
  echo "[ERROR] Fallo arrancando cloud-sql-proxy: $(date)"
  exit 1
fi
#
echo "CICD: $(date)" >> /log-cicd.log

echo "=== Startup script finalizado con éxito: $(date) ==="