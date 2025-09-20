#!/bin/bash
# Descripción: Tests de verificación de puertos con netcat (nc)
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
readonly TIMEOUT="${TIMEOUT:-3}"
readonly LOG_FILE="/tmp/nc-tests-$(date +%Y%m%d-%H%M%S).log"
readonly TEMP_DIR="/tmp/nc-test-$$"

# Crear directorio temporal
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Función para logging
log_mensaje() {
    local nivel="$1"
    shift
    local mensaje="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$nivel] $mensaje" | tee -a "$LOG_FILE"
}

# Función para verificar disponibilidad de nc
verificar_nc_disponible() {
    if ! command -v nc >/dev/null 2>&1; then
        log_mensaje "ERROR" "netcat (nc) no está disponible"
        echo -e "${COLOR_ROJO}Error: netcat (nc) no está instalado${COLOR_RESET}"
        echo "Instalar con:"
        echo "  Ubuntu/Debian: sudo apt-get install netcat"
        echo "  CentOS/RHEL:   sudo yum install nc"
        echo "  macOS:         brew install netcat"
        return 1
    fi

    # Detectar versión de nc
    if nc -h 2>&1 | grep -q "OpenBSD"; then
        log_mensaje "INFO" "Detectado OpenBSD netcat"
        echo -e "${COLOR_VERDE}✓ OpenBSD netcat disponible${COLOR_RESET}"
    elif nc -h 2>&1 | grep -q "GNU"; then
        log_mensaje "INFO" "Detectado GNU netcat"
        echo -e "${COLOR_VERDE}✓ GNU netcat disponible${COLOR_RESET}"
    else
        log_mensaje "INFO" "Versión de netcat desconocida"
        echo -e "${COLOR_AMARILLO}⚠ Versión de netcat no identificada${COLOR_RESET}"
    fi

    return 0
}

# Función para escaneo básico de puerto
escanear_puerto() {
    local host="$1"
    local puerto="$2"
    local timeout="${3:-$TIMEOUT}"

    echo -n "  Probando $host:$puerto... "

    # Intentar conexión con timeout
    if nc -z -v -w"$timeout" "$host" "$puerto" 2>/dev/null; then
        echo -e "${COLOR_VERDE}ABIERTO${COLOR_RESET}"
        log_mensaje "INFO" "Puerto $host:$puerto está ABIERTO"
        return 0
    else
        echo -e "${COLOR_ROJO}CERRADO/FILTRADO${COLOR_RESET}"
        log_mensaje "INFO" "Puerto $host:$puerto está CERRADO o FILTRADO"
        return 1
    fi
}

# Función para escaneo de rango de puertos
escanear_rango_puertos() {
    local host="$1"
    local puerto_inicio="$2"
    local puerto_fin="$3"

    echo -e "${COLOR_AZUL}=== Escaneando rango $puerto_inicio-$puerto_fin en $host ===${COLOR_RESET}"
    echo ""

    local puertos_abiertos=0
    local puertos_cerrados=0

    for puerto in $(seq "$puerto_inicio" "$puerto_fin"); do
        if nc -z -w1 "$host" "$puerto" 2>/dev/null; then
            echo -e "  Puerto $puerto: ${COLOR_VERDE}ABIERTO${COLOR_RESET}"
            ((puertos_abiertos++))
            echo "$puerto" >> "$TEMP_DIR/puertos_abiertos.txt"
        else
            # Solo mostrar si está en modo verbose
            if [[ "${VERBOSE:-0}" == "1" ]]; then
                echo -e "  Puerto $puerto: ${COLOR_ROJO}CERRADO${COLOR_RESET}"
            fi
            ((puertos_cerrados++))
        fi
    done

    echo ""
    echo "Resumen:"
    echo "  Puertos abiertos: $puertos_abiertos"
    echo "  Puertos cerrados: $puertos_cerrados"

    if [[ -f "$TEMP_DIR/puertos_abiertos.txt" ]]; then
        echo ""
        echo "Lista de puertos abiertos:"
        cat "$TEMP_DIR/puertos_abiertos.txt" | while read puerto; do
            # Identificar servicio común
            case $puerto in
                21) echo "  $puerto - FTP" ;;
                22) echo "  $puerto - SSH" ;;
                23) echo "  $puerto - Telnet" ;;
                25) echo "  $puerto - SMTP" ;;
                53) echo "  $puerto - DNS" ;;
                80) echo "  $puerto - HTTP" ;;
                110) echo "  $puerto - POP3" ;;
                143) echo "  $puerto - IMAP" ;;
                443) echo "  $puerto - HTTPS" ;;
                3306) echo "  $puerto - MySQL" ;;
                5432) echo "  $puerto - PostgreSQL" ;;
                6379) echo "  $puerto - Redis" ;;
                8080) echo "  $puerto - HTTP-Alt" ;;
                *) echo "  $puerto" ;;
            esac
        done
    fi
}

# Función para test de conectividad TCP
test_conectividad_tcp() {
    local host="$1"
    local puerto="$2"

    echo -e "${COLOR_AZUL}=== Test de Conectividad TCP a $host:$puerto ===${COLOR_RESET}"
    echo ""

    # Test básico
    echo "1. Test de conexión básica:"
    nc -zv -w"$TIMEOUT" "$host" "$puerto" 2>&1 | tee -a "$LOG_FILE"

    echo ""
    echo "2. Enviando banner request:"

    # Intentar obtener banner del servicio
    echo "" | nc -w"$TIMEOUT" "$host" "$puerto" 2>/dev/null > "$TEMP_DIR/banner.txt" || true

    if [[ -s "$TEMP_DIR/banner.txt" ]]; then
        echo "Banner recibido:"
        head -5 "$TEMP_DIR/banner.txt" | sed 's/^/  /'
    else
        echo "  No se recibió banner"
    fi

    echo ""
}

# Función para servidor de prueba con nc
crear_servidor_prueba() {
    local puerto="${1:-9999}"

    echo -e "${COLOR_AZUL}=== Creando servidor de prueba en puerto $puerto ===${COLOR_RESET}"
    echo ""

    # Verificar si el puerto está disponible
    if nc -z localhost "$puerto" 2>/dev/null; then
        echo -e "${COLOR_ROJO}Error: Puerto $puerto ya está en uso${COLOR_RESET}"
        return 1
    fi

    echo "Iniciando servidor en puerto $puerto..."
    echo "Presiona Ctrl+C para detener"
    echo ""

    # Crear servidor que responde con mensaje
    while true; do
        echo -e "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nServidor de prueba activo en puerto $puerto\r\n" | \
            nc -l -p "$puerto" -q 1 2>/dev/null || \
            nc -l "$puerto" 2>/dev/null || break
    done
}

# Función para transferencia de archivos con nc
test_transferencia_archivos() {
    local modo="$1"  # send o receive
    local host="${2:-localhost}"
    local puerto="${3:-9999}"

    echo -e "${COLOR_AZUL}=== Test de Transferencia de Archivos ===${COLOR_RESET}"
    echo ""

    if [[ "$modo" == "send" ]]; then
        # Crear archivo de prueba
        local test_file="$TEMP_DIR/test_file.txt"
        echo "Archivo de prueba generado en $(date)" > "$test_file"
        echo "Contenido de ejemplo para transferencia" >> "$test_file"

        echo "Enviando archivo a $host:$puerto..."
        nc -w"$TIMEOUT" "$host" "$puerto" < "$test_file"

        if [[ $? -eq 0 ]]; then
            echo -e "${COLOR_VERDE}✓ Archivo enviado exitosamente${COLOR_RESET}"
        else
            echo -e "${COLOR_ROJO}✗ Error al enviar archivo${COLOR_RESET}"
        fi
    elif [[ "$modo" == "receive" ]]; then
        local output_file="$TEMP_DIR/received_file.txt"

        echo "Esperando archivo en puerto $puerto..."
        echo "Timeout: ${TIMEOUT}s"

        timeout "$TIMEOUT" nc -l -p "$puerto" > "$output_file" 2>/dev/null || \
        timeout "$TIMEOUT" nc -l "$puerto" > "$output_file" 2>/dev/null

        if [[ -s "$output_file" ]]; then
            echo -e "${COLOR_VERDE}✓ Archivo recibido${COLOR_RESET}"
            echo "Contenido:"
            cat "$output_file" | sed 's/^/  /'
        else
            echo -e "${COLOR_AMARILLO}⚠ No se recibió archivo${COLOR_RESET}"
        fi
    fi
}

# Función para test de UDP
test_udp() {
    local host="$1"
    local puerto="$2"

    echo -e "${COLOR_AZUL}=== Test UDP a $host:$puerto ===${COLOR_RESET}"
    echo ""

    echo "Enviando paquete UDP..."
    echo "test" | nc -u -w1 "$host" "$puerto" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        echo -e "${COLOR_VERDE}✓ Paquete UDP enviado${COLOR_RESET}"
    else
        echo -e "${COLOR_ROJO}✗ Error al enviar paquete UDP${COLOR_RESET}"
    fi

    echo ""
    echo "Nota: UDP no garantiza entrega, resultado puede no ser confiable"
}

# Función para análisis de servicios comunes
analizar_servicios_comunes() {
    local host="${1:-localhost}"

    echo -e "${COLOR_AZUL}=== Análisis de Servicios Comunes en $host ===${COLOR_RESET}"
    echo ""

    # Lista de puertos comunes a verificar
    local puertos_comunes=(
        "22:SSH"
        "80:HTTP"
        "443:HTTPS"
        "3306:MySQL"
        "5432:PostgreSQL"
        "6379:Redis"
        "8080:HTTP-Alt"
        "8443:HTTPS-Alt"
        "9000:PHP-FPM"
        "27017:MongoDB"
    )

    echo "Verificando servicios estándar:"
    echo ""

    for servicio in "${puertos_comunes[@]}"; do
        IFS=':' read -r puerto nombre <<< "$servicio"
        echo -n "  $nombre (puerto $puerto): "

        if nc -z -w1 "$host" "$puerto" 2>/dev/null; then
            echo -e "${COLOR_VERDE}ACTIVO${COLOR_RESET}"

            # Intentar obtener versión/banner para algunos servicios
            case $puerto in
                22)
                    local ssh_version=$(echo "" | nc -w1 "$host" "$puerto" 2>/dev/null | head -1)
                    [[ -n "$ssh_version" ]] && echo "    Versión: $ssh_version"
                    ;;
                80|8080)
                    local http_response=$(echo -e "HEAD / HTTP/1.0\r\n\r\n" | nc -w1 "$host" "$puerto" 2>/dev/null | grep "Server:" | head -1)
                    [[ -n "$http_response" ]] && echo "    $http_response"
                    ;;
            esac
        else
            echo -e "${COLOR_ROJO}INACTIVO${COLOR_RESET}"
        fi
    done
}

# Función para generar reporte
generar_reporte() {
    echo ""
    echo -e "${COLOR_AZUL}=== REPORTE DE TESTS ===${COLOR_RESET}"
    echo ""

    echo "Archivo de log: $LOG_FILE"
    echo "Directorio temporal: $TEMP_DIR"

    if [[ -f "$TEMP_DIR/puertos_abiertos.txt" ]]; then
        echo ""
        echo "Puertos abiertos encontrados:"
        cat "$TEMP_DIR/puertos_abiertos.txt" | tr '\n' ' '
        echo ""
    fi

    echo ""
    echo "Timestamp: $(date)"
}

# Función principal
main() {
    local accion="${1:-ayuda}"
    shift || true

    # Verificar nc disponible
    verificar_nc_disponible || exit 1

    echo ""

    case "$accion" in
        puerto)
            local host="${1:-localhost}"
            local puerto="${2:-80}"
            escanear_puerto "$host" "$puerto"
            ;;
        rango)
            local host="${1:-localhost}"
            local inicio="${2:-1}"
            local fin="${3:-100}"
            escanear_rango_puertos "$host" "$inicio" "$fin"
            ;;
        tcp)
            local host="${1:-localhost}"
            local puerto="${2:-80}"
            test_conectividad_tcp "$host" "$puerto"
            ;;
        servidor)
            local puerto="${1:-9999}"
            crear_servidor_prueba "$puerto"
            ;;
        enviar)
            local host="${1:-localhost}"
            local puerto="${2:-9999}"
            test_transferencia_archivos "send" "$host" "$puerto"
            ;;
        recibir)
            local puerto="${1:-9999}"
            test_transferencia_archivos "receive" "localhost" "$puerto"
            ;;
        udp)
            local host="${1:-localhost}"
            local puerto="${2:-53}"
            test_udp "$host" "$puerto"
            ;;
        servicios)
            local host="${1:-localhost}"
            analizar_servicios_comunes "$host"
            ;;
        ayuda|*)
            echo "Uso: $0 [acción] [opciones]"
            echo ""
            echo "Acciones disponibles:"
            echo "  puerto <host> <puerto>     - Verificar puerto específico"
            echo "  rango <host> <inicio> <fin> - Escanear rango de puertos"
            echo "  tcp <host> <puerto>        - Test de conectividad TCP"
            echo "  servidor <puerto>          - Crear servidor de prueba"
            echo "  enviar <host> <puerto>     - Enviar archivo por nc"
            echo "  recibir <puerto>           - Recibir archivo por nc"
            echo "  udp <host> <puerto>        - Test de puerto UDP"
            echo "  servicios <host>           - Analizar servicios comunes"
            echo ""
            echo "Ejemplos:"
            echo "  $0 puerto google.com 80"
            echo "  $0 rango localhost 8000 8100"
            echo "  $0 servicios localhost"
            [[ "$accion" != "ayuda" ]] && exit 1
            ;;
    esac

    generar_reporte
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi