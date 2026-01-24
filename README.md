# 🚀 Projet Fil Rouge - Infrastructure Réseau Linux
‎ 

## 👥 Membres :
- Johann CHIAROTTO
- Dylan THOMAS
- Theo DARRIBEAU

**Année :** B2 Cybersécurité

‎ 
## 🎯 Objectif du Projet

Conception, déploiement et maintien d'une infrastructure réseau Linux complète, sécurisée et automatisée, capable d'héberger les services essentiels d'une entreprise.

Ce projet met l'accent sur :
* **L'Automatisation** (Infrastructure as Code avec Ansible)
* **La Conteneurisation** des services (Docker)
* **La Sécurité** et la **Maintenabilité**

---

## 🏗️ Architecture et Technologies

### 1. Schéma d'Architecture et Topologie Réseau
L'infrastructure utilise un modèle à **trois sous-réseaux distincts**, chacun géré et sécurisé par une machine **FIREWALL** agissant comme passerelle (NAT/Routage).

![alt text](fichier_supplementaire/architecture.png)

* **Réseaux Utilisés :** `192.168.56.0/24` (Réseau Serveur), `192.168.57.0/24` (Réseau Sauvegarde), `192.168.58.0/24` (Réseau Client).
* **Système d'Exploitation :** **Rocky Linux 9.7 (Minimal)** pour toutes les machines.

### 2. Adressage IP

| Machine | Rôle Principal | Interface 1 (Sous-réseau) | Interface 2 (Sous-réseau) | Interface 3 (Sous-réseau) |
| :--- | :--- | :--- | :--- | :--- |
| **FIREWALL** | Passerelle/Sécurité (NAT) | `192.168.56.1` (Réseau Serveur) | `192.168.57.1` (Réseau Sauvegarde) | `192.168.58.1` (Réseau Client) |
| **SERVEUR** | Services Web et Mail | `192.168.56.20` | - | - |
| **BACKUP** | Stockage des Sauvegardes | - | `192.168.57.20` | - |
| **CLIENT** | Machine de Test/Accès | - | - | `192.168.58.20` |

| Accès depuis l'hôte | IP (Réseau HostOnly) |
| :--- | :--- |
| **Accès au SERVEUR** | `192.168.56.10` (Via FIREWALL) |
| **Accès au BACKUP** | `192.168.57.10` (Via FIREWALL) |
| **Accès au CLIENT** | `192.168.58.10` (Via FIREWALL) |

### 3. Services Déployés

| Service | Rôle | Technologie(s) | Conteneurisé | Accès Clé |
| :--- | :--- | :--- | :--- | :--- |
| **Service Web** | Site vitrine avec redirection HTTP vers HTTPS | **Nginx** | ✅ Oui | `https://192.168.56.20` |
| **Service de Mail** | Serveur de messagerie local (SMTP/IMAP) | **Postfix & Dovecot** | ✅ Oui | Port 25 et 143 |
| **Sauvegarde** | Sauvegarde automatisée de l'infrastructure | **rsync** + **cron** | ❌ Non | `192.168.57.20` |

### 4. Outils Clés 

| Catégorie | Outil(s) |
| :--- | :--- |
| **Infrastructure as Code** | **Ansible** (Automatisation complète) |
| **Conteneurisation** | **Docker** & **Docker Compose** |
| **Système** | **Rocky Linux 9** / Pare-feu **FirewallD** / **SELinux** |
| **Sauvegarde** | **rsync** via scripts bash et **Crontab** |

---

## ⚙️ Déploiement et Automatisation

L'ensemble de l'infrastructure est déployé et configuré via **Ansible** depuis la machine hôte.

### Prérequis

* Un hyperviseur (VirtualBox, etc.) avec 4 VMs Rocky Linux 9.7 (Minimal).
* **Ansible** et **sshpass** installés sur la machine hôte.

### Étapes de Déploiement

1. **Préparation des VMs :** - Créer les VMs, définir les cartes réseaux (HostOnly/NAT) avec les adresses IP fixes.
   - S'assurer de la connectivité SSH entre l'hôte et les VMs.
2. **Lancement de l'automatisation :** Exécuter le playbook principal pour installer et configurer tous les services (utilisateurs, SSH, Firewall, Docker, etc.).
   ```bash
   ansible-playbook -i inventory.ini setup.yml
3.Vérification des conteneurs : Sur le serveur, vérifier que les services Web et Mail tournent correctement :
```Bash
sudo docker ps -a
```

➡️ Pour le détail des commandes pas à pas, veuillez consulter le fichier commandes_configurations.md.

### 🔒 Sécurité et Maintenance

**Accès SSH Sécurisé**
L'accès aux machines FIREWALL, SERVEUR et BACKUP est sécurisé :
- **Port modifié** : 2222 (au lieu de 22)
- **Root désactivé** : `PermitRootLogin no`
- **Contrôle d'accès** : Autorisation limitée à un utilisateur spécifique.
- Gestion de **SELinux** et **FirewallD** pour autoriser ce port spécifique.

**Stratégie de Sauvegarde**
- Un script automatisé (backup_rsync.sh`) s'exécute tous les jours à 3h00 du matin via une tâche cron.
- Les fichiers du système sont sauvegardés via rsync.
- Une notification par mail est envoyée avec le statut et l'emplacement de la sauvegarde.

**Surveillance**
L'état des conteneurs Docker (Web et Mail) est géré avec la politique `restart: always` assurant une haute disponibilité en cas de crash du service.

(Note : L'implémentation de la surveillance avancée type Prometheus/Grafana est prévue pour une version future).

📖 Documentation
- commandes_configurations.md : Référence complète et chronologique des commandes et configurations manuelles effectuées (réseau, SSH, Nginx, Mail, Docker).

- Scripts et fichiers utiles : Scripts de sauvegarde (backup_rsync.sh), fichiers docker-compose.yml, certificats SSL autogénérés.

Dépôt Git : https://github.com/JohannChiarotto/Reseau_linux_b2.git
