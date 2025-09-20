#!/bin/bash
# Descripción: Análisis comparativo TLS vs HTTP con curl
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
readonly TIMEOUT="${TIMEOUT:-10}"
readonly USER_AGENT="${USER_AGENT:-Mozilla/5.0 Gestor-Procesos/1.0}"
readonly TEMP_DIR="/tmp/tls-analysis-$$"

# Crear directorio temporal
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Función para analizar protocolo HTTP
analizar_http() {
    local url="$1"
    local output_file="$TEMP_DIR/http-analysis.txt"

    echo -e "${COLOR_AZUL}=== Análisis HTTP ===${COLOR_RESET}"
    echo "URL: $url"
    echo ""

    # Realizar petición con curl verbose
    curl -v \
        --http1.1 \
        --max-time "$TIMEOUT" \
        --user-agent "$USER_AGENT" \
        --location \
        --write-out "\n\nTIEMPO_TOTAL: %{time_total}s\nTIEMPO_CONEXION: %{time_connect}s\nTIEMPO_PRIMERA_BYTE: %{time_starttransfer}s\nVELOCIDAD_DESCARGA: %{speed_download} bytes/s\nTAMAÑO_DESCARGA: %{size_download} bytes\nCODIGO_HTTP: %{http_code}\nREDIRECCIONES: %{num_redirects}\n" \
        --silent \
        --output /dev/null \
        "$url" 2>"$output_file" || true

    # Extraer información con awk
    echo "Información de conexión:"
    awk '
    /Connected to/ {
        split($0, parts, " ")
        for (i=1; i<=NF; i++) {
            if (parts[i] ~ /\(.*\)/) {
                gsub(/[()]/, "", parts[i])
                print "  • IP servidor: " parts[i]
            }
            if (parts[i] == "port") {
                print "  • Puerto: " parts[i+1]
            }
        }
    }
    /^> Host:/ {
        print "  • Host: " $3
    }
    /^< Server:/ {
        gsub(/^< Server: /, "")
        print "  • Servidor: " $0
    }
    /^< Content-Type:/ {
        gsub(/^< Content-Type: /, "")
        print "  • Content-Type: " $0
    }
    /^< Content-Length:/ {
        gsub(/^< Content-Length: /, "")
        print "  • Content-Length: " $0 " bytes"
    }
    /TIEMPO_TOTAL:/ {
        print "\nMétricas de rendimiento:"
        print "  • " $0
    }
    /TIEMPO_CONEXION:/ {
        print "  • " $0
    }
    /TIEMPO_PRIMERA_BYTE:/ {
        print "  • " $0
    }
    /VELOCIDAD_DESCARGA:/ {
        print "  • " $0
    }
    /CODIGO_HTTP:/ {
        gsub(/CODIGO_HTTP: /, "")
        codigo = $0
        print "  • Código HTTP: " codigo
        if (codigo >= 200 && codigo < 300) {
            print "    Estado: EXITOSO"
        } else if (codigo >= 300 && codigo < 400) {
            print "    Estado: REDIRECCION"
        } else if (codigo >= 400 && codigo < 500) {
            print "    Estado: ERROR_CLIENTE"
        } else if (codigo >= 500) {
            print "    Estado: ERROR_SERVIDOR"
        }
    }
    ' "$output_file"

    # Análisis de headers
    echo ""
    echo "Headers de seguridad HTTP:"
    local headers_seguridad=(
        "Strict-Transport-Security"
        "X-Content-Type-Options"
        "X-Frame-Options"
        "X-XSS-Protection"
        "Content-Security-Policy"
        "Referrer-Policy"
    )

    for header in "${headers_seguridad[@]}"; do
        if grep -qi "^< $header:" "$output_file"; then
            valor=$(grep -i "^< $header:" "$output_file" | cut -d' ' -f3-)
            echo -e "  ${COLOR_VERDE}✓${COLOR_RESET} $header: $valor"
        else
            echo -e "  ${COLOR_ROJO}✗${COLOR_RESET} $header: NO PRESENTE"
        fi
    done

    # Análisis de cookies
    echo ""
    echo "Análisis de cookies:"
    if grep -q "^< Set-Cookie:" "$output_file"; then
        grep "^< Set-Cookie:" "$output_file" | while read -r line; do
            cookie=$(echo "$line" | cut -d' ' -f3-)
            echo "  • Cookie encontrada"

            # Verificar atributos de seguridad
            if echo "$cookie" | grep -qi "Secure"; then
                echo -e "    ${COLOR_VERDE}✓ Secure${COLOR_RESET}"
            else
                echo -e "    ${COLOR_AMARILLO}⚠ Sin Secure${COLOR_RESET}"
            fi

            if echo "$cookie" | grep -qi "HttpOnly"; then
                echo -e "    ${COLOR_VERDE}✓ HttpOnly${COLOR_RESET}"
            else
                echo -e "    ${COLOR_AMARILLO}⚠ Sin HttpOnly${COLOR_RESET}"
            fi

            if echo "$cookie" | grep -qi "SameSite"; then
                echo -e "    ${COLOR_VERDE}✓ SameSite${COLOR_RESET}"
            else
                echo -e "    ${COLOR_AMARILLO}⚠ Sin SameSite${COLOR_RESET}"
            fi
        done
    else
        echo "  No se encontraron cookies"
    fi
}

# Función para analizar protocolo HTTPS/TLS
analizar_tls() {
    local url="$1"
    local output_file="$TEMP_DIR/tls-analysis.txt"

    echo ""
    echo -e "${COLOR_AZUL}=== Análisis HTTPS/TLS ===${COLOR_RESET}"
    echo "URL: $url"
    echo ""

    # Realizar petición con información TLS
    curl -v \
        --tlsv1.2 \
        --max-time "$TIMEOUT" \
        --user-agent "$USER_AGENT" \
        --location \
        --write-out "\n\nTIEMPO_TOTAL: %{time_total}s\nTIEMPO_CONEXION: %{time_connect}s\nTIEMPO_APPCONNECT: %{time_appconnect}s\nTIEMPO_PRIMERA_BYTE: %{time_starttransfer}s\nSSL_VERIFY: %{ssl_verify_result}\nHTTP_VERSION: %{http_version}\n" \
        --silent \
        --output /dev/null \
        "$url" 2>"$output_file" || true

    # Extraer información TLS con awk
    echo "Información TLS/SSL:"
    awk '
    /SSL connection using/ {
        gsub(/^\* /, "")
        print "  • " $0
    }
    /Server certificate:/ {
        print "\nCertificado del servidor:"
        in_cert = 1
    }
    in_cert && /subject:/ {
        gsub(/^\*  /, "")
        print "  • " $0
    }
    in_cert && /start date:/ {
        gsub(/^\*  /, "")
        print "  • " $0
    }
    in_cert && /expire date:/ {
        gsub(/^\*  /, "")
        print "  • " $0
    }
    in_cert && /issuer:/ {
        gsub(/^\*  /, "")
        print "  • " $0
    }
    in_cert && /SSL certificate verify/ {
        gsub(/^\*  /, "")
        print "  • Verificación: " $0
        in_cert = 0
    }
    /ALPN, server accepted/ {
        gsub(/^\* /, "")
        print "  • Protocolo ALPN: " $0
    }
    /TIEMPO_APPCONNECT:/ {
        print "\nMétricas TLS:"
        gsub(/TIEMPO_APPCONNECT: /, "")
        print "  • Tiempo handshake TLS: " $0
    }
    /SSL_VERIFY:/ {
        gsub(/SSL_VERIFY: /, "")
        if ($0 == "0") {
            print "  • Verificación SSL: EXITOSA"
        } else {
            print "  • Verificación SSL: FALLÓ (código " $0 ")"
        }
    }
    /HTTP_VERSION:/ {
        gsub(/HTTP_VERSION: /, "")
        print "  • Versión HTTP: " $0
    }
    ' "$output_file"

    # Análisis de cifrado
    echo ""
    echo "Análisis de cifrado:"
    if grep -q "SSL connection using" "$output_file"; then
        cifrado=$(grep "SSL connection using" "$output_file" | sed 's/.*SSL connection using //' | cut -d' ' -f1)
        echo "  • Suite de cifrado: $cifrado"

        # Evaluar fortaleza del cifrado
        if echo "$cifrado" | grep -q "TLSv1.[23]"; then
            echo -e "    ${COLOR_VERDE}✓ Versión TLS moderna${COLOR_RESET}"
        else
            echo -e "    ${COLOR_AMARILLO}⚠ Versión TLS antigua${COLOR_RESET}"
        fi

        if echo "$cifrado" | grep -qi "AES"; then
            echo -e "    ${COLOR_VERDE}✓ Cifrado AES${COLOR_RESET}"
        fi

        if echo "$cifrado" | grep -qi "SHA256\|SHA384"; then
            echo -e "    ${COLOR_VERDE}✓ Hash fuerte${COLOR_RESET}"
        elif echo "$cifrado" | grep -qi "SHA1\|MD5"; then
            echo -e "    ${COLOR_ROJO}✗ Hash débil${COLOR_RESET}"
        fi
    fi

    # Análisis HSTS
    echo ""
    echo "Análisis HSTS:"
    if grep -q "Strict-Transport-Security" "$output_file"; then
        hsts=$(grep "Strict-Transport-Security" "$output_file" | cut -d' ' -f3-)
        echo -e "  ${COLOR_VERDE}✓ HSTS habilitado: $hsts${COLOR_RESET}"

        # Extraer max-age
        if echo "$hsts" | grep -o "max-age=[0-9]*"; then
            max_age=$(echo "$hsts" | grep -o "max-age=[0-9]*" | cut -d= -f2)
            dias=$((max_age / 86400))
            echo "    Duración: $dias días"
        fi
    else
        echo -e "  ${COLOR_ROJO}✗ HSTS no habilitado${COLOR_RESET}"
    fi
}

# Función para comparar HTTP vs HTTPS
comparar_protocolos() {
    local dominio="$1"
    local http_file="$TEMP_DIR/http-analysis.txt"
    local tls_file="$TEMP_DIR/tls-analysis.txt"

    echo ""
    echo -e "${COLOR_AZUL}=== COMPARACIÓN HTTP vs HTTPS ===${COLOR_RESET}"
    echo ""

    # Tabla comparativa
    echo "| Característica | HTTP | HTTPS |"
    echo "|----------------|------|-------|"

    # Cifrado
    echo -n "| Cifrado | "
    echo -n -e "${COLOR_ROJO}✗ No${COLOR_RESET} | "
    echo -e "${COLOR_VERDE}✓ Sí${COLOR_RESET} |"

    # Integridad
    echo -n "| Integridad | "
    echo -n -e "${COLOR_ROJO}✗ No${COLOR_RESET} | "
    echo -e "${COLOR_VERDE}✓ Sí${COLOR_RESET} |"

    # Autenticación
    echo -n "| Autenticación | "
    echo -n -e "${COLOR_ROJO}✗ No${COLOR_RESET} | "
    if grep -q "SSL certificate verify ok" "$tls_file" 2>/dev/null; then
        echo -e "${COLOR_VERDE}✓ Sí${COLOR_RESET} |"
    else
        echo -e "${COLOR_AMARILLO}⚠ Parcial${COLOR_RESET} |"
    fi

    # HSTS
    echo -n "| HSTS | "
    if grep -q "Strict-Transport-Security" "$http_file" 2>/dev/null; then
        echo -n -e "${COLOR_VERDE}✓ Sí${COLOR_RESET} | "
    else
        echo -n -e "${COLOR_ROJO}✗ No${COLOR_RESET} | "
    fi
    if grep -q "Strict-Transport-Security" "$tls_file" 2>/dev/null; then
        echo -e "${COLOR_VERDE}✓ Sí${COLOR_RESET} |"
    else
        echo -e "${COLOR_ROJO}✗ No${COLOR_RESET} |"
    fi

    # Rendimiento
    echo ""
    echo "Comparación de rendimiento:"

    # Extraer tiempos
    if [[ -f "$http_file" ]] && [[ -f "$tls_file" ]]; then
        tiempo_http=$(grep "TIEMPO_TOTAL:" "$http_file" 2>/dev/null | cut -d' ' -f2 | sed 's/s//')
        tiempo_https=$(grep "TIEMPO_TOTAL:" "$tls_file" 2>/dev/null | cut -d' ' -f2 | sed 's/s//')

        if [[ -n "$tiempo_http" ]] && [[ -n "$tiempo_https" ]]; then
            echo "  • Tiempo HTTP:  ${tiempo_http}s"
            echo "  • Tiempo HTTPS: ${tiempo_https}s"

            # Calcular diferencia con awk
            diferencia=$(awk "BEGIN { printf \"%.3f\", $tiempo_https - $tiempo_http }")
            echo "  • Overhead TLS: ${diferencia}s"
        fi
    fi

    echo ""
    echo "Recomendaciones de seguridad:"
    echo -e "  ${COLOR_VERDE}✓${COLOR_RESET} Usar siempre HTTPS para datos sensibles"
    echo -e "  ${COLOR_VERDE}✓${COLOR_RESET} Implementar HSTS con max-age largo"
    echo -e "  ${COLOR_VERDE}✓${COLOR_RESET} Usar TLS 1.2 o superior"
    echo -e "  ${COLOR_VERDE}✓${COLOR_RESET} Implementar HTTP/2 para mejor rendimiento"
    echo -e "  ${COLOR_VERDE}✓${COLOR_RESET} Configurar redirección automática HTTP → HTTPS"
}

# Función principal
main() {
    local dominio="${1:-}"

    if [[ -z "$dominio" ]]; then
        echo "Uso: $0 <dominio>"
        echo "Ejemplo: $0 example.com"
        exit 1
    fi

    echo -e "${COLOR_AZUL}╔══════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_AZUL}║     ANÁLISIS COMPARATIVO TLS vs HTTP    ║${COLOR_RESET}"
    echo -e "${COLOR_AZUL}╚══════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo "Dominio analizado: $dominio"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Construir URLs
    http_url="http://${dominio}"
    https_url="https://${dominio}"

    # Realizar análisis
    analizar_http "$http_url"
    analizar_tls "$https_url"
    comparar_protocolos "$dominio"

    echo ""
    echo -e "${COLOR_VERDE}=== Análisis completado ===${COLOR_RESET}"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi