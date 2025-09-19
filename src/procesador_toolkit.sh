#!/bin/bash
# Descripción: Procesador con Unix toolkit - cut, tee, y más herramientas
# Autor: Equipo 12
# Fecha: 2025-09-19

set -euo pipefail

# Variables
readonly LOG_DIR="${LOG_DIR:-/tmp/toolkit-logs}"
readonly REPORT_FILE="$LOG_DIR/reporte-$(date +%Y%m%d-%H%M%S).txt"
readonly TEMP_DIR="/tmp/toolkit-$$"

# Crear directorios necesarios
mkdir -p "$LOG_DIR" "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# Función para procesar logs con cut y tee
procesar_logs_sistema() {
    local log_file="${1:-/tmp/gestor-logs/gestor-web-$(date +%Y%m%d).log}"

    echo "=== Procesamiento de Logs con Unix Toolkit ===" | tee "$REPORT_FILE"
    echo "Fecha: $(date)" | tee -a "$REPORT_FILE"
    echo "Archivo procesado: $log_file" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"

    if [[ ! -f "$log_file" ]]; then
        echo "Error: Archivo de log no encontrado: $log_file" | tee -a "$REPORT_FILE"
        return 1
    fi

    # Extraer campos con cut y guardar con tee
    echo "1. Extrayendo timestamps (campo 1-2):" | tee -a "$REPORT_FILE"
    echo "----------------------------------------" | tee -a "$REPORT_FILE"

    # Usar cut para extraer fecha y hora, tee para mostrar y guardar
    grep "^\[" "$log_file" 2>/dev/null | \
        cut -d' ' -f1-2 | \
        sed 's/\[//g; s/\]//g' | \
        head -5 | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/timestamps.txt"

    echo "" | tee -a "$REPORT_FILE"

    # Extraer niveles de log con cut
    echo "2. Niveles de log encontrados:" | tee -a "$REPORT_FILE"
    echo "-------------------------------" | tee -a "$REPORT_FILE"

    grep "^\[" "$log_file" 2>/dev/null | \
        cut -d'[' -f3 | \
        cut -d']' -f1 | \
        sort | uniq -c | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/niveles.txt"

    echo "" | tee -a "$REPORT_FILE"

    # Procesar mensajes de error con cut
    echo "3. Mensajes de error (primeras 50 caracteres):" | tee -a "$REPORT_FILE"
    echo "------------------------------------------------" | tee -a "$REPORT_FILE"

    grep "ERROR" "$log_file" 2>/dev/null | \
        cut -d']' -f4- | \
        cut -c1-50 | \
        head -5 | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/errores.txt"

    echo "" | tee -a "$REPORT_FILE"

    # Análisis de puertos con cut
    echo "4. Puertos detectados en logs:" | tee -a "$REPORT_FILE"
    echo "-------------------------------" | tee -a "$REPORT_FILE"

    grep -i "puerto" "$log_file" 2>/dev/null | \
        cut -d':' -f2- | \
        grep -o "[0-9]\{4,5\}" | \
        sort -u | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/puertos.txt"

    echo "" | tee -a "$REPORT_FILE"
}

# Función para procesar salida de comandos de red
procesar_salida_red() {
    echo "=== Procesamiento de Información de Red ===" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"

    # Procesar salida de netstat con cut
    echo "1. Conexiones TCP activas (IP:Puerto):" | tee -a "$REPORT_FILE"
    echo "---------------------------------------" | tee -a "$REPORT_FILE"

    netstat -tan 2>/dev/null | \
        grep "^tcp" | \
        grep "ESTABLISHED" | \
        cut -c45-65,68-88 | \
        head -5 | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/conexiones.txt"

    echo "" | tee -a "$REPORT_FILE"

    # Procesar información de interfaces con cut
    echo "2. Interfaces de red (nombre y estado):" | tee -a "$REPORT_FILE"
    echo "----------------------------------------" | tee -a "$REPORT_FILE"

    ifconfig 2>/dev/null | \
        grep "^[a-z]" | \
        cut -d: -f1 | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/interfaces.txt"

    echo "" | tee -a "$REPORT_FILE"

    # Procesar tabla de rutas con cut
    echo "3. Tabla de rutas simplificada:" | tee -a "$REPORT_FILE"
    echo "--------------------------------" | tee -a "$REPORT_FILE"

    netstat -rn 2>/dev/null | \
        tail -n +3 | \
        cut -c1-20,21-40,41-60 | \
        head -5 | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/rutas.txt"

    echo "" | tee -a "$REPORT_FILE"
}

# Función para procesar información de procesos
procesar_info_procesos() {
    echo "=== Procesamiento de Información de Procesos ===" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"

    # Top procesos por CPU con cut
    echo "1. Top 5 procesos por uso de CPU:" | tee -a "$REPORT_FILE"
    echo "----------------------------------" | tee -a "$REPORT_FILE"

    ps aux 2>/dev/null | \
        sort -nrk 3 | \
        head -6 | \
        tail -5 | \
        cut -c1-10,61-80,11-15 | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/cpu_top.txt"

    echo "" | tee -a "$REPORT_FILE"

    # Top procesos por memoria con cut
    echo "2. Top 5 procesos por uso de memoria:" | tee -a "$REPORT_FILE"
    echo "--------------------------------------" | tee -a "$REPORT_FILE"

    ps aux 2>/dev/null | \
        sort -nrk 4 | \
        head -6 | \
        tail -5 | \
        cut -c1-10,61-80,16-20 | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/mem_top.txt"

    echo "" | tee -a "$REPORT_FILE"

    # Procesos del usuario actual
    echo "3. Procesos del usuario $(whoami):" | tee -a "$REPORT_FILE"
    echo "------------------------------------" | tee -a "$REPORT_FILE"

    ps -u "$(whoami)" 2>/dev/null | \
        tail -n +2 | \
        cut -c1-10,25-35,48- | \
        head -5 | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/user_procs.txt"

    echo "" | tee -a "$REPORT_FILE"
}

# Función para análisis combinado con múltiples herramientas
analisis_combinado() {
    echo "=== Análisis Combinado con Unix Toolkit ===" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"

    # Pipeline complejo: grep | cut | sort | uniq | tee
    echo "1. Análisis de patrones en logs:" | tee -a "$REPORT_FILE"
    echo "---------------------------------" | tee -a "$REPORT_FILE"

    local log_file="/tmp/gestor-logs/gestor-web-$(date +%Y%m%d).log"

    if [[ -f "$log_file" ]]; then
        # Extraer, cortar, ordenar, contar únicos y guardar
        grep -o "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" "$log_file" 2>/dev/null | \
            sort | \
            uniq -c | \
            sort -rn | \
            head -5 | \
            tee -a "$REPORT_FILE" "$TEMP_DIR/ips_frecuentes.txt"
    else
        echo "  Archivo de log no encontrado" | tee -a "$REPORT_FILE"
    fi

    echo "" | tee -a "$REPORT_FILE"

    # Análisis de uso de disco con cut y tee
    echo "2. Uso de disco por partición:" | tee -a "$REPORT_FILE"
    echo "-------------------------------" | tee -a "$REPORT_FILE"

    df -h 2>/dev/null | \
        tail -n +2 | \
        cut -c1-25,36-40,42-50,52-60 | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/disco.txt"

    echo "" | tee -a "$REPORT_FILE"

    # Análisis de carga del sistema
    echo "3. Carga del sistema:" | tee -a "$REPORT_FILE"
    echo "---------------------" | tee -a "$REPORT_FILE"

    uptime | \
        cut -d',' -f3- | \
        tee -a "$REPORT_FILE" "$TEMP_DIR/carga.txt"

    echo "" | tee -a "$REPORT_FILE"

    # Memoria disponible con free y cut
    echo "4. Uso de memoria:" | tee -a "$REPORT_FILE"
    echo "------------------" | tee -a "$REPORT_FILE"

    if command -v free >/dev/null 2>&1; then
        free -h 2>/dev/null | \
            grep "^Mem:" | \
            cut -c8-30,32-40,42-50 | \
            tee -a "$REPORT_FILE" "$TEMP_DIR/memoria.txt"
    else
        # En macOS usar vm_stat
        vm_stat 2>/dev/null | \
            head -5 | \
            cut -c1-30,31-50 | \
            tee -a "$REPORT_FILE" "$TEMP_DIR/memoria.txt"
    fi

    echo "" | tee -a "$REPORT_FILE"
}

# Función para generar resumen
generar_resumen() {
    echo "=== RESUMEN DEL PROCESAMIENTO ===" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"

    # Contar archivos generados
    local archivos_generados=$(ls -1 "$TEMP_DIR" 2>/dev/null | wc -l)
    echo "Archivos temporales generados: $archivos_generados" | tee -a "$REPORT_FILE"

    # Listar archivos con tamaños
    echo "" | tee -a "$REPORT_FILE"
    echo "Archivos procesados:" | tee -a "$REPORT_FILE"
    ls -lh "$TEMP_DIR" 2>/dev/null | \
        tail -n +2 | \
        cut -c31-40,47- | \
        tee -a "$REPORT_FILE"

    echo "" | tee -a "$REPORT_FILE"
    echo "Reporte guardado en: $REPORT_FILE" | tee -a "$REPORT_FILE"

    # Estadísticas del reporte
    echo "" | tee -a "$REPORT_FILE"
    echo "Estadísticas del reporte:" | tee -a "$REPORT_FILE"
    echo "  Líneas totales: $(wc -l < "$REPORT_FILE")" | tee -a "$REPORT_FILE"
    echo "  Tamaño: $(du -h "$REPORT_FILE" | cut -f1)" | tee -a "$REPORT_FILE"
    echo "  Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$REPORT_FILE"
}

# Función principal
main() {
    local opcion="${1:-todo}"

    echo "╔══════════════════════════════════════════╗"
    echo "║   PROCESADOR CON UNIX TOOLKIT (cut/tee)  ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    case "$opcion" in
        logs)
            procesar_logs_sistema "${2:-}"
            ;;
        red)
            procesar_salida_red
            ;;
        procesos)
            procesar_info_procesos
            ;;
        analisis)
            analisis_combinado
            ;;
        todo)
            procesar_logs_sistema
            echo "" | tee -a "$REPORT_FILE"
            procesar_salida_red
            echo "" | tee -a "$REPORT_FILE"
            procesar_info_procesos
            echo "" | tee -a "$REPORT_FILE"
            analisis_combinado
            ;;
        *)
            echo "Uso: $0 [logs|red|procesos|analisis|todo] [archivo_log]"
            echo ""
            echo "Opciones:"
            echo "  logs     - Procesar archivos de log"
            echo "  red      - Procesar información de red"
            echo "  procesos - Procesar información de procesos"
            echo "  analisis - Análisis combinado"
            echo "  todo     - Ejecutar todo el procesamiento"
            exit 1
            ;;
    esac

    generar_resumen

    echo ""
    echo "=== Procesamiento completado ===" | tee -a "$REPORT_FILE"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi