#!/bin/bash

echo -e "\n____TP5 ansible réalisé par DAMBE Lamboni____\n"

echo -e "\n*** Étape 1 : Installation et configuration du conteneur via LXD ***\n"

# Création du conteneur LXD
echo -e "\nCréation du conteneur LXD\n"
lxc launch ubuntu:20.04 CodeIgniter4-Tp5

# Attendre que le conteneur soit complètement démarré
sleep 30

# Récupération de l'adresse IP du conteneur
IP_ADDRESS=$(lxc list CodeIgniter4-Tp5 -c 4 --format csv | cut -d' ' -f1)

# Configuration SSH sur le conteneur
lxc exec CodeIgniter4-Tp5 -- bash -c "
    echo 'Configuration SSH'
    sed -i 's/^#\(PubkeyAuthentication\) .*/\1 no/' /etc/ssh/sshd_config
    sed -i 's/^#\(PasswordAuthentication\) .*/\1 yes/' /etc/ssh/sshd_config
    sed -i 's/^#\(PermitRootLogin\) .*/\1 yes/' /etc/ssh/sshd_config
    sed -i 's/^#\(ChallengeResponseAuthentication\) .*/\1 yes/' /etc/ssh/sshd_config
    systemctl restart sshd
"

# Étape 2 : Installation des utilitaires sur le conteneur
echo -e "\n*** Étape 2 : Installation des utilitaires sur le conteneur CodeIgniter4-Tp5 ***\n"
lxc exec CodeIgniter4-Tp5 -- bash -c "
    sudo apt update
    sudo apt install -y ansible python3-pymysql sshpass
"

# Configuration du mot de passe root
echo -e "\nConfiguration du mot de passe root\n"
lxc exec CodeIgniter4-Tp5 -- bash -c "
    echo 'root:root' | chpasswd
"

# Étape 3 : Automatisation du déploiement
echo -e "\n**** Étape 3 : Automation du déploiement ****\n"

# Création du fichier d'inventaire dans le conteneur
lxc exec CodeIgniter4-Tp5 -- bash -c "
cat <<EOF > /root/inventory.ini
[codeigniter_servers]
CodeIgniter4-Tp5 ansible_host=${IP_ADDRESS} ansible_user=root ansible_ssh_pass=root ansible_connection=ssh ansible_python_interpreter=/usr/bin/python3
EOF
"

# Création et configuration du rôle webserver dans le conteneur
lxc exec CodeIgniter4-Tp5 -- bash -c "
ansible-galaxy init /root/webserver
cat <<EOF > /root/webserver/tasks/main.yml
---
- name: Install Nginx
  apt:
    name: nginx
    state: present
- name: Start and enable Nginx service
  systemd:
    name: nginx
    state: started
    enabled: yes
- name: Install PHP-FPM and necessary PHP modules
  apt:
    name:
      - php-fpm
      - php-mysql
      - php-cli
      - php-curl
    state: present
- name: Ensure PHP-FPM is running and enabled
  systemd:
    name: php7.4-fpm
    state: started
    enabled: yes
- name: Configure Nginx for CodeIgniter
  template:
    src: nginx_codeigniter.conf.j2
    dest: /etc/nginx/sites-available/codeigniter
  notify:
    - Reload Nginx
- name: Enable Nginx site configuration
  file:
    src: /etc/nginx/sites-available/codeigniter
    dest: /etc/nginx/sites-enabled/codeigniter
    state: link
  notify:
    - Reload Nginx
- name: Remove default site configuration
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify:
    - Reload Nginx
EOF
"

# Création du template nginx dans le conteneur
lxc exec CodeIgniter4-Tp5 -- bash -c "
cat <<EOF > /root/webserver/templates/nginx_codeigniter.conf.j2
server {
    listen 80;
    server_name {{ ansible_hostname }};
    root /var/www/html/codeigniter/public;
    index index.php index.html index.htm;
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }    
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    location ~ /\.ht {
        deny all;
    }
}
EOF
"

# Création et configuration du rôle MySQL dans le conteneur
lxc exec CodeIgniter4-Tp5 -- bash -c "
ansible-galaxy init /root/mysql
cat <<EOF > /root/mysql/tasks/main.yml
---
- name: Install MySQL
  apt:
    name: mysql-server
    state: present
- name: Ensure MySQL is running and enabled
  systemd:
    name: mysql
    state: started
    enabled: yes
- name: Create a MySQL database for CodeIgniter
  mysql_db:
    name: codeigniter_db
    state: present
- name: Create a MySQL user for CodeIgniter
  mysql_user:
    name: \"{{ mysql_user }}\"
    password: \"{{ mysql_password }}\"
    priv: \"codeigniter_db.*:ALL\"
    state: present
EOF
"

# Création et configuration du rôle PHP dans le conteneur
lxc exec CodeIgniter4-Tp5 -- bash -c "
ansible-galaxy init /root/php
cat <<EOF > /root/php/tasks/main.yml
---
- name: Install PHP 7.4 and required extensions
  apt:
    name:
      - php7.4
      - php7.4-cli
      - php7.4-mysql
      - php7.4-curl
    state: present
EOF
"

# Création du playbook principal dans le conteneur
lxc exec CodeIgniter4-Tp5 -- bash -c "
cat <<EOF > /root/site.yml
---
- name: Deploy CodeIgniter 4 application with Nginx
  hosts: codeigniter_servers
  become: yes
  vars:
    mysql_password: \"secret_password\"
  roles:
    - webserver
    - php
    - mysql
EOF
"

# Déploiement à l'intérieur du conteneur
echo -e "\n*** Lancement du playbook avec ansible-playbook à l'intérieur du conteneur ***\n"
lxc exec CodeIgniter4-Tp5 -- bash -c "
cd /root
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini site.yml
"


# Vérification de la connectivité avec curl
echo -e "\n*** Test de la connectivité avec curl ***\n"
curl -I "http://${IP_ADDRESS}" || {
    echo -e "\n[Erreur] Impossible d'atteindre le serveur CodeIgniter à l'adresse ${IP_ADDRESS}\n"
    exit 1
}


# Fin
echo -e "\n**** Fin de l'exécution du script. ****"




#Le script automatise le déploiement d'une application CodeIgniter 4 dans un conteneur LXD configuré avec une pile logicielle
# complète (Nginx, PHP, MySQL) en utilisant Ansible. Il crée un conteneur Ubuntu 20.04, configure l'accès SSH avec authentification
# par mot de passe, installe les outils nécessaires (Ansible, Python3-pymysql, sshpass, curl), puis orchestre l’installation et la 
#configuration des services via des rôles Ansible. Ces rôles gèrent l'installation de Nginx (avec un site personnalisé), 
#PHP (et ses extensions nécessaires), et MySQL (avec une base de données et un utilisateur dédiés). Enfin, le script exécute
#un playbook pour assurer le bon fonctionnement de l'infrastructure et permet de tester l'accès HTTP au serveur.