#!/bin/bash
# Descripción: Verificación de sockets y conexiones con ss
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
readonly PUERTO_GESTOR="${PORT:-8080}"
readonly TEMP_DIR="/tmp/socket-analysis-$$"

# Crear directorio temporal
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Función para verificar si ss está disponible
verificar_ss_disponible() {
    if ! command -v ss >/dev/null 2>&1; then
        echo -e "${COLOR_ROJO}Error: 'ss' no está disponible${COLOR_RESET}"
        echo "Intentando usar netstat como alternativa..."

        if command -v netstat >/dev/null 2>&1; then
            echo -e "${COLOR_VERDE}✓ Usando netstat como alternativa${COLOR_RESET}"
            return 1
        else
            echo -e "${COLOR_ROJO}Error: ni 'ss' ni 'netstat' están disponibles${COLOR_RESET}"
            exit 1
        fi
    fi
    return 0
}

# Función para analizar puertos TCP
analizar_puertos_tcp() {
    echo -e "${COLOR_AZUL}=== Análisis de Puertos TCP ===${COLOR_RESET}"
    echo ""

    if verificar_ss_disponible; then
        # Usar ss
        echo "Puertos TCP escuchando:"
        ss -tlnp 2>/dev/null | awk '
        NR > 1 {
            split($4, addr, ":")
            puerto = addr[length(addr)]
            estado = $2

            if (puerto != "" && puerto != "*") {
                printf "  Puerto %-6s - Estado: %-10s", puerto, estado

                # Clasificar puerto
                if (puerto == 22) print " [SSH]"
                else if (puerto == 80) print " [HTTP]"
                else if (puerto == 443) print " [HTTPS]"
                else if (puerto == 3306) print " [MySQL]"
                else if (puerto == 5432) print " [PostgreSQL]"
                else if (puerto == 6379) print " [Redis]"
                else if (puerto == 8080 || puerto == 8081 || puerto == 8082) print " [HTTP Alt]"
                else if (puerto >= 1024 && puerto < 49152) print " [Usuario]"
                else if (puerto >= 49152) print " [Dinámico]"
                else print " [Sistema]"
            }
        }' | sort -u

        echo ""
        echo "Estadísticas TCP:"
        ss -s 2>/dev/null | grep -A2 "^TCP:" | tail -2
    else
        # Usar netstat como alternativa
        echo "Puertos TCP escuchando (netstat):"
        netstat -tln 2>/dev/null | awk '
        /^tcp/ {
            split($4, addr, ":")
            puerto = addr[length(addr)]
            if (puerto != "" && puerto != "*") {
                print "  Puerto " puerto
            }
        }' | sort -u
    fi
}

# Función para analizar conexiones activas
analizar_conexiones_activas() {
    echo ""
    echo -e "${COLOR_AZUL}=== Conexiones Activas ===${COLOR_RESET}"
    echo ""

    if verificar_ss_disponible; then
        # Contar conexiones por estado con ss
        echo "Estados de conexión:"
        ss -tan 2>/dev/null | awk '
        NR > 1 {
            estados[$2]++
            total++
        }
        END {
            for (estado in estados) {
                printf "  %-15s: %d conexiones\n", estado, estados[estado]
            }
            printf "\n  Total: %d conexiones activas\n", total
        }'

        echo ""
        echo "Top 10 conexiones por IP remota:"
        ss -tan 2>/dev/null | awk '
        NR > 1 && $2 == "ESTAB" {
            split($5, remote, ":")
            if (remote[1] != "" && remote[1] != "*") {
                ips[remote[1]]++
            }
        }
        END {
            for (ip in ips) {
                print ips[ip], ip
            }
        }' | sort -rn | head -10 | while read count ip; do
            printf "  %-20s: %d conexiones\n" "$ip" "$count"
        done
    else
        # Usar netstat como alternativa
        echo "Estados de conexión (netstat):"
        netstat -tan 2>/dev/null | awk '
        /^tcp/ {
            estados[$6]++
        }
        END {
            for (estado in estados) {
                printf "  %-15s: %d conexiones\n", estado, estados[estado]
            }
        }'
    fi
}

# Función para verificar puerto específico
verificar_puerto_especifico() {
    local puerto="$1"

    echo ""
    echo -e "${COLOR_AZUL}=== Verificación Puerto $puerto ===${COLOR_RESET}"
    echo ""

    # Verificar si el puerto está en uso
    if verificar_ss_disponible; then
        # Usar ss
        if ss -tln | grep -q ":$puerto "; then
            echo -e "  ${COLOR_VERDE}✓ Puerto $puerto está ESCUCHANDO${COLOR_RESET}"

            # Obtener información del proceso
            local proceso=$(ss -tlnp 2>/dev/null | grep ":$puerto " | awk '{print $NF}')
            if [[ -n "$proceso" ]]; then
                echo "  Proceso: $proceso"
            fi

            # Contar conexiones al puerto
            local conexiones=$(ss -tan | grep ":$puerto " | wc -l)
            echo "  Conexiones activas: $conexiones"

            # Detalles de conexiones
            echo ""
            echo "  Detalles de conexiones:"
            ss -tan 2>/dev/null | grep ":$puerto " | awk '{
                printf "    %-20s -> %-20s [%s]\n", $4, $5, $2
            }' | head -5
        else
            echo -e "  ${COLOR_ROJO}✗ Puerto $puerto NO está escuchando${COLOR_RESET}"

            # Verificar si está disponible
            if ! nc -z localhost "$puerto" 2>/dev/null; then
                echo -e "  ${COLOR_VERDE}✓ Puerto $puerto está DISPONIBLE para usar${COLOR_RESET}"
            fi
        fi
    else
        # Usar netstat y lsof como alternativa
        if netstat -tln 2>/dev/null | grep -q ":$puerto "; then
            echo -e "  ${COLOR_VERDE}✓ Puerto $puerto está ESCUCHANDO${COLOR_RESET}"

            # Intentar obtener proceso con lsof
            if command -v lsof >/dev/null 2>&1; then
                local proceso=$(lsof -i :$puerto 2>/dev/null | awk 'NR==2 {print $1 "(" $2 ")"}')
                if [[ -n "$proceso" ]]; then
                    echo "  Proceso: $proceso"
                fi
            fi
        else
            echo -e "  ${COLOR_ROJO}✗ Puerto $puerto NO está escuchando${COLOR_RESET}"
        fi
    fi
}

# Función para análisis de sockets Unix
analizar_sockets_unix() {
    echo ""
    echo -e "${COLOR_AZUL}=== Sockets Unix/Local ===${COLOR_RESET}"
    echo ""

    if verificar_ss_disponible; then
        echo "Sockets Unix activos:"
        ss -xlp 2>/dev/null | awk '
        NR > 1 {
            tipo = $1
            estado = $2
            path = $NF

            if (path != "" && path != "*") {
                printf "  %-10s %-10s %s\n", tipo, estado, path
            }
        }' | head -10

        # Contar por tipo
        echo ""
        echo "Estadísticas de sockets Unix:"
        local total=$(ss -xl 2>/dev/null | wc -l)
        echo "  Total: $((total-1)) sockets Unix"
    else
        echo "Análisis de sockets Unix no disponible sin 'ss'"
    fi
}

# Función para monitoreo de rendimiento
analizar_rendimiento_red() {
    echo ""
    echo -e "${COLOR_AZUL}=== Rendimiento de Red ===${COLOR_RESET}"
    echo ""

    if verificar_ss_disponible; then
        # Análisis de memoria de sockets
        echo "Uso de memoria por sockets:"
        ss -tam 2>/dev/null | awk '
        /^ESTAB/ {
            if ($6 ~ /skmem/) {
                gsub(/.*skmem:\(/, "", $6)
                gsub(/\).*/, "", $6)
                split($6, mem, ",")

                # mem[1] = r (receive buffer)
                # mem[2] = rb (receive buffer size)
                # mem[3] = t (transmit buffer)
                # mem[4] = tb (transmit buffer size)

                total_recv += mem[1]
                total_send += mem[3]
                count++
            }
        }
        END {
            if (count > 0) {
                printf "  Buffer recepción promedio: %.2f KB\n", total_recv/count/1024
                printf "  Buffer envío promedio: %.2f KB\n", total_send/count/1024
                printf "  Conexiones analizadas: %d\n", count
            }
        }'

        # Análisis de retransmisiones con awk
        echo ""
        echo "Análisis de calidad de conexión:"
        ss -ti 2>/dev/null | awk '
        /retrans/ {
            retrans++
        }
        /cwnd/ {
            cwnd++
        }
        END {
            if (cwnd > 0) {
                printf "  Conexiones con retransmisiones: %d\n", retrans
                printf "  Total conexiones TCP detalladas: %d\n", cwnd
                if (retrans > 0) {
                    printf "  Tasa de retransmisión: %.1f%%\n", (retrans*100.0)/cwnd
                }
            }
        }'
    fi
}

# Función para generar resumen
generar_resumen_sockets() {
    echo ""
    echo -e "${COLOR_AZUL}=== RESUMEN DE SOCKETS ===${COLOR_RESET}"
    echo ""

    if verificar_ss_disponible; then
        # Resumen general con awk
        ss -tuan 2>/dev/null | awk '
        BEGIN {
            tcp_listen = 0
            tcp_estab = 0
            udp = 0
            total = 0
        }
        NR > 1 {
            total++
            if ($1 == "tcp" && $2 == "LISTEN") tcp_listen++
            else if ($1 == "tcp" && $2 == "ESTAB") tcp_estab++
            else if ($1 == "udp") udp++
        }
        END {
            print "  Estadísticas generales:"
            printf "    • TCP escuchando:      %d\n", tcp_listen
            printf "    • TCP establecidas:    %d\n", tcp_estab
            printf "    • UDP activos:         %d\n", udp
            printf "    • Total sockets:       %d\n", total
        }'

        # Puertos críticos
        echo ""
        echo "  Estado de puertos críticos:"
        for puerto in 22 80 443 3306 5432 8080; do
            if ss -tln 2>/dev/null | grep -q ":$puerto "; then
                echo -e "    Puerto $puerto: ${COLOR_VERDE}ACTIVO${COLOR_RESET}"
            else
                echo -e "    Puerto $puerto: ${COLOR_AMARILLO}INACTIVO${COLOR_RESET}"
            fi
        done

        # Recomendaciones
        echo ""
        echo "  Recomendaciones:"

        # Verificar puertos peligrosos
        if ss -tln 2>/dev/null | grep -qE ":(23|135|139|445) "; then
            echo -e "    ${COLOR_ROJO}⚠ Puertos potencialmente peligrosos abiertos${COLOR_RESET}"
        fi

        # Verificar muchas conexiones TIME_WAIT
        local time_wait=$(ss -tan 2>/dev/null | grep -c "TIME-WAIT" || echo 0)
        if [[ $time_wait -gt 100 ]]; then
            echo -e "    ${COLOR_AMARILLO}⚠ Alto número de conexiones TIME_WAIT ($time_wait)${COLOR_RESET}"
        fi

        echo -e "    ${COLOR_VERDE}✓ Usar firewall para restringir acceso${COLOR_RESET}"
        echo -e "    ${COLOR_VERDE}✓ Cerrar puertos no utilizados${COLOR_RESET}"
    fi
}

# Función principal
main() {
    local accion="${1:-todo}"
    local puerto="${2:-$PUERTO_GESTOR}"

    echo -e "${COLOR_AZUL}╔══════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_AZUL}║    VERIFICACIÓN DE SOCKETS CON SS       ║${COLOR_RESET}"
    echo -e "${COLOR_AZUL}╚══════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Sistema: $(uname -s) $(uname -r)"
    echo ""

    case "$accion" in
        "tcp")
            analizar_puertos_tcp
            ;;
        "conexiones")
            analizar_conexiones_activas
            ;;
        "puerto")
            verificar_puerto_especifico "$puerto"
            ;;
        "unix")
            analizar_sockets_unix
            ;;
        "rendimiento")
            analizar_rendimiento_red
            ;;
        "todo")
            analizar_puertos_tcp
            analizar_conexiones_activas
            verificar_puerto_especifico "$puerto"
            analizar_sockets_unix
            analizar_rendimiento_red
            generar_resumen_sockets
            ;;
        *)
            echo "Uso: $0 [tcp|conexiones|puerto|unix|rendimiento|todo] [puerto]"
            echo ""
            echo "Acciones:"
            echo "  tcp         - Analizar puertos TCP"
            echo "  conexiones  - Ver conexiones activas"
            echo "  puerto      - Verificar puerto específico"
            echo "  unix        - Analizar sockets Unix"
            echo "  rendimiento - Métricas de rendimiento"
            echo "  todo        - Análisis completo"
            exit 1
            ;;
    esac

    echo ""
    echo -e "${COLOR_VERDE}=== Verificación completada ===${COLOR_RESET}"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi