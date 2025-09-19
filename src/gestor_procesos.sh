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

# Variables globales para control de señales
SIGNAL_RECIBIDA=""
EN_APAGADO=0

# Función mejorada para manejar señales
manejar_signal() {
    local signal="$1"

    # Evitar manejo múltiple de señales
    if [[ $EN_APAGADO -eq 1 ]]; then
        log_mensaje "WARN" "Ya se está procesando una señal de apagado"
        return
    fi

    SIGNAL_RECIBIDA="$signal"

    case "$signal" in
        INT)
            log_mensaje "WARN" "Recibida señal SIGINT (Ctrl+C) - interrumpiendo proceso"
            EN_APAGADO=1

            # Intentar apagado graceful si hay proceso activo
            if proceso_activo; then
                log_mensaje "INFO" "Deteniendo proceso de forma controlada..."
                detener_proceso
            fi

            limpiar_recursos
            exit $EXIT_ERROR_SIGNAL
            ;;

        TERM)
            log_mensaje "INFO" "Recibida señal SIGTERM - apagado controlado"
            EN_APAGADO=1

            # Dar tiempo para terminar operaciones en curso
            log_mensaje "INFO" "Esperando finalización de operaciones..."
            sleep 1

            if proceso_activo; then
                detener_proceso
            fi

            exit $EXIT_SUCCESS
            ;;

        HUP)
            log_mensaje "INFO" "Recibida señal SIGHUP - recargando configuración"

            # Recargar variables de entorno sin reiniciar el proceso
            if [[ -f "$PROJECT_ROOT/.env" ]]; then
                log_mensaje "INFO" "Recargando variables desde .env"
                set -a
                source "$PROJECT_ROOT/.env" 2>/dev/null || log_mensaje "WARN" "Error al recargar .env"
                set +a
                log_mensaje "INFO" "Configuración recargada exitosamente"
            else
                log_mensaje "WARN" "No se encontró archivo .env para recargar"
            fi
            ;;

        USR1)
            log_mensaje "INFO" "Recibida señal SIGUSR1 - mostrando estado detallado"

            # Mostrar información detallada del sistema
            echo "=== Estado Detallado del Sistema ==="
            echo "Fecha: $(date)"
            echo "PID del script: $$"
            echo "Variables de entorno:"
            echo "  PORT=$PORT"
            echo "  MESSAGE=$MESSAGE"
            echo "  RELEASE=$RELEASE"

            if proceso_activo; then
                local pid=$(cat "$PID_FILE")
                echo "Proceso activo: PID $pid"

                # Verificar si el proceso realmente existe
                if ps -p "$pid" > /dev/null 2>&1; then
                    echo "Estado del proceso: RUNNING"
                else
                    echo "Estado del proceso: STALE (PID obsoleto)"
                fi
            else
                echo "Proceso: INACTIVO"
            fi

            # Mostrar últimas líneas del log
            if [[ -f "$LOG_FILE" ]]; then
                echo "Últimas 5 líneas del log:"
                tail -n 5 "$LOG_FILE"
            fi
            echo "===================================="
            ;;

        USR2)
            log_mensaje "INFO" "Recibida señal SIGUSR2 - rotación de logs"

            # Rotar archivo de log si existe
            if [[ -f "$LOG_FILE" ]]; then
                local backup_log="${LOG_FILE}.$(date +%H%M%S).bak"
                mv "$LOG_FILE" "$backup_log"
                log_mensaje "INFO" "Log rotado a: $backup_log"
                log_mensaje "INFO" "Nuevo archivo de log iniciado"
            else
                log_mensaje "INFO" "No hay log para rotar"
            fi
            ;;

        QUIT)
            log_mensaje "ERROR" "Recibida señal SIGQUIT - terminación forzada"
            EN_APAGADO=1

            # Terminación inmediata sin limpieza completa
            if [[ -f "$PID_FILE" ]]; then
                rm -f "$PID_FILE"
            fi

            log_mensaje "ERROR" "Terminación forzada completada"
            exit $EXIT_ERROR_SIGNAL
            ;;

        *)
            log_mensaje "WARN" "Señal no manejada: $signal"
            ;;
    esac
}

# Función auxiliar para verificar si el proceso está activo
proceso_activo() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Configurar traps mejorados para manejo de señales
set -E
trap 'manejar_error $LINENO "$BASH_COMMAND" $?' ERR
trap 'limpiar_recursos' EXIT
trap 'manejar_signal INT' INT
trap 'manejar_signal TERM' TERM
trap 'manejar_signal HUP' HUP
trap 'manejar_signal USR1' USR1
trap 'manejar_signal USR2' USR2
trap 'manejar_signal QUIT' QUIT

# FUNCIONES DE GESTIÓN DE PROCESOS

# Función para iniciar el proceso
iniciar_proceso() {
    log_mensaje "INFO" "Iniciando proceso en puerto $PORT..."

    # Verificar si estamos en proceso de apagado
    if [[ $EN_APAGADO -eq 1 ]]; then
        log_mensaje "WARN" "No se puede iniciar proceso durante apagado"
        return $EXIT_ERROR_PROCESO
    fi

    # Verificar si el archivo PID existe
    if [[ -f "$PID_FILE" ]]; then
        local pid_existente=$(cat "$PID_FILE" 2>/dev/null)

        # Verificar si el proceso realmente existe
        if kill -0 "$pid_existente" 2>/dev/null; then
            log_mensaje "ERROR" "El proceso ya está en ejecución con PID $pid_existente"
            return $EXIT_ERROR_PROCESO
        else
            log_mensaje "WARN" "PID obsoleto encontrado, limpiando..."
            rm -f "$PID_FILE"
        fi
    fi

    # Crear directorio de logs si no existe
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" || {
            log_mensaje "ERROR" "No se pudo crear directorio de logs: $LOG_DIR"
            return $EXIT_ERROR_PERMISOS
        }
    fi

    # Verificar disponibilidad del puerto antes de iniciar
    if ! command -v lsof >/dev/null 2>&1; then
        log_mensaje "WARN" "lsof no disponible, no se puede verificar puerto"
    else
        if lsof -i:$PORT >/dev/null 2>&1; then
            log_mensaje "ERROR" "Puerto $PORT ya está en uso"
            return $EXIT_ERROR_RED
        fi
    fi

    # Crear proceso simulado con manejo de señales
    (
        # Heredar traps del proceso padre
        trap 'exit 0' TERM
        trap 'exit 0' INT

        # Bucle del proceso simulado
        while true; do
            # Verificar si debemos terminar
            if [[ $EN_APAGADO -eq 1 ]]; then
                exit 0
            fi

            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $MESSAGE - Release: $RELEASE - Puerto: $PORT" >> "$LOG_FILE"
            sleep 5
        done
    ) &

    local nuevo_pid=$!

    # Guardar PID con verificación
    echo "$nuevo_pid" > "$PID_FILE" || {
        log_mensaje "ERROR" "No se pudo crear archivo PID"
        kill -TERM "$nuevo_pid" 2>/dev/null
        return $EXIT_ERROR_PERMISOS
    }

    log_mensaje "INFO" "Proceso iniciado con PID $nuevo_pid en puerto $PORT"
    log_mensaje "INFO" "Versión: $RELEASE"
    log_mensaje "INFO" "Mensaje: $MESSAGE"
    log_mensaje "INFO" "Logs en: $LOG_FILE"
    log_mensaje "INFO" "Señales disponibles: INT, TERM, HUP, USR1, USR2, QUIT"

    return $EXIT_SUCCESS
}

# Función mejorada para detener el proceso
detener_proceso() {
    log_mensaje "INFO" "Deteniendo proceso..."

    # Verificar si el archivo PID existe
    if [[ ! -f "$PID_FILE" ]]; then
        log_mensaje "WARN" "No hay proceso activo para detener"
        return $EXIT_SUCCESS
    fi

    # Leer PID del archivo
    local pid=$(cat "$PID_FILE" 2>/dev/null) || {
        log_mensaje "ERROR" "No se pudo leer archivo PID"
        return $EXIT_ERROR_PERMISOS
    }

    # Verificar si el proceso existe antes de intentar detenerlo
    if ! kill -0 "$pid" 2>/dev/null; then
        log_mensaje "WARN" "Proceso $pid no existe, limpiando PID obsoleto"
        rm -f "$PID_FILE"
        return $EXIT_SUCCESS
    fi

    log_mensaje "INFO" "Enviando señal SIGTERM al proceso $pid..."

    # Intentar terminar gracefully con SIGTERM
    if kill -TERM "$pid" 2>/dev/null; then
        local contador=0
        local max_espera=10

        # Esperar hasta que el proceso termine
        while [[ $contador -lt $max_espera ]] && kill -0 "$pid" 2>/dev/null; do
            log_mensaje "INFO" "Esperando que el proceso termine... ($((contador+1))/$max_espera)"
            sleep 1
            ((contador++))
        done

        # Si el proceso aún existe, usar SIGKILL
        if kill -0 "$pid" 2>/dev/null; then
            log_mensaje "WARN" "El proceso no respondió a SIGTERM, enviando SIGKILL..."
            kill -KILL "$pid" 2>/dev/null

            # Esperar un momento para la terminación forzada
            sleep 1

            if kill -0 "$pid" 2>/dev/null; then
                log_mensaje "ERROR" "No se pudo terminar el proceso $pid"
                return $EXIT_ERROR_PROCESO
            else
                log_mensaje "INFO" "Proceso terminado forzosamente con SIGKILL"
            fi
        else
            log_mensaje "INFO" "Proceso terminado exitosamente con SIGTERM"
        fi
    else
        log_mensaje "ERROR" "No se pudo enviar señal al proceso $pid"
        return $EXIT_ERROR_PROCESO
    fi

    # Eliminar archivo PID
    rm -f "$PID_FILE" || {
        log_mensaje "ERROR" "No se pudo eliminar archivo PID"
        return $EXIT_ERROR_PERMISOS
    }

    log_mensaje "INFO" "Proceso con PID $pid detenido completamente"

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

# Función para control via systemctl
controlar_servicio_systemd() {
    local accion="$1"
    local servicio="gestor-web.service"

    # Verificar si systemd está disponible
    if ! command -v systemctl >/dev/null 2>&1; then
        log_mensaje "ERROR" "systemctl no está disponible en este sistema"
        return $EXIT_ERROR_DEPENDENCIA
    fi

    # Verificar si el servicio está instalado
    if ! systemctl list-unit-files 2>/dev/null | grep -q "$servicio"; then
        log_mensaje "WARN" "Servicio $servicio no está instalado"
        log_mensaje "INFO" "Use 'sudo systemd/gestionar-servicio.sh instalar' para instalar"
        return $EXIT_ERROR_CONFIGURACION
    fi

    case "$accion" in
        start)
            log_mensaje "INFO" "Iniciando servicio via systemctl..."
            if sudo systemctl start "$servicio"; then
                log_mensaje "INFO" "Servicio iniciado correctamente"
                sudo systemctl status "$servicio" --no-pager | head -10
                return $EXIT_SUCCESS
            else
                log_mensaje "ERROR" "Error al iniciar servicio"
                return $EXIT_ERROR_PROCESO
            fi
            ;;
        stop)
            log_mensaje "INFO" "Deteniendo servicio via systemctl..."
            if sudo systemctl stop "$servicio"; then
                log_mensaje "INFO" "Servicio detenido correctamente"
                return $EXIT_SUCCESS
            else
                log_mensaje "ERROR" "Error al detener servicio"
                return $EXIT_ERROR_PROCESO
            fi
            ;;
        restart)
            log_mensaje "INFO" "Reiniciando servicio via systemctl..."
            if sudo systemctl restart "$servicio"; then
                log_mensaje "INFO" "Servicio reiniciado correctamente"
                sudo systemctl status "$servicio" --no-pager | head -10
                return $EXIT_SUCCESS
            else
                log_mensaje "ERROR" "Error al reiniciar servicio"
                return $EXIT_ERROR_PROCESO
            fi
            ;;
        reload)
            log_mensaje "INFO" "Recargando configuración via systemctl..."
            if sudo systemctl reload "$servicio"; then
                log_mensaje "INFO" "Configuración recargada correctamente"
                return $EXIT_SUCCESS
            else
                log_mensaje "ERROR" "Error al recargar configuración"
                return $EXIT_ERROR_PROCESO
            fi
            ;;
        status)
            log_mensaje "INFO" "Estado del servicio systemd:"
            sudo systemctl status "$servicio" --no-pager || true
            echo ""
            log_mensaje "INFO" "Últimas líneas del journal:"
            sudo journalctl -u "$servicio" -n 10 --no-pager || true
            return $EXIT_SUCCESS
            ;;
        enable)
            log_mensaje "INFO" "Habilitando servicio para inicio automático..."
            if sudo systemctl enable "$servicio"; then
                log_mensaje "INFO" "Servicio habilitado para inicio automático"
                return $EXIT_SUCCESS
            else
                log_mensaje "ERROR" "Error al habilitar servicio"
                return $EXIT_ERROR_PROCESO
            fi
            ;;
        disable)
            log_mensaje "INFO" "Deshabilitando inicio automático..."
            if sudo systemctl disable "$servicio"; then
                log_mensaje "INFO" "Inicio automático deshabilitado"
                return $EXIT_SUCCESS
            else
                log_mensaje "ERROR" "Error al deshabilitar servicio"
                return $EXIT_ERROR_PROCESO
            fi
            ;;
        *)
            log_mensaje "ERROR" "Acción desconocida: $accion"
            return $EXIT_ERROR_VALIDACION
            ;;
    esac
}

# Función para analizar logs con journalctl
analizar_logs() {
    local servicio="gestor-web.service"
    local desde="${1:-1 hour ago}"

    log_mensaje "INFO" "=== Análisis de logs del sistema ==="

    # Verificar si journalctl está disponible
    if ! command -v journalctl >/dev/null 2>&1; then
        log_mensaje "WARN" "journalctl no disponible, analizando logs tradicionales"
        analizar_logs_tradicionales
        return $?
    fi

    # Si systemd está disponible, analizar logs del servicio
    if systemctl list-unit-files 2>/dev/null | grep -q "$servicio"; then
        echo ""
        echo "=== Logs del servicio systemd ==="

        # Contar mensajes por nivel usando awk
        echo ""
        echo "Distribución de mensajes (última hora):"
        journalctl -u "$servicio" --since "$desde" --no-pager 2>/dev/null | \
            awk '/INFO/ {info++}
                 /WARN/ {warn++}
                 /ERROR/ {error++}
                 END {
                     printf "  ✓ INFO:  %d mensajes\n", info+0
                     printf "  ⚠ WARN:  %d mensajes\n", warn+0
                     printf "  ✗ ERROR: %d mensajes\n", error+0
                 }'

        # Mostrar últimos errores
        echo ""
        echo "Últimos errores del servicio:"
        journalctl -u "$servicio" --since "$desde" --no-pager 2>/dev/null | \
            grep "ERROR" | \
            tail -5 || echo "  No se encontraron errores recientes"

        # Análisis de reinicios
        echo ""
        echo "Reinicios del servicio hoy:"
        local reinicios=$(journalctl -u "$servicio" --since today --no-pager 2>/dev/null | \
            grep -c "Started\|Stopped" || echo "0")
        echo "  Cantidad de reinicios: $reinicios"

        # Tiempo de actividad
        echo ""
        echo "Estado actual del servicio:"
        if systemctl is-active "$servicio" >/dev/null 2>&1; then
            local uptime=$(systemctl show "$servicio" --property=ActiveEnterTimestamp | cut -d= -f2)
            echo "  ✓ Servicio activo desde: $uptime"
        else
            echo "  ✗ Servicio no activo"
        fi
    fi

    # Analizar logs tradicionales también
    echo ""
    echo "=== Logs del proceso tradicional ==="
    analizar_logs_tradicionales

    return $EXIT_SUCCESS
}

# Función auxiliar para analizar logs tradicionales
analizar_logs_tradicionales() {
    # Verificar si existe el archivo de log
    if [[ ! -f "$LOG_FILE" ]]; then
        log_mensaje "INFO" "No hay archivo de log tradicional"
        return $EXIT_SUCCESS
    fi

    echo ""
    echo "Archivo de log: $LOG_FILE"

    # Tamaño del archivo
    local tamano=$(du -h "$LOG_FILE" 2>/dev/null | cut -f1)
    echo "Tamaño: $tamano"

    # Contar líneas totales
    local total_lineas=$(wc -l < "$LOG_FILE" 2>/dev/null)
    echo "Total de líneas: $total_lineas"

    # Análisis con awk
    echo ""
    echo "Análisis del contenido:"

    # Extraer y analizar tiempos
    if grep -q "Release:" "$LOG_FILE" 2>/dev/null; then
        echo ""
        echo "Versiones detectadas:"
        awk '/Release:/ {releases[$7]++}
             END {for (r in releases) printf "  %s: %d veces\n", r, releases[r]}' "$LOG_FILE"
    fi

    # Extraer puertos utilizados
    if grep -q "Puerto:" "$LOG_FILE" 2>/dev/null; then
        echo ""
        echo "Puertos utilizados:"
        awk -F'Puerto: ' '/Puerto:/ {ports[$2]++}
             END {for (p in ports) printf "  Puerto %s: %d veces\n", p, ports[p]}' "$LOG_FILE"
    fi

    # Mostrar últimas líneas
    echo ""
    echo "Últimas 10 entradas del log:"
    tail -10 "$LOG_FILE" | sed 's/^/  /'

    return $EXIT_SUCCESS
}

# Función principal
main() {
    local comando="${1:-ayuda}"
    local resultado=0

    case "$comando" in
        # Comandos tradicionales
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
        # Comandos de systemctl
        systemctl)
            shift
            local subcomando="${1:-}"
            case "$subcomando" in
                start|stop|restart|reload|status|enable|disable)
                    controlar_servicio_systemd "$subcomando"
                    resultado=$?
                    ;;
                *)
                    echo "Uso: $SCRIPT_NAME systemctl {start|stop|restart|reload|status|enable|disable}"
                    resultado=$EXIT_ERROR_VALIDACION
                    ;;
            esac
            ;;
        # Alias directos para systemctl
        start|stop|restart|reload)
            controlar_servicio_systemd "$comando"
            resultado=$?
            ;;
        # Comando de análisis de logs
        logs|analizar-logs)
            shift
            analizar_logs "${1:-1 hour ago}"
            resultado=$?
            ;;
        # Comando de análisis avanzado con awk
        metricas|analizar-metricas)
            # Ejecutar script de análisis avanzado
            local script_metricas="$SCRIPT_DIR/analizar_metricas.sh"
            if [[ -x "$script_metricas" ]]; then
                "$script_metricas"
                resultado=$?
            else
                log_mensaje "ERROR" "Script de métricas no encontrado: $script_metricas"
                resultado=$EXIT_ERROR_CONFIGURACION
            fi
            ;;
        *)
            echo "Uso: $SCRIPT_NAME {iniciar|detener|estado|logs|metricas|start|stop|restart|reload|systemctl}"
            echo ""
            echo "Comandos básicos (sin systemd):"
            echo "  iniciar  - Inicia el proceso gestor"
            echo "  detener  - Detiene el proceso gestor"
            echo "  estado   - Muestra el estado actual"
            echo "  logs     - Analiza logs del sistema"
            echo "  metricas - Análisis avanzado con awk"
            echo ""
            echo "Comandos systemd:"
            echo "  start    - Inicia servicio via systemctl"
            echo "  stop     - Detiene servicio via systemctl"
            echo "  restart  - Reinicia servicio via systemctl"
            echo "  reload   - Recarga configuración via systemctl"
            echo ""
            echo "Control avanzado:"
            echo "  systemctl status  - Ver estado detallado del servicio"
            echo "  systemctl enable  - Habilitar inicio automático"
            echo "  systemctl disable - Deshabilitar inicio automático"
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