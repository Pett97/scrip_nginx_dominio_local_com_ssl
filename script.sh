#!/bin/bash

#Peterson Henrique de Padua
#Pett97


# atualizar lista pacote
apt update -y
echo -e "\033[32m lista de pacotes atualizados\033[0m"

# instalar certbot
apt install certbot python3-certbot-nginx -y
echo -e "\033[32m cerbot instalado \033[0m"

#instalar nano 
apt install nano -y

echo -e "\033[32m editor de texto nano instalado \033[0m"

#instalar curl 
apt install curl -y
echo -e "\033[32m curl instalado \033[0m"

#instalar navegador web links 

apt install links -y
echo -e "\033[32m links instalado \033[0m"


# Gerar certificado autofirmado
echo -e "\033[32mGerando certificado autofirmado...\033[0m"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx-selfsigned.key \
  -out /etc/ssl/certs/nginx-selfsigned.crt

# Gerar chave Diffie-Hellman
echo -e "\033[32mGerando chave Diffie-Hellman...\033[0m"
openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Criar diretório snippets caso não exista
if [ ! -d "/etc/nginx/snippets" ]; then
    echo -e "\033[32mCriando diretório /etc/nginx/snippets...\033[0m"
    mkdir -p /etc/nginx/snippets
fi

# Criar o arquivo self-signed.conf
echo -e "\033[32mCriando o arquivo self-signed.conf...\033[0m"
cat <<EOL > /etc/nginx/snippets/self-signed.conf
ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;
EOL

# Criar o arquivo ssl-params.conf
echo -e "\033[32mCriando o arquivo ssl-params.conf...\033[0m"
cat <<EOL > /etc/nginx/snippets/ssl-params.conf
ssl_protocols TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/nginx/dhparam.pem;
ssl_ciphers EECDH+AESGCM:EDH+AESGCM;
ssl_ecdh_curve secp384r1;
ssl_session_timeout 10m;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOL

# Solicitar o nome do domínio
echo -e "\033[33mDigite o nome do domínio (exemplo: meu_dominio.local): \033[0m"
read dominio

# Configurar diretórios do domínio
diretorio="/var/www/$dominio"
html="$diretorio/html"
status_pages="$diretorio/status-pages"
logs="$diretorio/logs"
maintenance="$diretorio/maintenance"

# Criar diretórios para o domínio
echo -e "\033[32mCriando diretórios para o domínio...\033[0m"
mkdir -p "$html" "$status_pages" "$logs" "$maintenance"

# Criar arquivos de logs
echo -e "\033[32mCriando arquivos de logs...\033[0m"
touch "$logs/nginx_access.log" "$logs/nginx_error.log"

# Criar uma página de teste simples
echo "<html><body><h1>Bem-vindo ao $dominio!</h1></body></html>" > "$html/index.html"

# Criar páginas de erro personalizadas
echo "<html><body><h1>Erro 404 :/$dominio!</h1></body></html>" > "$status_pages/404.html"
echo "<html><body><h1>Manutencao 503 :/$dominio!</h1></body></html>" > "$maintenance/503.html"

# Criar configuração do Nginx para o domínio
config_file="/etc/nginx/sites-available/$dominio"
echo -e "\033[32mCriando configuração para o domínio...\033[0m"
cat <<EOL > $config_file
server {
    listen 80;
    listen [::]:80;
    server_name $dominio;
    return 301 https://$dominio\$request_uri;
}
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2 ipv6only=on;
    include /etc/nginx/snippets/self-signed.conf;
    include /etc/nginx/snippets/ssl-params.conf;
    server_name $dominio;

    root $html;
    index index.html;

    access_log $logs/nginx_access.log;
    error_log $logs/nginx_error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    error_page 404 /status-pages/404.html;
    location = /status-pages/404.html {
        root $diretorio;
        internal;
    }

    error_page 503 /maintenance/503.html;
    location = /maintenance/503.html {
        root $diretorio;
        internal;
    }

    location /maintenance {
        return 503;
    }
}
EOL

# Criar link simbólico no sites-enabled
echo -e "\033[32mAtivando o site no Nginx...\033[0m"
ln -sf $config_file /etc/nginx/sites-enabled/

# Adicionar o domínio ao arquivo /etc/hosts
if ! grep -q "$dominio" /etc/hosts; then
    echo "127.0.0.1   $dominio" >> /etc/hosts
    echo -e "\033[32mDomínio $dominio adicionado ao /etc/hosts\033[0m"
else
    echo -e "\033[31mO domínio $dominio já está presente no /etc/hosts\033[0m"
fi

# Testar configuração do Nginx
echo -e "\033[32mTestando a configuração do Nginx...\033[0m"
if nginx -t; then
    # Recarregar o Nginx
    echo -e "\033[32mRecarregando o Nginx...\033[0m"
    systemctl reload nginx
    echo -e "\033[32mDomínio $dominio configurado com sucesso!\033[0m"
else
    echo -e "\033[31mErro na configuração do Nginx. Verifique os logs.\033[0m"
    exit 1
fi