# TP5 : Déploiement d'une application CodeIgniter 4 avec Ansible

**Auteur :** DAMBE Lamboni
**UFR :** Rouen, Département Informatique
**Programme :** Master 2 SSI
**Date :** Mardi 10 Décembre 2024
**Module :** Administration Réseaux et Protocoles
**Email :** [dlamboni31@gmail.com](mailto:dlamboni31@gmail.com)

---

## 1. Présentation

Ce projet a pour objectif de **déployer automatiquement une application CodeIgniter 4** dans un conteneur LXD en utilisant **Ansible**. La stack logicielle complète comprend :

* Serveur web Nginx
* PHP 7.4 avec extensions nécessaires
* MySQL avec création d’une base de données et d’un utilisateur dédié

Le script Bash fourni automatise l’ensemble du processus, depuis la création du conteneur jusqu’au déploiement de l’application.

---

## 2. Prérequis

* **LXD** installé sur la machine hôte
* Ubuntu 20.04 comme image de conteneur
* Connexion Internet pour l’installation des paquets
* Ansible, Python3-pymysql et sshpass installés dans le conteneur (automatisé par le script)

---

## 3. Étapes du déploiement

### Étape 1 : Création et configuration du conteneur

* Création du conteneur Ubuntu 20.04 nommé `CodeIgniter4-Tp5`
* Configuration de SSH pour permettre l’authentification par mot de passe
* Redémarrage du service SSH pour appliquer la configuration

---

### Étape 2 : Installation des utilitaires

* Installation de **Ansible**, **Python3-pymysql** et **sshpass** dans le conteneur
* Configuration du mot de passe root pour le conteneur

---

### Étape 3 : Automation avec Ansible

#### 3.1. Inventaire Ansible

Fichier `inventory.ini` créé automatiquement dans le conteneur :

```ini
[codeigniter_servers]
CodeIgniter4-Tp5 ansible_host=<IP_du_conteneur> ansible_user=root ansible_ssh_pass=root ansible_connection=ssh ansible_python_interpreter=/usr/bin/python3
```

---

#### 3.2. Rôles Ansible

1. **webserver** : installation et configuration de Nginx et PHP-FPM, déploiement du template Nginx pour CodeIgniter
2. **mysql** : installation de MySQL, création de la base `codeigniter_db` et de l’utilisateur avec tous les privilèges
3. **php** : installation de PHP 7.4 et extensions nécessaires (cli, mysql, curl)

---

#### 3.3. Playbook principal

Fichier `site.yml` :

```yaml
---
- name: Deploy CodeIgniter 4 application with Nginx
  hosts: codeigniter_servers
  become: yes
  vars:
    mysql_password: "secret_password"
  roles:
    - webserver
    - php
    - mysql
```

---

### Étape 4 : Déploiement de l’application

* Copie des fichiers de l’application CodeIgniter dans `/var/www/html/codeigniter`
* Attribution des permissions correctes à l’utilisateur et groupe `www-data`
* Redémarrage du service Nginx via handler Ansible pour appliquer la configuration

---

### Étape 5 : Exécution automatisée

Le script `deploy.sh` :

* Crée et configure le conteneur
* Installe les utilitaires nécessaires
* Génère l’inventaire et les rôles Ansible
* Exécute le playbook pour déployer l’application
* Vérifie la connectivité HTTP avec `curl`

---

## 4. Nettoyage

Le script `cleanup.sh` permet de **supprimer le conteneur LXD** et nettoyer l’environnement :

```bash
#!/bin/bash

echo -e "\n____ Nettoyage du TP5 Ansible ____\n"

CONTAINER_NAME="CodeIgniter4-Tp5"

if lxc list "$CONTAINER_NAME" --format csv | grep -q "$CONTAINER_NAME"; then
    echo -e "\n*** Arrêt du conteneur LXD '$CONTAINER_NAME' ***\n"
    lxc stop "$CONTAINER_NAME" --force

    echo -e "\n*** Suppression du conteneur LXD '$CONTAINER_NAME' ***\n"
    lxc delete "$CONTAINER_NAME"

    echo -e "\n*** Nettoyage terminé avec succès. ***\n"
else
    echo -e "\n[Info] Le conteneur '$CONTAINER_NAME' n'existe pas ou a déjà été supprimé.\n"
fi
```

---

## 5. Test et vérification

Après exécution du script, l’application CodeIgniter doit être accessible à l’adresse IP du conteneur. Une requête `curl -I http://<IP_du_conteneur>` doit renvoyer un code HTTP 200.

---

## 6. Références

* [Documentation officielle Ansible](https://docs.ansible.com/ansible/latest/index.html)
* [OpenClassrooms : Automatiser vos tâches avec Ansible](https://openclassrooms.com/fr/courses/2035796-utilisez-ansible-pour-automatiser-vos-taches-de-configuration/6373897-assemblez-les-operations-avec-les-playbooks-pour-automatiser-le-deploiement)
* [Tutoriel IAC Goffinet](https://iac.goffinet.org/ansible-linux/un-premier-playbook/)

---

