#!/bin/bash
# Instalar os pacotes necessários
apt-get update -y
apt-get upgrade -y
apt-get install -y ca-certificates curl
# Instalação do Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu
# Subir o Wordpress
cat << EOF > /home/ubuntu/docker-compose.yaml
services:
  wordpress:
    image: wordpress
    restart: always
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: <rds-endpoint>
      WORDPRESS_DB_USER: <database-main-user>
      WORDPRESS_DB_PASSWORD: <database-password>
      WORDPRESS_DB_NAME: <database-name>
    volumes:
      - /mnt/efs/wordpress:/var/www/html
EOF
docker compose -f /home/ubuntu/docker-compose.yaml up -d
# Montagem do EFS
apt-get install -y nfs-common
mkdir -p /mnt/efs
# !!! Insira nessa linha o comando copiado em Anexar usando client do NFS "altere o 'efs' para '/mnt/efs' no final"
chown -R 1000:1000 /mnt/efs/wordpress
echo "<EFS-DNS-Name>:/ /mnt/efs nfs defaults,_netdev 0 0" >> /etc/fstab

