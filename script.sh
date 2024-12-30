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

# gerar certificado autofirmado
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt

echo -e "\033[32m certificado autofirmado gerado \033[0m"

# gerar chave 
openssl dhparam -out /etc/nginx/dhparam.pem 2048
echo -e "\033[32m chave ssl gerada \033[0m"


#configurar nginx para usar o SSL

# Caminho do arquivo de configuração
CONF_FILE="/etc/nginx/snippets/self-signed.conf"

# Conteúdo do arquivo de configuração
CONF_CONTENT="ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;
ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;"
# Cria o arquivo self-signed.conf 
echo "Criando o arquivo $CONF_FILE..."
sudo bash -c "echo '$CONF_CONTENT' > $CONF_FILE"

# Verifica se o arquivo foi criado com sucesso
if [ -f "$CONF_FILE" ]; then
    echo "Arquivo $CONF_FILE criado com sucesso!"
else
    echo "Erro ao criar o arquivo $CONF_FILE."
fi

# Caminho do arquivo
CONF_FILE_SSL="/etc/nginx/snippets/ssl-params.conf"

# Conteúdo do arquivo
CONF_CONTENT_SSL="ssl_protocols TLSv1.3;
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

# Disable strict transport security for now. You can uncomment the following
# line if you understand the implications.
#add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload;\";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection \"1; mode=block\";"

# Verifica se o diretório existe
if [ ! -d "/etc/nginx/snippets" ]; then
    echo "O diretório /etc/nginx/snippets não existe. Criando..."
    sudo mkdir -p /etc/nginx/snippets
fi

# Cria o arquivo e adiciona o conteúdo
echo "Criando o arquivo $CONF_FILE_SSL..."
sudo bash -c "echo '$CONF_CONTENT_SSL' > $CONF_FILE_SSL"

# Verifica se o arquivo foi criado com sucesso
if [ -f "$CONF_FILE_SSL" ]; then
    echo "Arquivo $CONF_FILE_SSL criado com sucesso!"
else
    echo "Erro ao criar o arquivo $CONF_FILE_SSL."
fi


########################### DOMINIO ##############################

# Solicitar o nome do domínio
echo -e "\033[33mDigite o nome do domínio (exemplo: meu_dominio.local): \033[0m"
read dominio

# Definir o diretório onde os arquivos do site serão armazenados
diretorio="/var/www/$dominio"
html="$diretorio/html"
status_pages="$diretorio/status-pages"
logs="$diretorio/logs"
maintenance="$diretorio/maintenance"

# Verificar se o diretório já existe
if [ -d "$diretorio" ]; then
  echo -e "\033[31mO diretório $diretorio já existe!\033[0m"
  exit 1
else
  # Criar o diretório principal e a subpastas
  mkdir -p "$html"
  mkdir -p "$status_pages"
  mkdir -p "$maintenance"
  echo -e "\033[32mDiretório $html criado!\033[0m"
  echo -e "\033[32mDiretório $status_page criado!\033[0m"
  echo -e "\033[32mDiretório $maintenance criado!\033[0m"
fi

#verficar diretorio de logs
if [ -d "$diretorio/logs" ]; then
  echo -e "\033[31mO diretório $diretorio logs já existe!\033[0m"
  exit 1
else
  # Criar o diretório logs
  mkdir -p "$logs"
  echo -e "\033[32mDiretório $logs criado!\033[0m"

fi


#criar arquivos de logs para registro
touch "$logs/nginx_access.log"
touch "$logs/nginx_error.log"
echo -e "\033[32mArquivos de log criados!\033[0m"


# Criar uma página de teste simples dentro da pasta html
echo "<html><body><h1>Bem-vindo ao $dominio!</h1></body></html>" > "$html/index.html"

#erros##################################

#Criar Uma pagina de erro 404 
echo "<html><body><h1>Erro 404 :/$dominio!</h1></body></html>" > "$status_pages/404.html"

#Criar pagina manutencao
echo "<html><body><h1>Manutencao 503 :/$dominio!</h1></body></html>" > "$maintenance/503.html"



# Definir a configuração do Nginx para o domínio
config_file="/etc/nginx/sites-available/$dominio"

cat <<EOL > $config_file
server {
    listen 80;
    listen [::]:80;
        
    server_name $dominio;
    return 301 https://$dominio$request_uri;
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

    # Página de erro personalizada para 404
    error_page 404 /status-pages/404.html;
    location = /status-pages/404.html {
        root $diretorio;
        internal;
    }

    # Página de erro personalizada para 503
    error_page 503 /maintenance/503.html;
    location = /maintenance/503.html {
        root $diretorio;
        internal;
    }

    # Endpoint para ativar a página de manutenção
    location /maintenance {
        return 503;
    }
}
EOL

# Criar um link simbólico no diretório sites-enabled
ln -s $config_file /etc/nginx/sites-enabled/

# Adicionar o domínio ao arquivo /etc/hosts
if ! grep -q "$dominio" /etc/hosts; then
    echo "127.0.0.1   $dominio" >> /etc/hosts
    echo -e "\033[32mDomínio $dominio adicionado ao /etc/hosts\033[0m"
else
    echo -e "\033[31mO domínio $dominio já está presente no /etc/hosts\033[0m"
fi

# Testar a configuração do Nginx
nginx -t

# Verificar se a configuração está correta e recarregar o Nginx
if [ $? -eq 0 ]; then
  systemctl reload nginx
  echo -e "\033[32mDomínio $dominio configurado com sucesso!\033[0m"
else
  echo -e "\033[31mErro na configuração do Nginx. Não foi possível recarregar o serviço.\033[0m"
  exit 1
fi



