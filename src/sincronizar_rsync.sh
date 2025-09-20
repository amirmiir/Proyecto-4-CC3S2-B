#!/bin/bash
# Descripción: Sincronización y backup de artefactos con rsync
# Autor: Equipo 12
# Fecha: 2025-09-19

set -euo pipefail

# Colores para output
readonly COLOR_VERDE='\033[0;32m'
readonly COLOR_AMARILLO='\033[0;33m'
readonly COLOR_ROJO='\033[0;31m'
readonly COLOR_AZUL='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Variables configurables
readonly BACKUP_DIR="${BACKUP_DIR:-/tmp/backups}"
readonly LOG_DIR="${LOG_DIR:-/tmp/gestor-logs}"
readonly CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/gestor}"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)
readonly RSYNC_LOG="/tmp/rsync-${TIMESTAMP}.log"

# Crear directorios necesarios
mkdir -p "$BACKUP_DIR" "$BACKUP_DIR/logs" "$BACKUP_DIR/config" "$BACKUP_DIR/artefactos"

# Función para verificar disponibilidad de rsync
verificar_rsync() {
    if ! command -v rsync >/dev/null 2>&1; then
        echo -e "${COLOR_ROJO}Error: rsync no está instalado${COLOR_RESET}"
        echo "Instalar con:"
        echo "  Ubuntu/Debian: sudo apt-get install rsync"
        echo "  CentOS/RHEL:   sudo yum install rsync"
        echo "  macOS:         brew install rsync"
        exit 1
    fi

    # Mostrar versión de rsync
    local version=$(rsync --version | head -1)
    echo -e "${COLOR_VERDE}✓ $version${COLOR_RESET}"
}

# Función para backup de logs
backup_logs() {
    echo -e "${COLOR_AZUL}=== Backup de Logs ===${COLOR_RESET}"
    echo ""

    local origen="$LOG_DIR"
    local destino="$BACKUP_DIR/logs/backup-$TIMESTAMP"

    if [[ ! -d "$origen" ]]; then
        echo -e "${COLOR_AMARILLO}⚠ Directorio de logs no existe: $origen${COLOR_RESET}"
        return 1
    fi

    echo "Origen:  $origen"
    echo "Destino: $destino"
    echo ""

    # Opciones de rsync para logs
    # -a: archivo (preserva permisos, tiempos, etc)
    # -v: verbose
    # -h: human-readable (no disponible en macOS rsync)
    # --progress: muestra progreso
    # --stats: estadísticas al final
    rsync -av \
        --progress \
        --stats \
        --exclude='*.tmp' \
        --exclude='*.lock' \
        "$origen/" "$destino/" 2>&1 | tee -a "$RSYNC_LOG"

    # Comprimir backup antiguo si existe
    if [[ -d "$destino" ]]; then
        echo ""
        echo "Comprimiendo backup..."
        tar -czf "$destino.tar.gz" -C "$BACKUP_DIR/logs" "backup-$TIMESTAMP" 2>/dev/null
        rm -rf "$destino"
        echo -e "${COLOR_VERDE}✓ Backup comprimido: $destino.tar.gz${COLOR_RESET}"
    fi

    # Mostrar estadísticas
    echo ""
    echo "Estadísticas del backup:"
    du -sh "$BACKUP_DIR/logs/"* 2>/dev/null | tail -5
}

# Función para backup de configuración
backup_configuracion() {
    echo ""
    echo -e "${COLOR_AZUL}=== Backup de Configuración ===${COLOR_RESET}"
    echo ""

    # Lista de archivos de configuración a respaldar
    local archivos_config=(
        "$HOME/.env"
        "$HOME/.config/gestor/"
        "/etc/systemd/system/gestor-web.service"
        "$(dirname "$0")/../systemd/"
        "$(dirname "$0")/../.env"
        "$(dirname "$0")/../.env.example"
    )

    local destino="$BACKUP_DIR/config/backup-$TIMESTAMP"
    mkdir -p "$destino"

    echo "Archivos a respaldar:"
    for archivo in "${archivos_config[@]}"; do
        if [[ -e "$archivo" ]]; then
            echo -e "  ${COLOR_VERDE}✓${COLOR_RESET} $archivo"

            # Usar rsync para cada archivo/directorio
            rsync -av \
                --relative \
                --quiet \
                "$archivo" \
                "$destino/" 2>/dev/null || true
        else
            echo -e "  ${COLOR_AMARILLO}✗${COLOR_RESET} $archivo (no existe)"
        fi
    done

    # Crear archivo de metadatos
    cat > "$destino/metadata.txt" << EOF
Backup de Configuración
========================
Fecha: $(date)
Usuario: $(whoami)
Host: $(hostname)
Sistema: $(uname -a)
========================
EOF

    echo ""
    echo -e "${COLOR_VERDE}✓ Configuración respaldada en: $destino${COLOR_RESET}"
}

# Función para sincronización incremental
sincronizacion_incremental() {
    echo ""
    echo -e "${COLOR_AZUL}=== Sincronización Incremental ===${COLOR_RESET}"
    echo ""

    local origen="${1:-$LOG_DIR}"
    local destino="${2:-$BACKUP_DIR/incremental}"

    echo "Configuración:"
    echo "  Origen:  $origen"
    echo "  Destino: $destino"
    echo ""

    # Crear estructura de directorios
    mkdir -p "$destino"

    # Rsync incremental con hardlinks
    # --link-dest: crea hardlinks para archivos sin cambios
    local ultimo_backup=$(ls -1d "$destino"/backup-* 2>/dev/null | tail -1)

    if [[ -n "$ultimo_backup" ]]; then
        echo "Último backup: $ultimo_backup"
        echo "Creando backup incremental..."

        rsync -av \
            --delete \
            --link-dest="$ultimo_backup" \
            --exclude='*.tmp' \
            --exclude='*.pid' \
            "$origen/" \
            "$destino/backup-$TIMESTAMP/"
    else
        echo "Creando backup inicial completo..."

        rsync -av \
            --delete \
            --exclude='*.tmp' \
            --exclude='*.pid' \
            "$origen/" \
            "$destino/backup-$TIMESTAMP/"
    fi

    # Limpiar backups antiguos (mantener últimos 7)
    echo ""
    echo "Limpiando backups antiguos..."
    ls -1dt "$destino"/backup-* 2>/dev/null | tail -n +8 | xargs rm -rf 2>/dev/null || true

    echo -e "${COLOR_VERDE}✓ Sincronización incremental completada${COLOR_RESET}"
}

# Función para sincronización remota
sincronizacion_remota() {
    echo ""
    echo -e "${COLOR_AZUL}=== Sincronización Remota ===${COLOR_RESET}"
    echo ""

    local usuario="${1:-usuario}"
    local host="${2:-backup.ejemplo.com}"
    local origen="${3:-$LOG_DIR}"
    local destino="${4:-/backup/gestor}"

    echo "Configuración:"
    echo "  Usuario: $usuario"
    echo "  Host:    $host"
    echo "  Origen:  $origen"
    echo "  Destino: $destino"
    echo ""

    # Verificar conectividad SSH
    echo -n "Verificando conectividad SSH... "
    if ssh -o ConnectTimeout=5 "$usuario@$host" "echo ok" >/dev/null 2>&1; then
        echo -e "${COLOR_VERDE}OK${COLOR_RESET}"
    else
        echo -e "${COLOR_ROJO}FALLO${COLOR_RESET}"
        echo "No se puede conectar a $usuario@$host"
        return 1
    fi

    # Sincronización con rsync sobre SSH
    echo ""
    echo "Sincronizando archivos..."

    rsync -avz \
        --progress \
        --delete \
        --exclude='*.tmp' \
        --exclude='*.lock' \
        --exclude='*.pid' \
        -e "ssh -o StrictHostKeyChecking=no" \
        "$origen/" \
        "$usuario@$host:$destino/" || {
            echo -e "${COLOR_ROJO}Error en sincronización remota${COLOR_RESET}"
            return 1
        }

    echo -e "${COLOR_VERDE}✓ Sincronización remota completada${COLOR_RESET}"
}

# Función para restauración desde backup
restaurar_backup() {
    echo ""
    echo -e "${COLOR_AZUL}=== Restauración desde Backup ===${COLOR_RESET}"
    echo ""

    # Listar backups disponibles
    echo "Backups disponibles:"
    echo ""

    local backups=()
    local index=1

    # Buscar backups de logs
    for backup in "$BACKUP_DIR"/logs/backup-*.tar.gz; do
        if [[ -f "$backup" ]]; then
            backups+=("$backup")
            local size=$(du -h "$backup" | cut -f1)
            local date=$(basename "$backup" | sed 's/backup-//; s/.tar.gz//')
            echo "  $index) Logs - $date ($size)"
            ((index++))
        fi
    done

    # Buscar backups incrementales
    for backup in "$BACKUP_DIR"/incremental/backup-*; do
        if [[ -d "$backup" ]]; then
            backups+=("$backup")
            local size=$(du -sh "$backup" | cut -f1)
            local date=$(basename "$backup" | sed 's/backup-//')
            echo "  $index) Incremental - $date ($size)"
            ((index++))
        fi
    done

    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${COLOR_AMARILLO}No hay backups disponibles${COLOR_RESET}"
        return 1
    fi

    echo ""
    echo -n "Seleccionar backup para restaurar (1-${#backups[@]}): "
    read -r seleccion

    if [[ ! "$seleccion" =~ ^[0-9]+$ ]] || [[ $seleccion -lt 1 ]] || [[ $seleccion -gt ${#backups[@]} ]]; then
        echo -e "${COLOR_ROJO}Selección inválida${COLOR_RESET}"
        return 1
    fi

    local backup_seleccionado="${backups[$((seleccion-1))]}"
    local destino_restauracion="${LOG_DIR}-restaurado-$TIMESTAMP"

    echo ""
    echo "Restaurando: $backup_seleccionado"
    echo "Destino: $destino_restauracion"
    echo ""

    # Restaurar según el tipo de backup
    if [[ "$backup_seleccionado" == *.tar.gz ]]; then
        # Descomprimir y restaurar
        mkdir -p "$destino_restauracion"
        tar -xzf "$backup_seleccionado" -C "$destino_restauracion" --strip-components=2
    else
        # Copiar directorio
        rsync -av "$backup_seleccionado/" "$destino_restauracion/"
    fi

    echo -e "${COLOR_VERDE}✓ Backup restaurado en: $destino_restauracion${COLOR_RESET}"
}

# Función para mostrar estadísticas
mostrar_estadisticas() {
    echo ""
    echo -e "${COLOR_AZUL}=== Estadísticas de Backups ===${COLOR_RESET}"
    echo ""

    # Espacio usado
    echo "Uso de espacio:"
    echo "  Total: $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)"
    echo ""

    # Desglose por tipo
    echo "Por categoría:"
    for dir in logs config incremental artefactos; do
        if [[ -d "$BACKUP_DIR/$dir" ]]; then
            local size=$(du -sh "$BACKUP_DIR/$dir" 2>/dev/null | cut -f1)
            local count=$(find "$BACKUP_DIR/$dir" -maxdepth 1 -type f -o -type d | wc -l)
            printf "  %-15s: %s (%d items)\n" "$dir" "$size" "$((count-1))"
        fi
    done

    # Backups más recientes
    echo ""
    echo "Backups más recientes:"
    find "$BACKUP_DIR" -type f -name "*.tar.gz" -o -type d -name "backup-*" 2>/dev/null | \
        xargs ls -lht 2>/dev/null | head -5

    # Log de rsync
    if [[ -f "$RSYNC_LOG" ]]; then
        echo ""
        echo "Última actividad de rsync:"
        tail -5 "$RSYNC_LOG"
    fi
}

# Función principal
main() {
    local accion="${1:-ayuda}"
    shift || true

    echo -e "${COLOR_AZUL}╔══════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_AZUL}║    SINCRONIZACIÓN CON RSYNC             ║${COLOR_RESET}"
    echo -e "${COLOR_AZUL}╚══════════════════════════════════════════╝${COLOR_RESET}"
    echo ""

    # Verificar rsync
    verificar_rsync
    echo ""

    case "$accion" in
        logs)
            backup_logs
            ;;
        config)
            backup_configuracion
            ;;
        incremental)
            sincronizacion_incremental "$@"
            ;;
        remoto)
            sincronizacion_remota "$@"
            ;;
        restaurar)
            restaurar_backup
            ;;
        stats)
            mostrar_estadisticas
            ;;
        todo)
            backup_logs
            backup_configuracion
            sincronizacion_incremental
            mostrar_estadisticas
            ;;
        ayuda|*)
            echo "Uso: $0 [acción] [opciones]"
            echo ""
            echo "Acciones:"
            echo "  logs        - Backup de logs"
            echo "  config      - Backup de configuración"
            echo "  incremental - Sincronización incremental"
            echo "  remoto      - Sincronización remota"
            echo "  restaurar   - Restaurar desde backup"
            echo "  stats       - Mostrar estadísticas"
            echo "  todo        - Ejecutar backup completo"
            echo ""
            echo "Ejemplos:"
            echo "  $0 logs"
            echo "  $0 incremental /origen /destino"
            echo "  $0 remoto usuario servidor /origen /destino"
            [[ "$accion" != "ayuda" ]] && exit 1
            ;;
    esac

    echo ""
    echo -e "${COLOR_VERDE}=== Operación completada ===${COLOR_RESET}"
    echo "Log de rsync: $RSYNC_LOG"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi