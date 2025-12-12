# Service réseau
‎ 

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
Carte 2 : 192.168.57.1\
Carte 3 : 192.168.58.1

FIREWALL:
- NAT
- Carte 1 -> 192.168.56.10 -> (serveur)
- Carte 2 -> 192.168.57.10 -> (backup)
- Carte 3 -> 197.168.58.10 -> (client)

SERVEUR :
- Carte 1 -> 192.168.56.20

BACKUP :
- Carte 2 -> 192.168.57.20

CLIENT :
- Carte 3 -> 192.168.58.20



### Configuration carte HostOnly

Création d'une carte Réseau sans DNS pour reliser en HostOnly.

```bash
sudo nano /etc/sysconfig/network-script/ifcfg-enp0s<CARTE>
```

```bash
DEVICE=<CARTE>
NAME=lan

ONBOOT=yes
BOOTPROTO=static

IPADDR=192.168.<IP-PC>
NETMASK=255.255.255.0
GATEWAY=198.168.<IP-FIREWALL>
DNS1=8.8.8.8
```

```bash
sudo nmcli con reload 
sudo nmcli con up lan
```

### Création d'un compte autre qu'**admin**

```bash
sudo adduser <NAME>
sudo passwd <NAME>
sudo usermod -aG wheel <NAME>
su - <NAME>
```

### Configuration SSH ⚠️ A TESTER ET VÉRIFIER

```bash
nano /etc/ssh/sshd_config
```

- Port 2222
- PermitRootLogin no
- MaxAuthTries 5
- PubkeyAuthentication yes
- PasswordAuthentication no
- PermetEmptyPasswords no

```bash
sudo systemctl reload sshd   
```


### Changement Hostname

```bash
sudo hostnamectl set-hostname <NAME>
```


### Configuration firewall

**Activer le forwarding IP (routage)**

```bash
# Activer temporairement
sudo sysctl -w net.ipv4.ip_forward=1

# Rendre permanent
sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sudo sysctl -p
```

**Configurer les zones firewall**

```bash
# Assigner les interfaces aux zones
sudo firewall-cmd --permanent --zone=public --add-interface=enp0s3
sudo firewall-cmd --permanent --zone=internal --add-interface=enp0s8
sudo firewall-cmd --permanent --zone=internal --add-interface=enp0s9
sudo firewall-cmd --permanent --zone=internal --add-interface=enp0s10
sudo firewall-cmd --reload
```

**Activer le NAT (masquerading)**

```bash
# Activer le masquerading sur les zones
sudo firewall-cmd --permanent --zone=public --add-masquerade
sudo firewall-cmd --permanent --zone=internal --add-masquerade
sudo firewall-cmd --reload
```

**Autoriser le forwarding depuis la zone internal**

```bash
# Changer le target de la zone internal pour autoriser le forwarding
sudo firewall-cmd --permanent --zone=internal --set-target=ACCEPT
sudo firewall-cmd --reload
```

**Vérification**

```bash
# Vérifier la configuration
sudo firewall-cmd --zone=public --list-all
sudo firewall-cmd --zone=internal --list-all
cat /proc/sys/net/ipv4/ip_forward
```




‎ 
## 2️⃣ Sauvegarde et restauration


Script de sauvegarde à automatisé avec cron.

```bash
sudo crontab -e
0 3 * * * /usr/local/bin/backup_rsync.sh 
```

Nom du fichier de sauvegarde : `backup_rsync.sh`.

La sauvegarde sert a enregistrer tous les fichiers qu'il y a sur la VM.\
Une fois la sauvevegarde faite, nous revevons un mail du status de la sauvegarde ainsi que l'emplacement de la sauvegarde.


‎ 
## 3️⃣ Services réseau

### Service web https

```
sudo dnf update -y
```
```
sudo dnf install nginx -y
```
```
sudo systemctl enable --now nginx
```
- Vérification si c'est enable
```
sudo systemctl status nginx
```
```
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```
- Site accessbile via l'ip de la machine sur internet normalement
```
sudo mkdir /etc/nginx/certificate
```
``` 
cd /etc/nginx/certificate
```
```
sudo openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out nginx-certificate.crt -keyout nginx.key
```
```
nano /etc/nginx/nginx.conf
```
```
return 301 https://$host$request_uri;
```
- Les deux commandes suivantes sont l'ajout de la redirection http vers https   
```
sudo nano /etc/nginx/conf.d/ssl.conf
```
```
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name _;

    ssl_certificate     /etc/nginx/certificate/nginx-certificate.crt;
    ssl_certificate_key /etc/nginx/certificate/nginx.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root /usr/share/nginx/html;
    index index.html index.htm;
}
```
```
sudo nginx -t
```
```
sudo systemctl reload nginx
```
```
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

‎ 
## 4️⃣ Conteneurisation

‎ 
## 5️⃣ Automatisation

‎ 
## 6️⃣ Surveillance