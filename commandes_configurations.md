# Commmandes de configuration
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

![alt text](fichier_supplementaire/architecture.png)

Carte 1 : 192.168.56.1\
Carte 2 : 192.168.57.1\
Carte 3 : 192.168.58.1

FIREWALL:
- NAT
- Carte 1 -> 192.168.56.10 -> (serveur, supervision)
- Carte 2 -> 192.168.57.10 -> (backup)
- Carte 3 -> 197.168.58.10 -> (client)

SERVEUR :
- Carte 1 -> 192.168.56.20

BACKUP :
- Carte 2 -> 192.168.57.20

CLIENT :
- Carte 3 -> 192.168.58.20

SUPERVISION :
- Carte 1 -> 192.168.56.30



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
GATEWAY=192.168.<IP-FIREWALL>
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

### Configuration SSH 

Cette configuration s'applique sur les VMs : **FIREWALL**, **SERVEUR**, **SUPERVISION** & **BACKUP**.

```bash
nano /etc/ssh/sshd_config
```

- Port 2222
- PermitRootLogin no
- PasswordAuthentication yes
- PermitEmptyPasswords no
- AllowUsers <VOTRE_USER>
- Protocol 2
- LoginGraceTime 60
- MaxAuthTries 3
- KbdInteractiveAuthentication no

Vérification erreur d'écriture :
```
sudo sshd -t
```

```
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --reload
```

Régler le problème de **SELinux** qui bloque le port :

```
# Installer les outils nécessaires
sudo dnf install policycoreutils-python-utils -y

# Autoriser le port 2222 pour SSH dans SELinux
sudo semanage port -a -t ssh_port_t -p tcp 2222

# Vérifier que le port est bien ajouté
sudo semanage port -l | grep ssh

# Redémarrer SSH
sudo systemctl restart sshd

# Vérifier le statut
sudo systemctl status sshd
```

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
### Sauvegarde et restauration

1. Prérequis & Connexion SSH Installez les outils et configurez la connexion sans mot de passe vers les machines à sauvegarder (Web/App, Firewall, etc.) :

```bash
# Installation
sudo dnf update -y && sudo dnf install -y rsync openssh-clients postfix mailx cyrus-sasl-plain

# Génération clé SSH & Envoi (Remplacer <IP_CIBLE> par les IP des VMs)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
ssh-copy-id user@<IP_CIBLE>
2. Déploiement des Scripts Créez l'arborescence et rendez les scripts exécutables (assurez-vous que backup.sh et restore.sh sont présents) :

Bash
mkdir -p ~/backup ~/backup-data ~/restore ~/cloud
chmod +x ~/backup/backup.sh ~/restore/restore.sh
3. Configuration Services (Email & Cloud)

Postfix (Gmail) :

Créez /etc/postfix/sasl_passwd avec : [smtp.gmail.com]:587 votre_email@gmail.com:votre_pass_app.

Compilez : sudo postmap /etc/postfix/sasl_passwd et sécurisez chmod 600.

Configurez /etc/postfix/main.cf pour utiliser le relay host Gmail.

Rclone (Cloud) :

Copiez votre configuration dans ~/.config/rclone/rclone.conf ou lancez rclone config (choix drive).

4. Automatisation (Crontab) Ajoutez la tâche planifiée (tous les jours à 02h00) via crontab -e :

Extrait de code
0 2 * * * /home/johann/backup/backup.sh >> /home/johann/backup/last_run.log 2>&1
5. Restauration Pour restaurer une sauvegarde, lancez simplement : ~/restore/restore.sh

```
‎ 
## 3️⃣ Services réseau

### Service web https

```bash
sudo dnf update -y
```

```bash
sudo dnf install nginx -y
```

```bash
sudo systemctl enable --now nginx
```

- Vérification si c'est enable
```bash
sudo systemctl status nginx
```

```
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

- Site accessbile via l'ip de la machine sur internet normalement
```bash
sudo mkdir /etc/nginx/certificate
```

``` bash
cd /etc/nginx/certificate
```

```bash
sudo openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out nginx-certificate.crt -keyout nginx.key
```

```bash
sudo nano /etc/nginx/nginx.conf
```

Rajouter la ligne suivante : `return 301 https://$host$request_uri;`\
De sorte a avoir un bloc comme celui ci :

```bash
server {
	listen       80;
    listen       [::]:80;
    server_name  _;

    return 301 https://$host$request_uri;
}
```

- Les deux commandes suivantes sont l'ajout de la redirection http vers https   
```bash
sudo nano /etc/nginx/conf.d/ssl.conf
```

```bash
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

```bash
sudo nginx -t
```

```bash
sudo systemctl reload nginx
```

```bash
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```



### Service mail

```bash
sudo hostnamectl set-hostname mail.example.local
```

```bash
sudo nano /etc/hosts
127.0.0.1   mail.example.local mail
```

```bash
sudo dnf install postfix -y
```

```bash
sudo systemctl enable --now postfix
```

```bash
sudo nano /etc/postfix/main.cf
```

- A complete dans la commande avt
```bash
myhostname = mail.example.local
mydomain = example.local
myorigin = $mydomain
inet_interfaces = all
inet_protocols = ipv4
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
mynetworks = 127.0.0.0/8
home_mailbox = Maildir/

```

```bash
sudo systemctl restart postfix
```

```bash
sudo dnf install dovecot -y
sudo systemctl enable --now dovecot
```

Rajouter la ligne suivante `protocols = imap pop3 lmtp` dans :
```bash
sudo nano /etc/dovecot/dovecot.conf
```

Rajouter la ligne suivante `mail_location = maildir:~/Maildir` dans :
```bash
sudo nano /etc/dovecot/conf.d/10-mail.conf
```

```bash
sudo firewall-cmd --permanent --add-service=smtp
sudo firewall-cmd --permanent --add-service=imap
sudo firewall-cmd --permanent --add-service=imaps
sudo firewall-cmd --reload
```

```bash
sudo adduser test
sudo passwd test
```

```bash
sudo mkdir -p /home/test/Maildir
sudo chown -R test:test /home/test/Maildir
```

```bash
sudo dnf install s-nail -y
```

```bash
echo "Ceci est un test" | mail -s "Test SMTP" test@localhost
```

```bash
sudo ls /home/test/Maildir/new
```

- Sur votre PC

```bash
telnet 192.168.56.20 25
```

```bash
EHLO pc-hote
MAIL FROM:<test@example.local>
RCPT TO:<test@example.local>
DATA
Subject: Test depuis PC
Ceci est un test
.
QUIT
```

- Sur la VM
```bash
sudo ls /home/test/Maildir/new
```

‎ 
## 4️⃣ Conteneurisation

### Conteneurisation du serveur web
- On creer un **docker-compose.yml** dans **/opt/dharibo-server**
```
version: '3.8'

services:
  web-server:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    volumes:
      # On pointe vers les dossiers réels sur votre machine
      - /etc/nginx/conf.d:/etc/nginx/conf.d:ro
      - /etc/nginx/certificate:/etc/nginx/certificate:ro
      - /var/www/dharibo.com/html:/usr/share/nginx/html:ro
    restart: always
```
- On stop nginx sur notre systeme car il y avait un probleme de port 80
```
sudo systemctl stop nginx
sudo systemctl disable nginx
```

- Modifie la ligne du fichier .conf
```
root /usr/share/nginx/html
```
- On start notre conteneur 
```
docker compose up -d
```

### Conteneurisation du serveur mail
- Création du **docker-compose.yml** dans **/opt/dharibo-mail**
```
services:
  mail-server:
    image: rockylinux:9
    container_name: mail_container
    hostname: mail.example.local
    ports:
      - "25:25"
      - "143:143"
    volumes:
      # Montage des fichiers de configuration
      - /etc/postfix/main.cf:/etc/postfix/main.cf:ro
      - /etc/dovecot/dovecot.conf:/etc/dovecot/dovecot.conf:ro
      - /etc/dovecot/conf.d/10-mail.conf:/etc/dovecot/conf.d/10-mail.conf:ro
      # Montage des données mails
      - /home/test/Maildir:/home/test/Maildir:rw
    command: >
      /bin/sh -c "dnf install -y postfix dovecot s-nail &&
      useradd test &&
      echo 'test:password' | chpasswd &&
      postfix start &&
      dovecot -F"
```
- On stop les services sur notre machine hote
```
sudo systemctl stop postfix dovecot
sudo systemctl disable postfix dovecot

sudo systemctl stop postfix
sudo systemctl disable postfix
```
- Démarrage de notre conteneur
```
docker compose up -d
```

‎ 
## 5️⃣ Automatisation


Pour cette partie vous devrez récupérer les fichier suivants :
- inventory.ini
- setup.yml


(Sur une VM)
- Créer une VM vierge avec RockyLinux 9
- Lui définir une carte HostOnly avec une adresse ip fixe
- Avoir un User en droit root


(Sur votre PC)
- assurer vous de pouvoir vous connecter en SSH a la VM créer
- installer ainsible
- donner l'acces si vous avez un mdp :
```
Votre système (PC),Commande à taper
Ubuntu / Debian / Kali / WSL (Windows) : sudo apt install sshpass
Rocky / Fedora / CentOS / RHEL : sudo dnf install sshpass
Mac (avec Homebrew) : brew install sshpass
```

- Faitent la commande suivande pour lancer l'automatisation : `ansible-playbook -i inventory.ini setup.yml`

Pour voir si les docker fonctionnent bien : `sudo docker ps -a`

‎ 
## 6️⃣ Surveillance

Afin de réaliser la surveillance, nous allons utilisé la dernière VM : **SUPERVISION**

Commencons par créer un fichier monitoring. `mkdir monitoring`

Créer les trois fichier suivants :

**docker-compose.yml** :
```
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - ./alert.rules.yml:/etc/prometheus/alert.rules.yml
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

  blackbox-exporter:
    image: prom/blackbox-exporter:latest
    container_name: blackbox-exporter
    ports:
      - "9115:9115"
```

**prometheus.yml**
```
global:
  scrape_interval: 15s

rule_files:
  - "alert.rules.yml"

scrape_configs:
  - job_name: 'serveurs_physiques'
    static_configs:
      - targets: ['192.168.56.20:9100']

  - job_name: 'site_web_https'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - http://192.168.56.20
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

**alert.rules.yml**
```
groups:
  - name: projet_alerts
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ALERTE : L'instance {{ $labels.instance }} est injoignable !"

      - alert: SiteWebHS
        expr: probe_success == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ALERTE : Le site web est inaccessible de l'extérieur !"

      - alert: DisquePresquePlein
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Attention : Moins de 10% d'espace libre sur {{ $labels.instance }}"
```

Sur **SERVEUR** ajouter le bloc suivant dans le fichier de configuration du docker du service web et relancer le.

```
services:
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
```

Ouvrir les ports :

```
sudo firewall-cmd --permanent --add-port=9100/tcp
sudo firewall-cmd --permanent --add-port=9100/udp
sudo firewall-cmd --reload

sudo firewall-cmd --list-ports
```

Relancer tous vos docker sur le **SERVEUR** et le **SUPERVISION** avec la commande suivante :

```
sudo docker compose up -d
```
