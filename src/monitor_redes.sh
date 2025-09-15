#!/bin/bash
# Descripción: Monitor de redes para verificación HTTP/DNS/TLS

set -euo pipefail
IFS=$'\n\t'

# VARIABLES GLOBALES Y CONFIGURACIÓN

# Directorio del script
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Archivos de control y logs
readonly LOG_DIR="/tmp/monitor-logs"
readonly LOG_FILE="${LOG_DIR}/monitor-redes-$(date +%Y%m%d).log"
readonly RESULTS_FILE="/tmp/monitor-results.json"

# Variables de entorno con valores por defecto
readonly DNS_SERVER="${DNS_SERVER:-8.8.8.8}"
readonly TARGETS="${TARGETS:-google.com,github.com}"
readonly CONFIG_URL="${CONFIG_URL:-http://httpbin.org/status/200}"
readonly TIMEOUT="${TIMEOUT:-10}"

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

# FUNCIONES DE UTILIDAD

# Función de logging
log_info() {
    local mensaje="$1"
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $mensaje" | tee -a "$LOG_FILE"
}

log_error() {
    local mensaje="$1"
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $mensaje" | tee -a "$LOG_FILE" >&2
}

# Función de limpieza
cleanup() {
    local exit_code=$?
    log_info "Limpiando recursos del monitor de redes..."
    # Aquí se agregarán recursos a limpiar en futuras iteraciones
    exit $exit_code
}

trap cleanup EXIT ERR INT TERM

# FUNCIONES DE MONITOREO

# Función para verificar conectividad HTTP
verificar_http() {
    local url="${1:-$CONFIG_URL}"
    local codigo_esperado="${2:-200}"
    local resultado_http=""
    local codigo_status=""
    local tiempo_respuesta=""
    
    log_info "Verificando HTTP: $url"
    
    # Realizar petición HTTP con curl y capturar información
    if resultado_http=$(curl -s -w "%{http_code}|%{time_total}" \
                           --max-time "$TIMEOUT" \
                           --connect-timeout 5 \
                           -H "User-Agent: Monitor-Redes/1.0" \
                           "$url" 2>/dev/null); then
        
        # Extraer código de estado y tiempo de respuesta
        codigo_status=$(echo "$resultado_http" | tail -1 | cut -d'|' -f1)
        tiempo_respuesta=$(echo "$resultado_http" | tail -1 | cut -d'|' -f2)
        
        log_info "Código HTTP: $codigo_status"
        log_info "Tiempo de respuesta: ${tiempo_respuesta}s"
        
        # Verificar si el código coincide con el esperado
        if [[ "$codigo_status" == "$codigo_esperado" ]]; then
            log_info "Verificación HTTP exitosa para $url"
            return $EXIT_SUCCESS
        else
            log_error "Código HTTP inesperado: esperado $codigo_esperado, obtenido $codigo_status"
            return $EXIT_ERROR_RED
        fi
    else
        log_error "Error de conectividad HTTP a $url"
        return $EXIT_ERROR_RED
    fi
}

# Función para mostrar ayuda
mostrar_ayuda() {
    cat << EOF
Uso: $SCRIPT_NAME [COMANDO] [OPCIONES]

COMANDOS:
    http        Verificar conectividad HTTP
    dns         Verificar resolución DNS
    tls         Verificar certificados TLS
    todo        Ejecutar todas las verificaciones
    ayuda       Mostrar esta ayuda

VARIABLES DE ENTORNO:
    DNS_SERVER  Servidor DNS a usar (defecto: 8.8.8.8)
    TARGETS     Hosts separados por comas (defecto: google.com,github.com)
    CONFIG_URL  URL para pruebas HTTP (defecto: http://httpbin.org/status/200)
    TIMEOUT     Timeout en segundos (defecto: 10)

EJEMPLOS:
    $SCRIPT_NAME http
    TARGETS="example.com,test.com" $SCRIPT_NAME dns
    CONFIG_URL="https://api.github.com" $SCRIPT_NAME http

CÓDIGOS DE SALIDA:
    0 - Éxito
    1 - Error general
    2 - Error de permisos
    3 - Error de proceso
    4 - Error de red
    5 - Error de configuración
    6 - Error de señal
    7 - Error de timeout
    8 - Error de dependencia
    9 - Error de validación
EOF
}

# Función para verificar dependencias
verificar_dependencias() {
    local dependencias=("curl" "dig" "openssl")
    local faltantes=()
    
    for cmd in "${dependencias[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            faltantes+=("$cmd")
        fi
    done
    
    if [[ ${#faltantes[@]} -ne 0 ]]; then
        log_error "Dependencias faltantes: ${faltantes[*]}"
        return $EXIT_ERROR_DEPENDENCIA
    fi
    
    log_info "Todas las dependencias están disponibles"
    return $EXIT_SUCCESS
}

# Función principal de procesamiento de argumentos
main() {
    # Crear directorio de logs si no existe
    [[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"
    
    log_info "Iniciando monitor de redes..."
    log_info "DNS_SERVER: $DNS_SERVER"
    log_info "TARGETS: $TARGETS"
    log_info "CONFIG_URL: $CONFIG_URL"
    log_info "TIMEOUT: $TIMEOUT"
    
    # Verificar dependencias
    verificar_dependencias || return $?
    
    # Procesar argumentos
    case "${1:-ayuda}" in
        "http")
            log_info "Ejecutando verificación HTTP..."
            verificar_http "${2:-$CONFIG_URL}" "${3:-200}"
            ;;
        "dns")
            log_info "Ejecutando verificación DNS..."
            # Función a implementar en Sprint 2
            ;;
        "tls")
            log_info "Ejecutando verificación TLS..."
            # Función a implementar en Sprint 2
            ;;
        "todo")
            log_info "Ejecutando todas las verificaciones..."
            # Función a implementar en Sprint 2
            ;;
        "ayuda"|"--help"|"-h")
            mostrar_ayuda
            return $EXIT_SUCCESS
            ;;
        *)
            log_error "Comando desconocido: $1"
            mostrar_ayuda
            return $EXIT_ERROR_VALIDACION
            ;;
    esac
    
    log_info "Monitor de redes completado exitosamente"
    return $EXIT_SUCCESS
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi