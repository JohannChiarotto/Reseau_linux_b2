# 🚀 Projet Fil Rouge - Infrastructure Réseau Linux
‎ 

## 👥 Membres :
- Johann CHIAROTTO
- Dylan THOMAS
- Theo DARRIBAU

**Année :** B2 Cybersécurité

‎ 
## 🎯 Objectif du Projet

Conception, déploiement et maintien d'une infrastructure réseau Linux complète, sécurisée et automatisée, capable d'héberger les services essentiels d'une entreprise.

Ce projet met l'accent sur :
* **L'Automatisation** (Infrastructure as Code)
* **La Conteneurisation** des services
* **La Sécurité** et la **Maintenabilité**

---

## 🏗️ Architecture et Technologies

### 1. Schéma d'Architecture et Topologie Réseau
L'infrastructure utilise un modèle à **trois sous-réseaux distincts**, chacun géré et sécurisé par une machine **FIREWALL** agissant comme passerelle (NAT/Routage).

![alt text](fichier_supplementaire/architecture.png)

* **Réseaux Utilisés :** $192.168.56.0/24$ (Réseau Serveur), $192.168.57.0/24$ (Réseau Sauvegarde), $192.168.58.0/24$ (Réseau Client).
* **Système d'Exploitation :** **Rocky Linux 9** pour toutes les machines.

### 2. Adressage IP

| Machine | Rôle Principal | Interface 1 (Sous-réseau) | Interface 2 (Sous-réseau) | Interface 3 (Sous-réseau) |
| :--- | :--- | :--- | :--- | :--- |
| **FIREWALL** | Passerelle/Sécurité (NAT) | $192.168.56.1$ (Réseau Serveur) | $192.168.57.1$ (Réseau Sauvegarde) | $192.168.58.1$ (Réseau Client) |
| **SERVEUR** | Services Web et DNS | $192.168.56.20$ | - | - |
| **BACKUP** | Stockage des Sauvegardes | - | $192.168.57.20$ | - |
| **CLIENT** | Machine de Test/Accès | - | - | $192.168.58.20$ |

| Service | Accès Filaire (Privé Hôte) |
| :--- | :--- |
| **Accès au SERVEUR** | $192.168.56.10$ (Via FIREWALL) |
| **Accès au BACKUP** | $192.168.57.10$ (Via FIREWALL) |
| **Accès au CLIENT** | $192.168.58.10$ (Via FIREWALL) |

### 3. Services Déployés

| Service | Rôle | Technologie(s) | Conteneurisé | Accès Clé |
| :--- | :--- | :--- | :--- | :--- |
| **Service Web** | Site vitrine en HTTPS | **Nginx** | 🚧 | `https://192.168.56.20` |
| **Service de Mail** | Serveur de messagerie | **PostFix** (Serveur)\ **Dovecot** (serveur)| 🚧 |  |


Pour compléter le tableau du haut :
| Service | Rôle | Technologie(s) | Conteneurisé | Accès Clé |
| **Résolution de Noms** | Serveur DNS interne | BIND9 | Non | `dig site.mon-entreprise.lan` |
| **Surveillance** | Monitoring et Alertes | Prometheus & Grafana | Oui (Docker Compose) | $https://monitoring.mon-entreprise.lan$ |

### 4. Outils Clés  🚧

| Catégorie | Outil(s) |
| :--- | :--- |
| **Infrastructure as Code** | **Ansible** (Automatisation) / **Vagrant** (VMs) |
| **Conteneurisation** | **Docker** & **Docker Compose** |
| **Système** | **Rocky Linux 9** / Pare-feu **FirewallD** (ou équivalent) |
| **Sauvegarde** | **rsync** / **Borg

---

## ⚙️ Déploiement et Automatisation  🚧

L'ensemble de l'infrastructure est entièrement déployé et configuré via **Ansible**.

### Prérequis

* [Liste des prérequis logiciels : Ex. Vagrant, VirtualBox/KVM, Ansible, Python]

### Étapes de Déploiement

1.  **Clonage :** Cloner ce dépôt Git.
2.  **Démarrage des VMs :**
    ```bash
    vagrant up
    ```
3.  **Déploiement Complet :** Exécuter le playbook principal pour installer et configurer tous les services, y compris le déploiement des conteneurs.
    ```bash
    ansible-playbook -i inventory/hosts main_playbook.yml
    ```

**➡️ Pour le détail des commandes pas à pas, veuillez consulter le fichier [commandes_configurations.md](./commandes_configurations.md).**

---

## 🔒 Sécurité et Maintenance

### Accès

L'accès à toutes les machines s'effectue via **SSH** et ses règles établie. L'authentification par mot de passe est tout de même activé.

### Stratégie de Sauvegarde  🚧

* Les données critiques et les configurations sont sauvegardées **quotidiennement** sur un serveur dédié.
* L'infrastructure peut être **restaurée** rapidement grâce au redéploiement automatisé (Ansible) suivi de la restauration des données à partir des sauvegardes.

### Surveillance  🚧

L'état des services est surveillé en temps réel via l'interface **Grafana** (accessible via le service de surveillance). Des alertes sont configurées en cas de défaillance majeure.

---

## 📖 Documentation

* **[commandes_configurations.md](./commandes_configurations.md)** : Référence complète et chronologique des commandes et configurations manuelles effectuées.
* **Scripts et fichier utiles** : Utilisé pour la sauvegarde, la restauration ou même pour une interface Nginx.
---

**Dépôt Git :** https://github.com/JohannChiarotto/Reseau_linux_b2.git