#!/usr/bin/env bash
###############################################################################
# Nginx en reverse-proxy HTTPS (certificat auto-signé) devant Open WebUI.
#
# Fragment partagé par les cibles « vraie VM » (AWS EC2, Exoscale) : le service
# Open WebUI écoute en HTTP sur 127.0.0.1:PROXY_PORT, Nginx termine le TLS.
#
# Variables d'environnement :
#   PROXY_PORT   port HTTP local d'Open WebUI (défaut 3000)
###############################################################################
set -eu

PROXY_PORT="${PROXY_PORT:-3000}"

apt-get install -y nginx openssl

# --- Certificat auto-signé ---
mkdir -p /etc/nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/ssl/selfsigned.key \
  -out /etc/nginx/ssl/selfsigned.crt \
  -subj "/CN=openwebui.local"

# --- Vhost HTTPS + redirection 80 -> 443 ---
cat > /etc/nginx/sites-available/openwebui <<EOF_NGINX
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate     /etc/nginx/ssl/selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

    location / {
        proxy_pass http://127.0.0.1:${PROXY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}
EOF_NGINX

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/openwebui /etc/nginx/sites-enabled/openwebui

systemctl restart nginx
