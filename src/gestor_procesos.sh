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
    # Cargar las variables 
    set -a
    source "$PROJECT_ROOT/.env" 2>/dev/null || true
    set +a
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

# MANEJO DE ERRORES Y SEÑALES

# Función para logging
log_mensaje() {
    local nivel="$1"
    shift
    local mensaje="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Crear directorio de logs si no existe
    [[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR" 2>/dev/null

    # Mostrar en pantalla y guardar en archivo si es posible
    if [[ -w "$LOG_DIR" ]]; then
        echo "[$timestamp] [$nivel] $mensaje" | tee -a "${LOG_FILE:-/tmp/gestor.log}"
    else
        echo "[$timestamp] [$nivel] $mensaje"
    fi
}

# Función de limpieza al salir
limpiar_recursos() {
    local codigo_salida=$?

    # Solo limpiar si no fue una salida limpia
    if [[ $codigo_salida -ne 0 ]]; then
        log_mensaje "WARN" "Limpiando recursos tras error (código: $codigo_salida)"

        # Limpiar PID si existe y es nuestro
        if [[ -f "$PID_FILE" ]]; then
            local pid_actual=$(cat "$PID_FILE" 2>/dev/null)
            if [[ "$pid_actual" == "$$" ]]; then
                rm -f "$PID_FILE"
                log_mensaje "INFO" "Archivo PID limpiado"
            fi
        fi
    fi

    exit $codigo_salida
}

# Función para manejar errores
manejar_error() {
    local linea="$1"
    local comando="$2"
    local codigo="$3"

    # Ignorar códigos de salida esperados (validación)
    if [[ $codigo -eq 9 ]] && [[ "$comando" == *"return"* ]]; then
        exit $codigo
    fi

    log_mensaje "ERROR" "Error en línea $linea: comando '$comando' falló con código $codigo"

    # Determinar tipo de error
    case $codigo in
        1) log_mensaje "ERROR" "Error general del sistema" ;;
        2) log_mensaje "ERROR" "Error de permisos - verificar permisos de archivos" ;;
        3) log_mensaje "ERROR" "Error de proceso - el proceso ya existe o no pudo iniciarse" ;;
        4) log_mensaje "ERROR" "Error de red - verificar conectividad y puertos" ;;
        5) log_mensaje "ERROR" "Error de configuración - verificar archivo .env" ;;
        *) log_mensaje "ERROR" "Error desconocido" ;;
    esac

    exit $codigo
}

# Función para manejar señales
manejar_signal() {
    local signal="$1"

    case "$signal" in
        INT)
            log_mensaje "WARN" "Recibida señal SIGINT (Ctrl+C) - interrumpiendo"
            limpiar_recursos
            exit $EXIT_ERROR_SIGNAL
            ;;
        TERM)
            log_mensaje "INFO" "Recibida señal SIGTERM - terminando gracefully"
            detener_proceso
            exit $EXIT_SUCCESS
            ;;
        HUP)
            log_mensaje "INFO" "Recibida señal SIGHUP - recargando configuración"
            # Recargar configuración en futuras versiones
            ;;
        *)
            log_mensaje "WARN" "Señal no manejada: $signal"
            ;;
    esac
}

# Configurar traps (desactivar ERR trap para returns controlados)
set -E
trap 'manejar_error $LINENO "$BASH_COMMAND" $?' ERR
trap 'limpiar_recursos' EXIT
trap 'manejar_signal INT' INT
trap 'manejar_signal TERM' TERM
trap 'manejar_signal HUP' HUP

# FUNCIONES DE GESTIÓN DE PROCESOS

# Función para iniciar el proceso
iniciar_proceso() {
    log_mensaje "INFO" "Iniciando proceso en puerto $PORT..."

    # Verificar si el archivo PID existe
    if [[ -f "$PID_FILE" ]]; then
        log_mensaje "ERROR" "El proceso ya está en ejecución"
        return $EXIT_ERROR_PROCESO
    fi

    # Crear directorio de logs si no existe
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" || {
            log_mensaje "ERROR" "No se pudo crear directorio de logs: $LOG_DIR"
            return $EXIT_ERROR_PERMISOS
        }
    fi

    # Simular inicio de proceso (se implementará completamente en Sprint 2)
    echo "$$" > "$PID_FILE" || {
        log_mensaje "ERROR" "No se pudo crear archivo PID"
        return $EXIT_ERROR_PERMISOS
    }

    log_mensaje "INFO" "Proceso iniciado con PID $$ en puerto $PORT"
    log_mensaje "INFO" "Logs en: $LOG_FILE"

    return $EXIT_SUCCESS
}

# Función para detener el proceso
detener_proceso() {
    log_mensaje "INFO" "Deteniendo proceso..."

    # Verificar si el archivo PID existe
    if [[ ! -f "$PID_FILE" ]]; then
        log_mensaje "WARN" "No hay proceso activo para detener"
        return $EXIT_SUCCESS
    fi

    # Leer PID y eliminar archivo
    local pid=$(cat "$PID_FILE" 2>/dev/null) || {
        log_mensaje "ERROR" "No se pudo leer archivo PID"
        return $EXIT_ERROR_PERMISOS
    }

    rm -f "$PID_FILE" || {
        log_mensaje "ERROR" "No se pudo eliminar archivo PID"
        return $EXIT_ERROR_PERMISOS
    }

    log_mensaje "INFO" "Proceso con PID $pid detenido"

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
    local resultado=0

    case "$comando" in
        iniciar)
            iniciar_proceso
            resultado=$?
            ;;
        detener)
            detener_proceso
            resultado=$?
            ;;
        estado)
            verificar_estado
            resultado=$?
            ;;
        *)
            echo "Uso: $SCRIPT_NAME {iniciar|detener|estado}"
            echo "  iniciar - Inicia el proceso gestor"
            echo "  detener - Detiene el proceso gestor"
            echo "  estado  - Muestra el estado actual"
            resultado=$EXIT_ERROR_VALIDACION
            ;;
    esac

    return $resultado
}

# EJECUCIÓN DEL SCRIPT

# Verificar que el script se ejecute directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set +e  # Desactivar temporalmente errexit para manejar códigos de salida
    main "$@"
    codigo=$?
    set -e
    exit $codigo
fi