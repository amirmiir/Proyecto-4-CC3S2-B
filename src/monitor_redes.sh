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

# Función para verificar resolución DNS
verificar_dns() {
    local targets_array
    local dominio
    local resultado_dig
    local ip_address
    local query_time
    
    log_info "Verificando resolución DNS con servidor: $DNS_SERVER"
    
    # Convertir TARGETS separados por comas en array
    IFS=',' read -ra targets_array <<< "$TARGETS"
    
    for dominio in "${targets_array[@]}"; do
        # Limpiar espacios en blanco
        dominio=$(echo "$dominio" | tr -d ' ')
        
        log_info "Resolviendo dominio: $dominio"
        
        # Realizar consulta DNS con dig
        if resultado_dig=$(dig +short +time=5 "@$DNS_SERVER" "$dominio" A 2>/dev/null); then
            
            # Verificar si obtuvo respuesta
            if [[ -n "$resultado_dig" ]]; then
                # Extraer primera IP (en caso de múltiples registros)
                ip_address=$(echo "$resultado_dig" | head -n1)
                
                # Obtener tiempo de consulta usando awk para parsing
                query_time=$(dig +noall +stats "@$DNS_SERVER" "$dominio" A 2>/dev/null | \
                           awk '/Query time:/ {print $4}')
                
                log_info "DNS resuelto: $dominio -> $ip_address"
                log_info "Tiempo de consulta: ${query_time:-N/A} ms"
                
                # Verificar formato de IP válida usando cut para validación
                if [[ "$ip_address" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    log_info "Verificación DNS exitosa para $dominio"
                else
                    log_error "Respuesta DNS inválida para $dominio: $ip_address"
                    return $EXIT_ERROR_RED
                fi
            else
                log_error "No se pudo resolver $dominio: sin respuesta del servidor DNS"
                return $EXIT_ERROR_RED
            fi
        else
            log_error "Error de conectividad DNS para $dominio con servidor $DNS_SERVER"
            return $EXIT_ERROR_RED
        fi
    done
    
    log_info "Verificación DNS completada exitosamente para todos los dominios"
    return $EXIT_SUCCESS
}

# Función para ejecutar todas las verificaciones (HTTP + DNS)
verificar_todo() {
    local exit_code=$EXIT_SUCCESS
    local error_count=0
    
    log_info "=== Iniciando verificación completa HTTP + DNS ==="
    
    # Verificar HTTP primero
    log_info "--- Verificación HTTP ---"
    if ! verificar_http; then
        log_error "Falló verificación HTTP"
        ((error_count++))
        exit_code=$EXIT_ERROR_RED
    fi
    
    # Separador visual en logs
    echo "" | tee -a "$LOG_FILE"
    
    # Verificar DNS después
    log_info "--- Verificación DNS ---"
    if ! verificar_dns; then
        log_error "Falló verificación DNS"
        ((error_count++))
        exit_code=$EXIT_ERROR_RED
    fi
    
    # Resumen final
    echo "" | tee -a "$LOG_FILE"
    log_info "=== Resumen de verificaciones ==="
    if [[ $error_count -eq 0 ]]; then
        log_info "Todas las verificaciones completadas exitosamente"
        log_info "HTTP: EXITOSO | DNS: EXITOSO"
    else
        log_error "Se encontraron $error_count errores en las verificaciones"
        if [[ $error_count -eq 1 ]]; then
            log_error "Una verificación falló - revisar logs arriba"
        else
            log_error "Múltiples verificaciones fallaron - revisar logs arriba"
        fi
    fi
    
    return $exit_code
}

# Función para mostrar ayuda
mostrar_ayuda() {
    cat << EOF
Uso: $SCRIPT_NAME [COMANDO] [OPCIONES]

COMANDOS:
    http        Verificar conectividad HTTP
    dns         Verificar resolución DNS
    tls         Verificar certificados TLS
    comparar    Comparar HTTP vs HTTPS
    netcat      Tests de puertos con nc
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

# Función para tests con netcat
test_con_netcat() {
    local accion="${1:-servicios}"
    local host="${2:-localhost}"

    log_info "=== Tests con netcat (nc) ==="

    # Verificar disponibilidad de nc
    if ! command -v nc >/dev/null 2>&1; then
        log_error "netcat (nc) no está disponible"
        return $EXIT_ERROR_DEPENDENCIA
    fi

    # Llamar al script de tests con nc
    local script_nc="$SCRIPT_DIR/test_puertos_nc.sh"
    if [[ -x "$script_nc" ]]; then
        "$script_nc" "$accion" "$host"
        return $?
    else
        # Test básico si el script no está disponible
        log_info "Ejecutando test básico con nc"

        # Convertir targets a array
        IFS=',' read -ra hosts <<< "$TARGETS"

        for target in "${hosts[@]}"; do
            target=$(echo "$target" | tr -d ' ')
            log_info "Verificando puertos comunes en $target"

            # Puertos comunes a verificar
            local puertos=(22 80 443 3306 5432 6379 8080)

            for puerto in "${puertos[@]}"; do
                echo -n "  Puerto $puerto: "
                if nc -z -w2 "$target" "$puerto" 2>/dev/null; then
                    echo "ABIERTO"
                    log_info "Puerto $target:$puerto ABIERTO"
                else
                    echo "CERRADO"
                fi
            done
            echo ""
        done
    fi

    return $EXIT_SUCCESS
}

# Función para comparar HTTP vs HTTPS
comparar_http_tls() {
    local targets="${1:-$TARGETS}"

    log_info "=== Iniciando comparación HTTP vs HTTPS ==="

    # Convertir targets a array
    IFS=',' read -ra hosts <<< "$targets"

    for host in "${hosts[@]}"; do
        # Limpiar espacios
        host=$(echo "$host" | tr -d ' ')

        log_info "Analizando: $host"

        # Llamar al script de análisis TLS
        local script_tls="$SCRIPT_DIR/analizar_tls.sh"
        if [[ -x "$script_tls" ]]; then
            "$script_tls" "$host"
        else
            # Análisis básico si el script no está disponible
            log_info "Realizando análisis básico para $host"

            # Probar HTTP
            echo ""
            echo "Probando HTTP://$host"
            local http_time=$(curl -o /dev/null -s -w '%{time_total}' "http://$host" 2>/dev/null)
            local http_code=$(curl -o /dev/null -s -w '%{http_code}' "http://$host" 2>/dev/null)
            echo "  Código HTTP: $http_code"
            echo "  Tiempo: ${http_time}s"

            # Probar HTTPS
            echo ""
            echo "Probando HTTPS://$host"
            local https_time=$(curl -o /dev/null -s -w '%{time_total}' "https://$host" 2>/dev/null)
            local https_code=$(curl -o /dev/null -s -w '%{http_code}' "https://$host" 2>/dev/null)
            local ssl_verify=$(curl -o /dev/null -s -w '%{ssl_verify_result}' "https://$host" 2>/dev/null)
            echo "  Código HTTPS: $https_code"
            echo "  Tiempo: ${https_time}s"
            echo "  Verificación SSL: $ssl_verify (0=OK)"

            # Comparación simple con awk
            echo ""
            echo "Diferencias:"
            awk -v http="$http_time" -v https="$https_time" 'BEGIN {
                diff = https - http
                if (diff > 0) {
                    printf "  HTTPS es %.3fs más lento (overhead TLS)\n", diff
                } else {
                    printf "  HTTPS es %.3fs más rápido\n", -diff
                }
            }'

            # Verificar HSTS
            echo ""
            if curl -sI "https://$host" | grep -qi "strict-transport-security"; then
                echo "  ✓ HSTS habilitado"
            else
                echo "  ✗ HSTS no habilitado"
            fi
        fi

        echo ""
        echo "----------------------------------------"
    done

    log_info "Comparación completada"
    return $EXIT_SUCCESS
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
            verificar_dns
            ;;
        "tls")
            log_info "Ejecutando verificación TLS..."
            # Función a implementar en Sprint 2
            ;;
        "comparar")
            log_info "Ejecutando comparación HTTP vs HTTPS..."
            comparar_http_tls "${2:-$TARGETS}"
            ;;
        "netcat"|"nc")
            log_info "Ejecutando tests con netcat..."
            test_con_netcat "${2:-servicios}" "${3:-localhost}"
            ;;
        "todo")
            log_info "Ejecutando todas las verificaciones..."
            verificar_todo
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