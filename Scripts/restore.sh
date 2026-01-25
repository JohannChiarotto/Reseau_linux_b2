[theo@localhost restore]$ cat push-simple.sh 
#!/bin/bash

#############################################
# Script de restauration vers VM distante
# Avec notification email automatique
#############################################

BACKUP_DIR="$HOME/backup-data"
SSH_KEY="$HOME/.ssh/id_rsa"
EMAIL_DEST="torth232@gmail.com"  # ← CHANGEZ ICI

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction d'envoi d'email
send_email() {
    local status="$1"
    local details="$2"
    
    if ! command -v mail &> /dev/null; then
        echo -e "${YELLOW}⚠️  Commande mail non disponible, email non envoyé${NC}"
        return
    fi
    
    if [ "$status" = "success" ]; then
        local subject="✅ Restauration Réussie - $(date '+%d/%m/%Y %H:%M')"
    else
        local subject="❌ Échec Restauration - $(date '+%d/%m/%Y %H:%M')"
    fi
    
    echo "$details" | mail -s "$subject" "${EMAIL_DEST}"
    echo -e "${GREEN}📧 Email envoyé à ${EMAIL_DEST}${NC}"
}

# Paramètres
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   RESTAURATION VERS VM DISTANTE            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

read -p "IP de la VM destination : " target_ip
read -p "Nom de la VM à restaurer [vm1] : " vm_name
vm_name=${vm_name:-vm1}

# Trouver la dernière sauvegarde
latest=$(ls -1t "$BACKUP_DIR" 2>/dev/null | head -1)
backup_path="$BACKUP_DIR/$latest/$vm_name"

if [ ! -d "$backup_path" ]; then
    echo -e "${RED}❌ Sauvegarde non trouvée : $backup_path${NC}"
    
    # Email d'erreur
    send_email "error" "Erreur de restauration

Sauvegarde non trouvée : $backup_path
VM demandée : $vm_name
Destination : $target_ip

Date : $(date '+%d/%m/%Y à %H:%M:%S')
"
    exit 1
fi

backup_size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)

echo ""
echo -e "${YELLOW}═══════════════════════════════════════${NC}"
echo -e "📦 Sauvegarde : ${GREEN}$latest${NC}"
echo -e "🖥️  VM source : ${GREEN}$vm_name${NC} ($backup_size)"
echo -e "🎯 Destination : ${GREEN}$target_ip${NC}"
echo -e "📧 Email : ${GREEN}$EMAIL_DEST${NC}"
echo -e "${YELLOW}═══════════════════════════════════════${NC}"
echo ""
read -p "Continuer ? (o/N) " -r
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo -e "${YELLOW}Annulé${NC}"
    exit 0
fi

# Sauvegarder l'heure de début
start_time=$(date +%s)
start_date=$(date '+%d/%m/%Y à %H:%M:%S')

echo ""
echo -e "${BLUE}🔄 Transfert vers ${target_ip}...${NC}"
echo ""

# Étape 1 : Copier la sauvegarde dans /tmp sur la VM distante
if ! scp -r -i "$SSH_KEY" "$backup_path" theo@${target_ip}:/tmp/restore_temp/ 2>&1 | tail -5; then
    echo -e "${RED}❌ Erreur lors du transfert${NC}"
    
    send_email "error" "Erreur de restauration

Échec du transfert SCP vers $target_ip

Sauvegarde : $latest
VM : $vm_name
Date : $start_date
"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Transfert terminé${NC}"
echo ""

# Étape 2 : Sur la VM distante, restaurer avec sudo
echo -e "${BLUE}🔄 Restauration sur ${target_ip}...${NC}"
echo ""

# Capturer la sortie de la restauration
restore_output=$(ssh -i "$SSH_KEY" theo@${target_ip} bash << 'ENDSSH'
restored_dirs=()
failed_dirs=()

echo "🔄 Restauration en cours..."
echo ""

# Restaurer /home
if [ -d /tmp/restore_temp/home ]; then
    echo "→ /home"
    if sudo rsync -a /tmp/restore_temp/home/ /home/ 2>&1; then
        echo "  ✓ /home restauré"
        restored_dirs+=("/home")
    else
        echo "  ✗ Erreur /home"
        failed_dirs+=("/home")
    fi
fi

# Restaurer /root
if [ -d /tmp/restore_temp/root ]; then
    echo "→ /root"
    if sudo rsync -a /tmp/restore_temp/root/ /root/ 2>&1; then
        echo "  ✓ /root restauré"
        restored_dirs+=("/root")
    else
        echo "  ✗ Erreur /root"
        failed_dirs+=("/root")
    fi
fi

# Restaurer /etc
if [ -d /tmp/restore_temp/etc ]; then
    echo "→ /etc"
    if sudo rsync -a /tmp/restore_temp/etc/ /etc/ 2>&1; then
        echo "  ✓ /etc restauré"
        restored_dirs+=("/etc")
    else
        echo "  ✗ Erreur /etc"
        failed_dirs+=("/etc")
    fi
fi

# Restaurer /var/www
if [ -d /tmp/restore_temp/var_www ]; then
    echo "→ /var/www"
    sudo mkdir -p /var/www
    if sudo rsync -a /tmp/restore_temp/var_www/ /var/www/ 2>&1; then
        echo "  ✓ /var/www restauré"
        restored_dirs+=("/var/www")
    else
        echo "  ✗ Erreur /var/www"
        failed_dirs+=("/var/www")
    fi
fi

# Restaurer /var/lib
if [ -d /tmp/restore_temp/var_lib ]; then
    echo "→ /var/lib"
    if sudo rsync -a /tmp/restore_temp/var_lib/ /var/lib/ 2>&1; then
        echo "  ✓ /var/lib restauré"
        restored_dirs+=("/var/lib")
    else
        echo "  ✗ Erreur /var/lib"
        failed_dirs+=("/var/lib")
    fi
fi

# Restaurer /opt
if [ -d /tmp/restore_temp/opt ]; then
    echo "→ /opt"
    sudo mkdir -p /opt
    if sudo rsync -a /tmp/restore_temp/opt/ /opt/ 2>&1; then
        echo "  ✓ /opt restauré"
        restored_dirs+=("/opt")
    else
        echo "  ✗ Erreur /opt"
        failed_dirs+=("/opt")
    fi
fi

# Restaurer /usr/local
if [ -d /tmp/restore_temp/usr_local ]; then
    echo "→ /usr/local"
    if sudo rsync -a /tmp/restore_temp/usr_local/ /usr/local/ 2>&1; then
        echo "  ✓ /usr/local restauré"
        restored_dirs+=("/usr/local")
    else
        echo "  ✗ Erreur /usr/local"
        failed_dirs+=("/usr/local")
    fi
fi

# Restaurer /srv
if [ -d /tmp/restore_temp/srv ]; then
    echo "→ /srv"
    sudo mkdir -p /srv
    if sudo rsync -a /tmp/restore_temp/srv/ /srv/ 2>&1; then
        echo "  ✓ /srv restauré"
        restored_dirs+=("/srv")
    else
        echo "  ✗ Erreur /srv"
        failed_dirs+=("/srv")
    fi
fi

# Nettoyer
sudo rm -rf /tmp/restore_temp
echo ""
echo "  ✓ Nettoyage effectué"
echo ""

# Afficher le résumé
echo "RESTORED:${#restored_dirs[@]}"
echo "FAILED:${#failed_dirs[@]}"
for dir in "${restored_dirs[@]}"; do
    echo "OK:$dir"
done
for dir in "${failed_dirs[@]}"; do
    echo "FAIL:$dir"
done
ENDSSH
)

# Afficher la sortie
echo "$restore_output"

# Calculer la durée
end_time=$(date +%s)
duration=$((end_time - start_time))
duration_min=$((duration / 60))
duration_sec=$((duration % 60))

# Analyser les résultats
restored_count=$(echo "$restore_output" | grep "^RESTORED:" | cut -d: -f2)
failed_count=$(echo "$restore_output" | grep "^FAILED:" | cut -d: -f2)
restored_dirs=$(echo "$restore_output" | grep "^OK:" | cut -d: -f2 | tr '\n' ', ' | sed 's/,$//')
failed_dirs=$(echo "$restore_output" | grep "^FAIL:" | cut -d: -f2 | tr '\n' ', ' | sed 's/,$//')

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"

# Déterminer le statut
if [ "$failed_count" = "0" ]; then
    echo -e "${GREEN}✅ Restauration réussie !${NC}"
    status="success"
    status_text="SUCCÈS"
    status_icon="✅"
else
    echo -e "${YELLOW}⚠️  Restauration terminée avec erreurs${NC}"
    status="partial"
    status_text="AVEC ERREURS"
    status_icon="⚠️"
fi

echo -e "   Réussis : ${GREEN}$restored_count${NC}"
echo -e "   Échoués : ${RED}$failed_count${NC}"
echo -e "   Durée : ${duration_min}m ${duration_sec}s"
echo -e "${BLUE}═══════════════════════════════════════${NC}"

# Préparer l'email
email_body="========================================================
          RESTAURATION VERS VM DISTANTE
              RAPPORT ${status_text}
========================================================

${status_icon} Statut : ${status_text}
📅 Date début : ${start_date}
📅 Date fin : $(date '+%d/%m/%Y à %H:%M:%S')
⏱️  Durée : ${duration_min}m ${duration_sec}s

--------------------------------------------------------
                  INFORMATIONS
--------------------------------------------------------

📦 Sauvegarde : ${latest}
🖥️  VM source : ${vm_name}
💾 Taille : ${backup_size}
🎯 Destination : ${target_ip}
👤 Utilisateur : theo

--------------------------------------------------------
                   RÉSULTATS
--------------------------------------------------------

✅ Répertoires restaurés : ${restored_count}
❌ Répertoires échoués : ${failed_count}

Répertoires restaurés avec succès :
$(echo "$restore_output" | grep "^OK:" | cut -d: -f2 | sed 's/^/  • /')

$(if [ "$failed_count" != "0" ]; then
    echo "Répertoires échoués :"
    echo "$restore_output" | grep "^FAIL:" | cut -d: -f2 | sed 's/^/  • /'
fi)

--------------------------------------------------------
              VÉRIFICATION RECOMMANDÉE
--------------------------------------------------------

Connectez-vous à la VM pour vérifier :
  ssh theo@${target_ip}
  ls -lha ~/
  
Redémarrez les services si nécessaire :
  sudo systemctl restart httpd
  sudo systemctl restart nginx
  sudo systemctl restart mariadb

========================================================
Message automatique - Système de restauration
$(hostname) - $(date '+%Y')
========================================================
"

# Envoyer l'email
echo ""
send_email "$status" "$email_body"

echo ""
echo -e "${BLUE}✅ Processus terminé !${NC}"

# Code de sortie
if [ "$failed_count" = "0" ]; then
    exit 0
else
    exit 1
fi
