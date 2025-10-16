#!/bin/bash

echo -e "\n____ Nettoyage du TP5 Ansible réalisé par DAMBE Lamboni ____\n"

# Arrêter et supprimer le conteneur LXD
echo -e "\n*** Arrêt et suppression du conteneur LXD ***\n"
lxc stop CodeIgniter4-Tp5
lxc delete CodeIgniter4-Tp5
