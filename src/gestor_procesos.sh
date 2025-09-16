#!/bin/bash
# Descripción: Gestor de procesos seguros con enfoque en redes

set -euo pipefail
IFS=$'\n\t'

# VARIABLES GLOBALES Y CONFIGURACIÓN

# Directorio del script
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Guardar variables pasadas por línea de comandos
_CMD_PORT="${PORT:-}"
_CMD_MESSAGE="${MESSAGE:-}"
_CMD_RELEASE="${RELEASE:-}"

# Cargar variables de entorno desde archivo .env si existe
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    echo "[INFO] Cargando variables desde .env"
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
elif [[ -f "$PROJECT_ROOT/.env.example" ]]; then
    echo "[WARN] No se encontró .env, usando valores por defecto de .env.example"
fi

# Variables de entorno con prioridad: línea de comandos > .env > defecto
readonly PORT="${_CMD_PORT:-${PORT:-8080}}"
readonly MESSAGE="${_CMD_MESSAGE:-${MESSAGE:-Servidor activo}}"
readonly RELEASE="${_CMD_RELEASE:-${RELEASE:-v1.0.0}}"

# Directorios configurables
readonly LOG_DIR="${LOG_DIR:-/tmp/gestor-logs}"
readonly PID_DIR="${PID_DIR:-/tmp}"

# Archivos de control
readonly PID_FILE="${PID_DIR}/gestor-web.pid"
readonly LOG_FILE="${LOG_DIR}/gestor-web-$(date +%Y%m%d).log"

# Códigos de salida específicos
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1
readonly EXIT_ERROR_PERMISOS=2
readonly EXIT_ERROR_PROCESO=3
readonly EXIT_ERROR_RED=4
readonly EXIT_ERROR_CONFIGURACION=5
readonly EXIT_ERROR_SIGNAL=6
readonly EXIT_ERROR_TIMEOUT=7
readonly EXIT_ERROR_DEPENDENCIA=8
readonly EXIT_ERROR_VALIDACION=9

# FUNCIONES DE GESTIÓN DE PROCESOS

# Función para iniciar el proceso
iniciar_proceso() {
    echo "[INFO] Iniciando proceso en puerto $PORT..."

    # Verificar si el archivo PID existe
    if [[ -f "$PID_FILE" ]]; then
        echo "[ERROR] El proceso ya está en ejecución"
        return $EXIT_ERROR_PROCESO
    fi

    # Crear directorio de logs si no existe
    [[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"

    # Simular inicio de proceso (se implementará completamente en Sprint 2)
    echo "$$" > "$PID_FILE"
    echo "[INFO] Proceso iniciado con PID $$ en puerto $PORT"
    echo "[INFO] Logs en: $LOG_FILE"

    return $EXIT_SUCCESS
}

# Función para detener el proceso
detener_proceso() {
    echo "[INFO] Deteniendo proceso..."

    # Verificar si el archivo PID existe
    if [[ ! -f "$PID_FILE" ]]; then
        echo "[WARN] No hay proceso activo para detener"
        return $EXIT_SUCCESS
    fi

    # Leer PID y eliminar archivo
    local pid=$(cat "$PID_FILE")
    rm -f "$PID_FILE"

    echo "[INFO] Proceso con PID $pid detenido"

    return $EXIT_SUCCESS
}

# Función para verificar el estado del proceso
verificar_estado() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        echo "Estado: ACTIVO"
        echo "PID: $pid"
        echo "Puerto: $PORT"
        echo "Versión: $RELEASE"
    else
        echo "Estado: INACTIVO"
        echo "Puerto configurado: $PORT"
        echo "Versión: $RELEASE"
    fi

    return $EXIT_SUCCESS
}

# FUNCIÓN PRINCIPAL Y PUNTO DE ENTRADA

# Función principal
main() {
    local comando="${1:-ayuda}"

    case "$comando" in
        iniciar)
            iniciar_proceso
            ;;
        detener)
            detener_proceso
            ;;
        estado)
            verificar_estado
            ;;
        *)
            echo "Uso: $SCRIPT_NAME {iniciar|detener|estado}"
            echo "  iniciar - Inicia el proceso gestor"
            echo "  detener - Detiene el proceso gestor"
            echo "  estado  - Muestra el estado actual"
            return $EXIT_ERROR_VALIDACION
            ;;
    esac
}

# EJECUCIÓN DEL SCRIPT

# Verificar que el script se ejecute directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi