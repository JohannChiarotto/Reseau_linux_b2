#!/bin/bash

#############################################
# Script de sauvegarde multi-VMs personnalisable
# Version simplifiée avec personnalisation par VM
#############################################

# ═══════════════════════════════════════════════════════════════
#                    CONFIGURATION GÉNÉRALE
# ═══════════════════════════════════════════════════════════════

BACKUP_ROOT="$HOME/backup-data"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="$HOME/logs/backup-$(date +%Y-%m-%d).log"
EMAIL_DEST="torth232@gmail.com"  # ← CHANGEZ VOTRE EMAIL ICI
RETENTION_DAYS_LOCAL=7

# Configuration SSH (automatique)
SSH_USER="$(whoami)"
SSH_KEY="$HOME/.ssh/id_rsa"

# ═══════════════════════════════════════════════════════════════
#              CONFIGURATION DES VMs À SAUVEGARDER
# ═══════════════════════════════════════════════════════════════

# Définir vos VMs avec leurs IPs et les dossiers à sauvegarder
# Format: "nom_vm|ip|dossiers_séparés_par_virgule"

VMS_CONFIG=(
    # Exemple 1: VM Serveur - sauvegarde /home et /var/www
    "serveur|192.168.56.20|/home,/var/www"
    
    # Exemple 2: VM Firewall - sauvegarde /home et /etc
    "firewall|192.168.58.20|/home,/"
    
    # Exemple 3: VM Backup - sauvegarde uniquement /home
    "backup|192.168.57.20|/home"
)

# ═══════════════════════════════════════════════════════════════
#    ⚠️  MODIFICATION : Éditez VMS_CONFIG ci-dessus avec :
#    - Le nom de votre VM
#    - Son adresse IP
#    - Les dossiers à sauvegarder (séparés par des virgules)
# ═══════════════════════════════════════════════════════════════

# Créer les répertoires nécessaires
mkdir -p "${BACKUP_ROOT}"
mkdir -p "$(dirname "${LOG_FILE}")"

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Fonction d'envoi d'email
send_email() {
    local subject="$1"
    local body="$2"
    
    if command -v mail &> /dev/null; then
        echo "$body" | mail -s "$subject" "${EMAIL_DEST}" 2>/dev/null
        log "Email envoyé: $subject"
    else
        log "ATTENTION: Commande mail non disponible (pas grave)"
    fi
}

# Fonction de vérification de connectivité SSH
check_ssh_connectivity() {
    local vm_name="$1"
    local vm_ip="$2"
    
    log "Test de connexion SSH à ${vm_name} (${vm_ip})..."
    
    if timeout 5 ssh -i "${SSH_KEY}" -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "${SSH_USER}@${vm_ip}" "exit" 2>/dev/null; then
        log "✓ Connexion SSH OK pour ${vm_name}"
        return 0
    else
        log "✗ Échec connexion SSH pour ${vm_name}"
        return 1
    fi
}

# Fonction de vérification de rsync sur la VM distante
check_remote_rsync() {
    local vm_ip="$1"
    
    if ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${vm_ip}" "command -v rsync" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Fonction de sauvegarde d'une VM
backup_vm() {
    local vm_name="$1"
    local vm_ip="$2"
    local vm_dirs="$3"
    local vm_backup_dir="${BACKUP_ROOT}/${DATE}/${vm_name}"
    
    log "=========================================="
    log "Sauvegarde de ${vm_name} (${vm_ip})"
    log "Dossiers: ${vm_dirs}"
    log "=========================================="
    
    # Vérifier la connectivité
    if ! check_ssh_connectivity "${vm_name}" "${vm_ip}"; then
        log "✗ Impossible de se connecter à ${vm_name}, sauvegarde ignorée"
        return 1
    fi
    
    # Vérifier que rsync est installé sur la VM
    if ! check_remote_rsync "${vm_ip}"; then
        log "✗ rsync n'est pas installé sur ${vm_name}"
        log "   Installez-le avec: ssh ${SSH_USER}@${vm_ip} 'sudo dnf install -y rsync'"
        return 1
    fi
    
    # Créer le répertoire de destination
    mkdir -p "${vm_backup_dir}"
    
    local dir_error_count=0
    
    # Convertir la liste de dossiers en tableau
    IFS=',' read -ra DIRS <<< "$vm_dirs"
    
    # Sauvegarder chaque répertoire
    for SOURCE_DIR in "${DIRS[@]}"; do
        # Enlever les espaces
        SOURCE_DIR=$(echo "$SOURCE_DIR" | xargs)
        
        log "  → Sauvegarde de ${SOURCE_DIR} depuis ${vm_name}..."
        
        # Vérifier que le répertoire existe sur la VM
        if ! ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${vm_ip}" "test -d ${SOURCE_DIR}" 2>/dev/null; then
            log "  ⚠️  ${SOURCE_DIR} n'existe pas sur ${vm_name}, ignoré"
            continue
        fi
        
        # Nom du répertoire de destination
        DEST_NAME=$(echo "${SOURCE_DIR}" | tr '/' '_' | sed 's/^_//')
        DEST_PATH="${vm_backup_dir}/${DEST_NAME}"
        
        # Rsync via SSH
        if rsync -avz -e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no" \
            --delete \
            --exclude='*.log' \
            --exclude='**/cache/' \
            --exclude='**/cache/**' \
            --exclude='.cache' \
            --exclude='.cache/**' \
            --exclude='**/tmp/' \
            --exclude='**/temp/' \
            --timeout=300 \
            "${SSH_USER}@${vm_ip}:${SOURCE_DIR}/" "${DEST_PATH}/" >> "${LOG_FILE}" 2>&1; then
            log "  ✓ ${SOURCE_DIR} sauvegardé"
        else
            log "  ✗ Erreur sauvegarde ${SOURCE_DIR}"
            dir_error_count=$((dir_error_count + 1))
        fi
    done
    
    # Créer fichier de métadonnées pour cette VM
    cat > "${vm_backup_dir}/vm_info.txt" << EOF
VM: ${vm_name}
IP: ${vm_ip}
Date: ${DATE}
Répertoires: ${vm_dirs}
Taille: $(du -sh "${vm_backup_dir}" 2>/dev/null | cut -f1)
Erreurs: ${dir_error_count}
EOF
    
    local size=$(du -sh "${vm_backup_dir}" 2>/dev/null | cut -f1)
    log "Taille ${vm_name}: ${size}"
    
    return ${dir_error_count}
}

# Fonction de nettoyage local
cleanup_local_backups() {
    log "=========================================="
    log "Nettoyage local (>${RETENTION_DAYS_LOCAL} jours)"
    log "=========================================="
    
    if [ -d "${BACKUP_ROOT}" ]; then
        find "${BACKUP_ROOT}" -maxdepth 1 -type d -mtime +${RETENTION_DAYS_LOCAL} ! -path "${BACKUP_ROOT}" -exec rm -rf {} \; 2>/dev/null
        log "✓ Nettoyage local terminé"
    fi
}

# DÉBUT DU SCRIPT
log "=========================================="
log "DÉMARRAGE SAUVEGARDE MULTI-VMS"
log "Date: $(date '+%d/%m/%Y %H:%M:%S')"
log "Utilisateur: ${SSH_USER}"
log "Destination: ${BACKUP_ROOT}/${DATE}"
log "=========================================="

# Vérifier que rsync est installé localement
if ! command -v rsync &> /dev/null; then
    log "✗ ERREUR: rsync n'est pas installé sur cette machine"
    log "   Installez-le avec: sudo dnf install -y rsync"
    send_email "❌ Erreur sauvegarde multi-VMs" "rsync n'est pas installé localement"
    exit 1
fi

# Vérifier la clé SSH
if [ ! -f "${SSH_KEY}" ]; then
    log "⚠️  ATTENTION: Clé SSH non trouvée: ${SSH_KEY}"
    log "   Générez une clé avec: ssh-keygen -t rsa -b 4096 -f ${SSH_KEY}"
    log "   Puis copiez-la sur chaque VM: ssh-copy-id -i ${SSH_KEY} ${SSH_USER}@<VM_IP>"
fi

# Vérifier l'espace disque
AVAILABLE_SPACE=$(df -h "${HOME}" | awk 'NR==2 {print $4}')
log "💾 Espace disque disponible: ${AVAILABLE_SPACE}"

# Compteurs
TOTAL_VMS=0
FAILED_VMS=0
SUCCESS_VMS=0

# Tableau pour stocker les infos des VMs
declare -a VM_NAMES
declare -a VM_IPS
declare -a VM_DIRS

# Parser la configuration
for vm_config in "${VMS_CONFIG[@]}"; do
    IFS='|' read -r vm_name vm_ip vm_dirs <<< "$vm_config"
    VM_NAMES+=("$vm_name")
    VM_IPS+=("$vm_ip")
    VM_DIRS+=("$vm_dirs")
done

# Afficher la configuration
log "Configuration des VMs:"
for i in "${!VM_NAMES[@]}"; do
    log "  ${VM_NAMES[$i]} → ${VM_IPS[$i]} → ${VM_DIRS[$i]}"
done
log ""

# Sauvegarder chaque VM
for i in "${!VM_NAMES[@]}"; do
    vm_name="${VM_NAMES[$i]}"
    vm_ip="${VM_IPS[$i]}"
    vm_dirs="${VM_DIRS[$i]}"
    
    TOTAL_VMS=$((TOTAL_VMS + 1))
    
    if backup_vm "${vm_name}" "${vm_ip}" "${vm_dirs}"; then
        SUCCESS_VMS=$((SUCCESS_VMS + 1))
    else
        FAILED_VMS=$((FAILED_VMS + 1))
    fi
    
    log ""
done

# Créer un fichier récapitulatif global
BACKUP_DIR="${BACKUP_ROOT}/${DATE}"
if [ -d "${BACKUP_DIR}" ]; then
    cat > "${BACKUP_DIR}/backup_summary.txt" << EOF
========================================
RÉSUMÉ SAUVEGARDE MULTI-VMS
========================================
Date: ${DATE}
VMs traitées: ${TOTAL_VMS}
VMs réussies: ${SUCCESS_VMS}
VMs échouées: ${FAILED_VMS}
Taille totale: $(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)

VMs sauvegardées:
$(for i in "${!VM_NAMES[@]}"; do 
    echo "  - ${VM_NAMES[$i]} (${VM_IPS[$i]}) → ${VM_DIRS[$i]}"
done)
EOF
fi

log "=========================================="
log "RÉSUMÉ: ${TOTAL_VMS} VMs traitées"
log "  ✓ Réussies: ${SUCCESS_VMS}"
log "  ✗ Échouées: ${FAILED_VMS}"
if [ -d "${BACKUP_DIR}" ]; then
    log "Taille totale: $(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)"
fi
log "=========================================="

# Nettoyage
cleanup_local_backups

# Rapport final par email
if [ ${FAILED_VMS} -gt 0 ]; then
    STATUS_ICON="⚠️"
    STATUS_TEXT="AVEC ERREURS"
else
    STATUS_ICON="✅"
    STATUS_TEXT="SUCCÈS COMPLET"
fi

# Email de rapport
if command -v mail &> /dev/null && [ -d "${BACKUP_DIR}" ]; then
    cat << EOF | mail -s "${STATUS_ICON} Sauvegarde Multi-VMs - $(date '+%d/%m/%Y')" "${EMAIL_DEST}" 2>/dev/null
========================================================
      SAUVEGARDE MULTI-VMS - RAPPORT ${STATUS_TEXT}
========================================================

${STATUS_ICON} Statut global : ${STATUS_TEXT}
📅 Date : $(date '+%d/%m/%Y à %H:%M:%S')
🖥️  Machine : $(hostname)
👤 Utilisateur : ${SSH_USER}

--------------------------------------------------------
                  RÉSUMÉ DES VMS
--------------------------------------------------------

📊 Total VMs : ${TOTAL_VMS}
✅ VMs OK : ${SUCCESS_VMS}
❌ VMs échouées : ${FAILED_VMS}

VMs sauvegardées :
$(for i in "${!VM_NAMES[@]}"; do
    vm_name="${VM_NAMES[$i]}"
    vm_ip="${VM_IPS[$i]}"
    vm_dirs="${VM_DIRS[$i]}"
    if [ -d "${BACKUP_ROOT}/${DATE}/${vm_name}" ]; then
        size=$(du -sh "${BACKUP_ROOT}/${DATE}/${vm_name}" 2>/dev/null | cut -f1 || echo "N/A")
        echo "  • ${vm_name} (${vm_ip})"
        echo "    Dossiers: ${vm_dirs}"
        echo "    Taille: ${size}"
        echo ""
    else
        echo "  • ${vm_name} (${vm_ip}) - ÉCHEC"
        echo ""
    fi
done)

--------------------------------------------------------
               DÉTAILS SAUVEGARDE
--------------------------------------------------------

💾 Destination : ${BACKUP_DIR}
📊 Taille totale : $(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)
⏱️  Rétention : ${RETENTION_DAYS_LOCAL} jours

--------------------------------------------------------
                      LOGS
--------------------------------------------------------

📜 Log complet : ${LOG_FILE}

--------------------------------------------------------
                  RESTAURATION
--------------------------------------------------------

💡 Pour restaurer un fichier :
   cd ${BACKUP_DIR}/<vm_name>
   cp -r <fichier> /destination/

💡 Pour restaurer une VM complète :
   rsync -avz ${BACKUP_DIR}/<vm_name>/home/ ${SSH_USER}@<vm_ip>:/home/

========================================================
Message automatique - Système de sauvegarde multi-VMs
$(hostname) - $(date '+%Y')
========================================================
EOF
    
    log "Email de rapport envoyé"
fi

log "=========================================="
log "FIN DE LA SAUVEGARDE MULTI-VMS"
log "=========================================="

# Code de sortie
if [ ${FAILED_VMS} -gt 0 ]; then
    exit 1
else
    exit 0
fi
