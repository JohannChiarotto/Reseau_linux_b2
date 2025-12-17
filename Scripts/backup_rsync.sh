#!/bin/bash

#############################################
# Script de sauvegarde avec rsync
# Sauvegarde /home et /var/www
# Rotation sur 7 jours
#############################################

# Configuration
BACKUP_ROOT="/backup"
SOURCE_DIRS=("/home" "/var/www")
DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="${BACKUP_ROOT}/${DATE}"
LOG_FILE="/var/log/backup_rsync.log"
EMAIL_DEST="admin@example.com"  # a remplacer avec votre adresse mail 
RETENTION_DAYS=7

# Créer le répertoire de backup
mkdir -p "${BACKUP_DIR}"

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Fonction d'envoi d'email en cas d'erreur
send_error_email() {
    local error_msg="$1"
    log "ERREUR: ${error_msg}"
    
    # Vérifier si mail/mailx est disponible
    if command -v mail &> /dev/null; then
        echo "Erreur lors de la sauvegarde du $(date)

Détails de l'erreur:
${error_msg}

Consultez le fichier de log: ${LOG_FILE}" | \
        mail -s "❌ Erreur de sauvegarde - $(hostname)" "${EMAIL_DEST}"
    else
        log "ATTENTION: Impossible d'envoyer l'email (commande mail non disponible)"
    fi
}

# Fonction de nettoyage des anciennes sauvegardes
cleanup_old_backups() {
    log "Nettoyage des sauvegardes de plus de ${RETENTION_DAYS} jours..."
    
    if [ -d "${BACKUP_ROOT}" ]; then
        find "${BACKUP_ROOT}" -maxdepth 1 -type d -mtime +${RETENTION_DAYS} ! -path "${BACKUP_ROOT}" -exec rm -rf {} \; 2>/dev/null
        log "Nettoyage terminé"
    fi
}

# Vérifier que rsync est installé
if ! command -v rsync &> /dev/null; then
    send_error_email "rsync n'est pas installé sur le système"
    exit 1
fi

# Vérifier l'espace disque disponible
AVAILABLE_SPACE=$(df -BG "${BACKUP_ROOT}" | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "${AVAILABLE_SPACE}" -lt 10 ]; then
    send_error_email "Espace disque insuffisant: ${AVAILABLE_SPACE}G disponible"
    exit 1
fi

log "=========================================="
log "Début de la sauvegarde"
log "Destination: ${BACKUP_DIR}"
log "=========================================="

# Compteur d'erreurs
ERROR_COUNT=0

# Sauvegarder chaque répertoire source
for SOURCE in "${SOURCE_DIRS[@]}"; do
    if [ ! -d "${SOURCE}" ]; then
        log "ATTENTION: Le répertoire ${SOURCE} n'existe pas, ignoré"
        continue
    fi
    
    log "Sauvegarde de ${SOURCE}..."
    
    # Nom du répertoire de destination
    DEST_NAME=$(echo "${SOURCE}" | tr '/' '_' | sed 's/^_//')
    DEST_PATH="${BACKUP_DIR}/${DEST_NAME}"
    
    # Exécuter rsync avec exclusions
    rsync -avh \
        --delete \
        --exclude='*.log' \
        --exclude='**/cache/' \
        --exclude='**/cache/**' \
        --exclude='.cache' \
        --exclude='.cache/**' \
        --stats \
        "${SOURCE}/" "${DEST_PATH}/" 2>&1 | tee -a "${LOG_FILE}"
    
    # Vérifier le code de retour
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log "✓ ${SOURCE} sauvegardé avec succès"
    else
        log "✗ Erreur lors de la sauvegarde de ${SOURCE}"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
done

# Créer un fichier de métadonnées
cat > "${BACKUP_DIR}/backup_info.txt" << EOF
Date de sauvegarde: ${DATE}
Hostname: $(hostname)
Répertoires sauvegardés: ${SOURCE_DIRS[@]}
Taille totale: $(du -sh "${BACKUP_DIR}" | cut -f1)
EOF

log "=========================================="
log "Sauvegarde terminée"
log "Taille totale: $(du -sh "${BACKUP_DIR}" | cut -f1)"
log "=========================================="

# Nettoyage des anciennes sauvegardes
cleanup_old_backups

# Envoyer un email selon le résultat
if [ ${ERROR_COUNT} -gt 0 ]; then
    send_error_email "${ERROR_COUNT} erreur(s) détectée(s) lors de la sauvegarde. Consultez ${LOG_FILE} pour plus de détails."
    exit 1
else
    log "Sauvegarde réussie sans erreur"
    
    # Email de confirmation systématique
    if command -v mail &> /dev/null; then
        BACKUP_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)
        TOTAL_BACKUPS=$(ls -1 "${BACKUP_ROOT}" | wc -l)
        
        echo "✅ Sauvegarde terminée avec succès

📅 Date: $(date '+%d/%m/%Y à %H:%M:%S')
🖥️  Serveur: $(hostname)
📂 Répertoires sauvegardés: ${SOURCE_DIRS[@]}
💾 Destination: ${BACKUP_DIR}
📊 Taille de cette sauvegarde: ${BACKUP_SIZE}
🗄️  Nombre total de sauvegardes: ${TOTAL_BACKUPS}
📜 Consultez le log: ${LOG_FILE}

---
Sauvegardes conservées (${RETENTION_DAYS} jours):
$(ls -1t "${BACKUP_ROOT}" | head -n 5)" | \
        mail -s "✅ Sauvegarde réussie - $(hostname)" "${EMAIL_DEST}"
        
        log "Email de confirmation envoyé à ${EMAIL_DEST}"
    else
        log "ATTENTION: Impossible d'envoyer l'email de confirmation (commande mail non disponible)"
    fi
fi

exit 0