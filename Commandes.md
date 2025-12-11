# Service réseau

**Membres :**
- Johann CHIAROTTO
- Dylan THOMAS
- Theo DARRIBAU
**Contexte :** Vous êtes administrateur système dans une entreprise. Votre mission est de concevoir, déployer et maintenir une infrastructure réseau complète capable d'héberger les services de l'entreprise.

**Sujet :** https://gitlab.com/MoulesFrites/b2-linux-2025/-/blob/main/00-Projet.md?ref_type=heads


‎ 
## 1️⃣ Infrastructure de base

### VM :
- Rocky-9.7-x86_64-minimal
- Mémoire vive : 2048
- Processeur : 2CPU
- 1.Optique 2.Disque dur
- adaptateur 1 : NAT
- adaptateur 2 : HostOnly


### Architecture réseau

![alt text](architecture.png)

Carte 1 : 192.168.56.1\
Carte 2 : 192.168.57.1

FIREWALL:
- NAT
- Carte 1 -> 192.168.56.10
- Carte 2 -> 192.168.57.10

SERVEUR :
- Carte 1 -> 192.168.56.20

BACKUP :
- Carte 1 -> 192.168.56.30

CLIENT :
- Carte 2 -> 192.168.57.20



### Configuration carte HostOnly

Création d'une carte Réseau sans DNS pour reliser en HOstOnly.

```
sudo nano /etc/sysconfig/network-script/ifcfg-enp0s8
```

```
DEVICE=enp0s8
NAME=johann

ONBOOT=yes
BOOTPROTO=static

IPADDR=192.168.56.<ID-PC>
NETMASK=255.255.255.0
GATEWAY=198.168.56.1
DNS1=8.8.8.8
```

### Création d'un compte autre qu'**admin**

```
sudo adduser <NAME>
sudo passwd <NAME>
sudo usermod -aG wheel <NAME>
su - <NAME>
```

### Configuration SSH

⚠️ A TESTER ET VÉRIFIER

```
nano /etc/ssh/sshd_config
```

- Port 2222
- PermitRootLogin no
- MaxAuthTries 5
- PubkeyAuthentication yes
- PasswordAuthentication no
- PermetEmptyPasswords no

```
sudo systemctl reload sshd   
```


### Changement Hostname

```
sudo hostnamectl set-hostname PC-<ID>
```




‎ 
## 2️⃣ Sauvegarde et restauration


Script de sauvegarde à automatisé avec cron.

```
sudo crontab -e
0 3 * * * /usr/local/bin/backup_rsync.sh 
```

Nom du fichier de sauvegarde : `sauvegarde.sh`.

La sauvegarde sert a enregistrer tous les fichiers qu'il y a sur la VM.\
Une fois la sauvevegarde faite, nous revevons un mail du status de la sauvegarde ainsi que l'emplacement de la sauvegarde.


‎ 
## 3️⃣ Services réseau

‎ 
## 4️⃣ Conteneurisation

‎ 
## 5️⃣ Automatisation

‎ 
## 6️⃣ Surveillance