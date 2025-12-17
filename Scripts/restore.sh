

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'#!/bin/bash


set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_DIR="/backup"
EMAIL_DEST="darribautheo33@example.com"


send_restore_email() {
    local status="$1"
    local details="$2"
    
    if ! command -v mail &> /dev/null; then
        return
    fi
    
    if [ "$status" = "success" ]; then
        cat << EOF | mail -s "✅ Restauration Réussie - $(hostname) - $(date '+%d/%m/%Y')" "${EMAIL_DEST}"
========================================================
        RESTAURATION SYSTÈME - RAPPORT DE SUCCÈS
========================================================

✅ Statut : RESTAURATION RÉUSSIE
📅 Date et heure : $(date '+%d/%m/%Y à %H:%M:%S')
🖥️  Serveur : $(hostname)
👤 Utilisateur : $(whoami)

--------------------------------------------------------
              DÉTAILS DE LA RESTAURATION
--------------------------------------------------------

${details}

--------------------------------------------------------
                     ATTENTION
--------------------------------------------------------

⚠️  Les fichiers ont été restaurés depuis la sauvegarde.
⚠️  Vérifiez que tout fonctionne correctement.

========================================================
Message automatique - Système de restauration
$(hostname) - $(date '+%Y')
========================================================
EOF
    else
        cat << EOF | mail -s "❌ Échec de Restauration - $(hostname) - $(date '+%d/%m/%Y')" "${EMAIL_DEST}"
========================================================
       RESTAURATION SYSTÈME - RAPPORT D'ÉCHEC
========================================================

❌ Statut : ÉCHEC
📅 Date et heure : $(date '+%d/%m/%Y à %H:%M:%S')
🖥️  Serveur : $(hostname)

--------------------------------------------------------
                       ERREUR
--------------------------------------------------------

${details}

========================================================
Message automatique - Système de restauration
$(hostname) - $(date '+%Y')
========================================================
EOF
    fi
}

show_help() {
    cat << EOF
${BLUE}=== Restauration de Sauvegarde ===${NC}

Usage: restore [fichier/dossier] [destination]

Exemples:
  restore /home/user/important.txt
  restore /home/user/important.txt /home/user/
  restore /var/www /var/www/

Sans paramètres: affiche un menu interactif

EOF
}

# Sélectionner une sauvegarde
select_backup() {
    echo -e "${BLUE}Sauvegardes disponibles:${NC}\n"
    local count=0
    local -a backups
    
    while IFS= read -r backup; do
        count=$((count + 1))
        backups+=("$backup")
        local size=$(du -sh "$BACKUP_DIR/$backup" 2>/dev/null | cut -f1)
        echo "[$count] $backup ($size)"
    done < <(ls -t1 "$BACKUP_DIR" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
    
    if [ $count -eq 0 ]; then
        echo -e "${RED}Aucune sauvegarde trouvée${NC}"
        exit 1
    fi
    
    echo ""
    read -p "Choisissez une sauvegarde (1-$count): " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
        echo -e "${RED}Choix invalide${NC}"
        exit 1
    fi
    
    SELECTED_BACKUP="${backups[$((choice - 1))]}"
    echo -e "${GREEN}✓ Sauvegarde sélectionnée: $SELECTED_BACKUP${NC}\n"
}

# Restaurer un fichier/dossier spécifique
restore_specific() {
    local file_path="$1"
    local destination="${2:-.}"
    
    # Normaliser le chemin (enlever le / en début s'il existe)
    file_path=$(echo "$file_path" | sed 's|^/||')
    
    if [ ! -d "$destination" ]; then
        echo -e "${RED}✗ Destination invalide: $destination${NC}"
        exit 1
    fi
    
    destination=$(cd "$destination" && pwd)
    local filename=$(basename "$file_path")
    
    # Chercher dans la sauvegarde la plus récente
    select_backup
    
    local source_path="$BACKUP_DIR/$SELECTED_BACKUP"
    local file_found=""
    
    # Chercher le fichier/dossier dans home ou var_www
    # home est stocké dans le dossier "home" de la sauvegarde
    if [ -e "$source_path/home/$file_path" ]; then
        file_found="$source_path/home/$file_path"
    # var/www est stocké dans le dossier "var_www" de la sauvegarde
    elif [ -e "$source_path/var_www/$file_path" ]; then
        file_found="$source_path/var_www/$file_path"
    else
        echo -e "${RED}✗ Fichier/dossier non trouvé dans la sauvegarde${NC}"
        echo ""
        echo "Chemins recherchés:"
        echo "  - $source_path/home/$file_path"
        echo "  - $source_path/var_www/$file_path"
        exit 1
    fi
    
    # Afficher infos
    echo -e "${GREEN}✓ Fichier trouvé${NC}"
    echo "  Source: $file_found"
    echo "  Destination: $destination/"
    echo ""
    
    read -p "Restaurer? (o/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        echo -e "${YELLOW}Annulé${NC}"
        exit 0
    fi
    
    # Restaurer
    if cp -rv "$file_found" "$destination/"; then
        echo -e "${GREEN}✓ Restauré avec succès vers: $destination/$(basename "$file_found")${NC}"
        
        # Envoyer email de succès
        send_restore_email "success" "📂 Fichier restauré : /$file_path
📍 Depuis la sauvegarde : $SELECTED_BACKUP
📥 Destination : $destination/$(basename "$file_found")
📊 Taille : $(du -sh "$file_found" | cut -f1)"
    else
        echo -e "${RED}✗ Erreur lors de la restauration${NC}"
        send_restore_email "error" "❌ Échec de la restauration du fichier : /$file_path"
        exit 1
    fi
}

# Restaurer tout
restore_all() {
    select_backup
    
    local source_path="$BACKUP_DIR/$SELECTED_BACKUP"
    
    echo -e "${YELLOW}⚠️  ATTENTION: Ceci va restaurer TOUS les fichiers${NC}"
    echo "  Source: $source_path"
    echo "  Vers: /"
    echo ""
    
    read -p "Continuer? (o/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        echo -e "${YELLOW}Annulé${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}Restauration en cours...${NC}\n"
    
    local restored_items=""
    
    # Restaurer home
    if [ -d "$source_path/home" ]; then
        echo "→ Restauration de /home"
        sudo rsync -av "$source_path/home/" /home/ 2>&1 | tail -10
        restored_items="${restored_items}   • /home\n"
    fi
    
    # Restaurer var_www
    if [ -d "$source_path/var_www" ]; then
        echo "→ Restauration de /var/www"
        sudo rsync -av "$source_path/var_www/" /var/www/ 2>&1 | tail -10
        restored_items="${restored_items}   • /var/www\n"
    fi
    
    echo -e "\n${GREEN}✓ Restauration terminée${NC}"
    
    # Envoyer email de succès
    send_restore_email "success" "📂 Répertoires restaurés :
${restored_items}
📍 Depuis la sauvegarde : $SELECTED_BACKUP
📥 Destination : Emplacements d'origine
⚠️  Type : Restauration COMPLÈTE"
}

# Programme principal
if [ $# -eq 0 ]; then
    echo -e "${BLUE}Menu de Restauration${NC}\n"
    echo "1) Restaurer un fichier/dossier spécifique"
    echo "2) Restaurer tout"
    echo "3) Quitter"
    echo ""
    read -p "Votre choix (1-3): " choice
    
    case "$choice" in
        1) 
            read -p "Chemin du fichier/dossier: " file
            read -p "Destination (défaut: courant): " dest
            restore_specific "$file" "$dest"
            ;;
        2)
            restore_all
            ;;
        3)
            exit 0
            ;;
        *)
            echo -e "${RED}Choix invalide${NC}"
            exit 1
            ;;
    esac
else
    case "$1" in
        --help|-h)
            show_help
            ;;
        *)
            restore_specific "$1" "$2"
            ;;
    esac
fi

NC='\033[0m'

# Configuration
BACKUP_DIR="/backup"
EMAIL_DEST="darribautheo33@example.com"

# Fonction d'envoi d'email
send_restore_email() {
    local status="$1"
    local details="$2"
    
    if ! command -v mail &> /dev/null; then
        return
    fi
    
    if [ "$status" = "success" ]; then
        cat << EOF | mail -s "✅ Restauration Réussie - $(hostname) - $(date '+%d/%m/%Y')" "${EMAIL_DEST}"
========================================================
        RESTAURATION SYSTÈME - RAPPORT DE SUCCÈS
========================================================

✅ Statut : RESTAURATION RÉUSSIE
📅 Date et heure : $(date '+%d/%m/%Y à %H:%M:%S')
🖥️  Serveur : $(hostname)
👤 Utilisateur : $(whoami)

--------------------------------------------------------
              DÉTAILS DE LA RESTAURATION
--------------------------------------------------------

${details}

--------------------------------------------------------
                     ATTENTION
--------------------------------------------------------

⚠️  Les fichiers ont été restaurés depuis la sauvegarde.
⚠️  Vérifiez que tout fonctionne correctement.

========================================================
Message automatique - Système de restauration
$(hostname) - $(date '+%Y')
========================================================
EOF
    else
        cat << EOF | mail -s "❌ Échec de Restauration - $(hostname) - $(date '+%d/%m/%Y')" "${EMAIL_DEST}"
========================================================
       RESTAURATION SYSTÈME - RAPPORT D'ÉCHEC
========================================================

❌ Statut : ÉCHEC
📅 Date et heure : $(date '+%d/%m/%Y à %H:%M:%S')
🖥️  Serveur : $(hostname)

--------------------------------------------------------
                       ERREUR
--------------------------------------------------------

${details}

========================================================
Message automatique - Système de restauration
$(hostname) - $(date '+%Y')
========================================================
EOF
    fi
}

show_help() {
    cat << EOF
${BLUE}=== Restauration de Sauvegarde ===${NC}

Usage: restore [fichier/dossier] [destination]

Exemples:
  restore /home/user/important.txt
  restore /home/user/important.txt /home/user/
  restore /var/www /var/www/

Sans paramètres: affiche un menu interactif

EOF
}

# Sélectionner une sauvegarde
select_backup() {
    echo -e "${BLUE}Sauvegardes disponibles:${NC}\n"
    local count=0
    local -a backups
    
    while IFS= read -r backup; do
        count=$((count + 1))
        backups+=("$backup")
        local size=$(du -sh "$BACKUP_DIR/$backup" 2>/dev/null | cut -f1)
        echo "[$count] $backup ($size)"
    done < <(ls -t1 "$BACKUP_DIR" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
    
    if [ $count -eq 0 ]; then
        echo -e "${RED}Aucune sauvegarde trouvée${NC}"
        exit 1
    fi
    
    echo ""
    read -p "Choisissez une sauvegarde (1-$count): " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
        echo -e "${RED}Choix invalide${NC}"
        exit 1
    fi
    
    SELECTED_BACKUP="${backups[$((choice - 1))]}"
    echo -e "${GREEN}✓ Sauvegarde sélectionnée: $SELECTED_BACKUP${NC}\n"
}

# Restaurer un fichier/dossier spécifique
restore_specific() {
    local file_path="$1"
    local destination="${2:-.}"
    
    # Normaliser le chemin (enlever le / en début s'il existe)
    file_path=$(echo "$file_path" | sed 's|^/||')
    
    if [ ! -d "$destination" ]; then
        echo -e "${RED}✗ Destination invalide: $destination${NC}"
        exit 1
    fi
    
    destination=$(cd "$destination" && pwd)
    local filename=$(basename "$file_path")
    
    # Chercher dans la sauvegarde la plus récente
    select_backup
    
    local source_path="$BACKUP_DIR/$SELECTED_BACKUP"
    local file_found=""
    
    # Chercher le fichier/dossier dans home ou var_www
    # home est stocké dans le dossier "home" de la sauvegarde
    if [ -e "$source_path/home/$file_path" ]; then
        file_found="$source_path/home/$file_path"
    # var/www est stocké dans le dossier "var_www" de la sauvegarde
    elif [ -e "$source_path/var_www/$file_path" ]; then
        file_found="$source_path/var_www/$file_path"
    else
        echo -e "${RED}✗ Fichier/dossier non trouvé dans la sauvegarde${NC}"
        echo ""
        echo "Chemins recherchés:"
        echo "  - $source_path/home/$file_path"
        echo "  - $source_path/var_www/$file_path"
        exit 1
    fi
    
    # Afficher infos
    echo -e "${GREEN}✓ Fichier trouvé${NC}"
    echo "  Source: $file_found"
    echo "  Destination: $destination/"
    echo ""
    
    read -p "Restaurer? (o/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        echo -e "${YELLOW}Annulé${NC}"
        exit 0
    fi
    
    # Restaurer
    if cp -rv "$file_found" "$destination/"; then
        echo -e "${GREEN}✓ Restauré avec succès vers: $destination/$(basename "$file_found")${NC}"
        
        # Envoyer email de succès
        send_restore_email "success" "📂 Fichier restauré : /$file_path
📍 Depuis la sauvegarde : $SELECTED_BACKUP
📥 Destination : $destination/$(basename "$file_found")
📊 Taille : $(du -sh "$file_found" | cut -f1)"
    else
        echo -e "${RED}✗ Erreur lors de la restauration${NC}"
        send_restore_email "error" "❌ Échec de la restauration du fichier : /$file_path"
        exit 1
    fi
}

# Restaurer tout
restore_all() {
    select_backup
    
    local source_path="$BACKUP_DIR/$SELECTED_BACKUP"
    
    echo -e "${YELLOW}⚠️  ATTENTION: Ceci va restaurer TOUS les fichiers${NC}"
    echo "  Source: $source_path"
    echo "  Vers: /"
    echo ""
    
    read -p "Continuer? (o/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        echo -e "${YELLOW}Annulé${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}Restauration en cours...${NC}\n"
    
    local restored_items=""
    
    # Restaurer home
    if [ -d "$source_path/home" ]; then
        echo "→ Restauration de /home"
        sudo rsync -av "$source_path/home/" /home/ 2>&1 | tail -10
        restored_items="${restored_items}   • /home\n"
    fi
    
    # Restaurer var_www
    if [ -d "$source_path/var_www" ]; then
        echo "→ Restauration de /var/www"
        sudo rsync -av "$source_path/var_www/" /var/www/ 2>&1 | tail -10
        restored_items="${restored_items}   • /var/www\n"
    fi
    
    echo -e "\n${GREEN}✓ Restauration terminée${NC}"
    
    # Envoyer email de succès
    send_restore_email "success" "📂 Répertoires restaurés :
${restored_items}
📍 Depuis la sauvegarde : $SELECTED_BACKUP
📥 Destination : Emplacements d'origine
⚠️  Type : Restauration COMPLÈTE"
}

# Programme principal
if [ $# -eq 0 ]; then
    echo -e "${BLUE}Menu de Restauration${NC}\n"
    echo "1) Restaurer un fichier/dossier spécifique"
    echo "2) Restaurer tout"
    echo "3) Quitter"
    echo ""
    read -p "Votre choix (1-3): " choice
    
    case "$choice" in
        1) 
            read -p "Chemin du fichier/dossier: " file
            read -p "Destination (défaut: courant): " dest
            restore_specific "$file" "$dest"
            ;;
        2)
            restore_all
            ;;
        3)
            exit 0
            ;;
        *)
            echo -e "${RED}Choix invalide${NC}"
            exit 1
            ;;
    esac
else
    case "$1" in
        --help|-h)
            show_help
            ;;
        *)
            restore_specific "$1" "$2"
            ;;
    esac
fi
