#!/bin/bash

#############################################
# Script de sauvegarde multi-VMs + Cloud
# Version avec Rclone intégré
#############################################

# ═══════════════════════════════════════════════════════════════
#                     CONFIGURATION GÉNÉRALE
# ═══════════════════════════════════════════════════════════════

BACKUP_ROOT="$HOME/backup-data"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="$HOME/logs/backup-$(date +%Y-%m-%d).log"
EMAIL_DEST="torth232@gmail.com"  # ← CHANGEZ VOTRE EMAIL ICI
RETENTION_DAYS_LOCAL=7

# Configuration SSH (automatique)
SSH_USER="$(whoami)"
SSH_KEY="$HOME/.ssh/id_rsa"

# Configuration Cloud (Rclone)
# ⚠️ IMPORTANT : Remplacez "mon_drive" par le nom configuré dans 'rclone config'
RCLONE_REMOTE="gdrive"       
CLOUD_DIR="Backups"      # Dossier de destination sur le Cloud

# ═══════════════════════════════════════════════════════════════
#               CONFIGURATION DES VMs À SAUVEGARDER
# ═══════════════════════════════════════════════════════════════

# Format: "nom_vm|ip|dossiers_séparés_par_virgule"
VMS_CONFIG=(
    # Exemple 1: VM Serveur
    "serveur|192.168.56.20|/home,/var/www"
    
    # Exemple 2: VM Firewall
    "firewall|192.168.58.10|/home"
    
    # Exemple 3: VM Backup
    "backup|192.168.57.20|/home"
)

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

# Fonction de sauvegarde d'une VM (Locale)
backup_vm() {
    local vm_name="$1"
    local vm_ip="$2"
    local vm_dirs="$3"
    local vm_backup_dir="${BACKUP_ROOT}/${DATE}/${vm_name}"
    
    log "------------------------------------------"
    log "Sauvegarde LOCALE de ${vm_name} (${vm_ip})"
    log "------------------------------------------"
    
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
        SOURCE_DIR=$(echo "$SOURCE_DIR" | xargs) # Enlever les espaces
        
        log "  → Récupération de ${SOURCE_DIR}..."
        
        # Vérifier que le répertoire existe sur la VM
        if ! ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no "${SSH_USER}@${vm_ip}" "test -d ${SOURCE_DIR}" 2>/dev/null; then
            log "  ⚠️  ${SOURCE_DIR} n'existe pas sur ${vm_name}, ignoré"
            continue
        fi
        
        # Nom du répertoire de destination (aplatir le chemin)
        DEST_NAME=$(echo "${SOURCE_DIR}" | tr '/' '_' | sed 's/^_//')
        DEST_PATH="${vm_backup_dir}/${DEST_NAME}"
        
        # Rsync via SSH
        if rsync -avz -e "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no" \
            --delete \
            --exclude='*.log' \
            --exclude='**/cache/' \
            --exclude='.cache' \
            --timeout=300 \
            "${SSH_USER}@${vm_ip}:${SOURCE_DIR}/" "${DEST_PATH}/" >> "${LOG_FILE}" 2>&1; then
            log "  ✓ ${SOURCE_DIR} sauvegardé"
        else
            log "  ✗ Erreur sauvegarde ${SOURCE_DIR}"
            dir_error_count=$((dir_error_count + 1))
        fi
    done
    
    # Métadonnées
    local size=$(du -sh "${vm_backup_dir}" 2>/dev/null | cut -f1)
    echo "VM: ${vm_name} | IP: ${vm_ip} | Date: ${DATE} | Taille: ${size}" > "${vm_backup_dir}/vm_info.txt"
    log "Terminé pour ${vm_name}. Taille: ${size}"
    
    return ${dir_error_count}
}

# Fonction d'envoi vers le Cloud (Rclone)
upload_to_cloud() {
    local source_dir="$1"
    local dest_dir="${CLOUD_DIR}/$(basename "${source_dir}")"

    log "=========================================="
    log "☁️  DÉBUT DU TRANSFERT CLOUD (${RCLONE_REMOTE})"
    log "=========================================="

    # Vérifier rclone
    if ! command -v rclone &> /dev/null; then
        log "✗ ERREUR: rclone n'est pas installé."
        return 1
    fi

    # Vérifier la configuration rclone
    if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:"; then
        log "✗ ERREUR: Remote rclone '${RCLONE_REMOTE}' introuvable."
        log "  Vérifiez la variable RCLONE_REMOTE en haut du script."
        return 1
    fi

    log "Envoi en cours vers ${RCLONE_REMOTE}:${dest_dir}..."

    # Copie vers le cloud
    if rclone copy "${source_dir}" "${RCLONE_REMOTE}:${dest_dir}" \
        --transfers=4 \
        --checkers=8 \
        --stats-one-line \
        --log-file="${LOG_FILE}" \
        --log-level=INFO; then
        
        log "✓ Transfert Cloud réussi !"
        return 0
    else
        log "✗ Échec du transfert Cloud."
        return 1
    fi
}

# Fonction de nettoyage local
cleanup_local_backups() {
    log "Nettoyage local (>${RETENTION_DAYS_LOCAL} jours)..."
    if [ -d "${BACKUP_ROOT}" ]; then
        find "${BACKUP_ROOT}" -maxdepth 1 -type d -mtime +${RETENTION_DAYS_LOCAL} ! -path "${BACKUP_ROOT}" -exec rm -rf {} \; 2>/dev/null
        log "✓ Nettoyage local terminé"
    fi
}

# ===============================================================
#                        DÉBUT DU SCRIPT
# ===============================================================
log "=========================================="
log "DÉMARRAGE SAUVEGARDE MULTI-VMS + CLOUD"
log "Date: $(date '+%d/%m/%Y %H:%M:%S')"
log "Destination Locale: ${BACKUP_ROOT}/${DATE}"
log "Destination Cloud: ${RCLONE_REMOTE}:${CLOUD_DIR}"
log "=========================================="

# 1. Vérifications pré-requises
if ! command -v rsync &> /dev/null; then
    log "✗ ERREUR: rsync absent."
    exit 1
fi

if [ ! -f "${SSH_KEY}" ]; then
    log "⚠️  ATTENTION: Clé SSH non trouvée: ${SSH_KEY}"
fi

# 2. Initialisation des compteurs
TOTAL_VMS=0
FAILED_VMS=0
SUCCESS_VMS=0
CLOUD_STATUS="Non tenté"
CLOUD_ICON="⚪"

# Tableaux de config
declare -a VM_NAMES
declare -a VM_IPS
declare -a VM_DIRS

for vm_config in "${VMS_CONFIG[@]}"; do
    IFS='|' read -r vm_name vm_ip vm_dirs <<< "$vm_config"
    VM_NAMES+=("$vm_name")
    VM_IPS+=("$vm_ip")
    VM_DIRS+=("$vm_dirs")
done

# 3. Boucle de sauvegarde LOCALE
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
done

BACKUP_DIR="${BACKUP_ROOT}/${DATE}"

# 4. Envoi vers le CLOUD
if [ ${SUCCESS_VMS} -gt 0 ] && [ -d "${BACKUP_DIR}" ]; then
    if upload_to_cloud "${BACKUP_DIR}"; then
        CLOUD_STATUS="SUCCÈS"
        CLOUD_ICON="✅"
    else
        CLOUD_STATUS="ÉCHEC"
        CLOUD_ICON="❌"
        FAILED_VMS=$((FAILED_VMS + 1)) # On compte l'échec cloud comme une erreur globale
    fi
else
    log "Aucune sauvegarde locale réussie, saut de l'étape Cloud."
    CLOUD_STATUS="ANNULÉ (Pas de données)"
    CLOUD_ICON="⚠️"
fi

# 5. Résumé et Rapport
log "=========================================="
log "RÉSUMÉ FINAL"
log "  VMs: ${SUCCESS_VMS}/${TOTAL_VMS} OK"
log "  Cloud: ${CLOUD_STATUS}"
if [ -d "${BACKUP_DIR}" ]; then
    log "  Taille: $(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)"
fi
log "=========================================="

# Nettoyage
cleanup_local_backups

# Définition du statut global pour l'email
if [ ${FAILED_VMS} -gt 0 ] || [ "${CLOUD_ICON}" == "❌" ]; then
    GLOBAL_ICON="⚠️"
    GLOBAL_TEXT="AVEC ERREURS"
else
    GLOBAL_ICON="✅"
    GLOBAL_TEXT="SUCCÈS COMPLET"
fi

# Envoi de l'email
if command -v mail &> /dev/null; then
    cat << EOF | mail -s "${GLOBAL_ICON} Backup - ${GLOBAL_TEXT} - $(date '+%d/%m')" "${EMAIL_DEST}" 2>/dev/null
========================================================
       RAPPORT DE SAUVEGARDE (LOCAL + CLOUD)
========================================================

${GLOBAL_ICON} Statut Global : ${GLOBAL_TEXT}
📅 Date : $(date '+%d/%m/%Y à %H:%M:%S')

--------------------------------------------------------
☁️  ÉTAT CLOUD (${RCLONE_REMOTE})
--------------------------------------------------------
Statut : ${CLOUD_ICON} ${CLOUD_STATUS}
Destination : ${CLOUD_DIR}/$(basename "${BACKUP_DIR}")

--------------------------------------------------------
🖥️  ÉTAT VMS (LOCAL)
--------------------------------------------------------
📊 Total VMs : ${TOTAL_VMS}
✅ Réussies : ${SUCCESS_VMS}
❌ Échouées : ${FAILED_VMS}

Détails :
$(for i in "${!VM_NAMES[@]}"; do
    vm_name="${VM_NAMES[$i]}"
    if [ -d "${BACKUP_DIR}/${vm_name}" ]; then
        size=$(du -sh "${BACKUP_DIR}/${vm_name}" 2>/dev/null | cut -f1)
        echo "  • ${vm_name} : OK (${size})"
    else
        echo "  • ${vm_name} : ÉCHEC ❌"
    fi
done)

--------------------------------------------------------
💾 STOCKAGE LOCAL
--------------------------------------------------------
Dossier : ${BACKUP_DIR}
Taille Totale : $(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)
Espace Libre Disque : $(df -h "${HOME}" | awk 'NR==2 {print $4}')

--------------------------------------------------------
ℹ️  LOGS
--------------------------------------------------------
Fichier log : ${LOG_FILE}

========================================================
$(hostname) - Système de Sauvegarde Automatique
========================================================
EOF
    log "Email de rapport envoyé."
fi

log "FIN DU SCRIPT"
exit 0
