#!/bin/bash
# Script auxiliar para gestionar el servicio systemd del gestor web

set -euo pipefail

# Colores para output
readonly COLOR_ROJO='\033[0;31m'
readonly COLOR_VERDE='\033[0;32m'
readonly COLOR_AMARILLO='\033[1;33m'
readonly COLOR_AZUL='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Función para imprimir mensajes con color
imprimir() {
    local color="$1"
    local mensaje="$2"
    echo -e "${color}${mensaje}${COLOR_RESET}"
}

# Función para verificar si se ejecuta como root
verificar_root() {
    if [[ $EUID -ne 0 ]]; then
        imprimir "$COLOR_ROJO" "Error: Este script debe ejecutarse como root (usar sudo)"
        exit 1
    fi
}

# Función para instalar el servicio
instalar_servicio() {
    imprimir "$COLOR_AZUL" "=== Instalando servicio gestor-web ==="

    # Crear directorios
    imprimir "$COLOR_AMARILLO" "Creando directorios..."
    mkdir -p /opt/gestor-web/src
    mkdir -p /etc/gestor-web
    mkdir -p /var/log/gestor-web
    mkdir -p /var/run

    # Copiar archivos
    imprimir "$COLOR_AMARILLO" "Copiando archivos..."
    cp -r ../src/* /opt/gestor-web/src/
    cp gestor.conf.example /etc/gestor-web/gestor.conf
    cp gestor-web.service /etc/systemd/system/

    # Ajustar permisos
    imprimir "$COLOR_AMARILLO" "Ajustando permisos..."
    chown -R nobody:nogroup /opt/gestor-web
    chown -R nobody:nogroup /var/log/gestor-web
    chmod +x /opt/gestor-web/src/gestor_procesos.sh

    # Recargar systemd
    imprimir "$COLOR_AMARILLO" "Recargando systemd..."
    systemctl daemon-reload

    # Habilitar servicio
    systemctl enable gestor-web.service

    imprimir "$COLOR_VERDE" "✓ Servicio instalado exitosamente"
    imprimir "$COLOR_AZUL" "Usa 'sudo systemctl start gestor-web' para iniciar"
}

# Función para desinstalar el servicio
desinstalar_servicio() {
    imprimir "$COLOR_AZUL" "=== Desinstalando servicio gestor-web ==="

    # Detener servicio si está activo
    if systemctl is-active --quiet gestor-web; then
        imprimir "$COLOR_AMARILLO" "Deteniendo servicio..."
        systemctl stop gestor-web
    fi

    # Deshabilitar servicio
    if systemctl is-enabled --quiet gestor-web; then
        imprimir "$COLOR_AMARILLO" "Deshabilitando servicio..."
        systemctl disable gestor-web
    fi

    # Eliminar archivos
    imprimir "$COLOR_AMARILLO" "Eliminando archivos..."
    rm -f /etc/systemd/system/gestor-web.service
    rm -rf /opt/gestor-web
    rm -rf /etc/gestor-web
    rm -rf /var/log/gestor-web

    # Recargar systemd
    systemctl daemon-reload

    imprimir "$COLOR_VERDE" "✓ Servicio desinstalado exitosamente"
}

# Función para mostrar estado del servicio
mostrar_estado() {
    imprimir "$COLOR_AZUL" "=== Estado del servicio gestor-web ==="

    # Estado básico
    systemctl status gestor-web --no-pager || true

    echo ""
    imprimir "$COLOR_AZUL" "=== Últimas líneas del log ==="
    journalctl -u gestor-web -n 10 --no-pager || true

    echo ""
    imprimir "$COLOR_AZUL" "=== Métricas del servicio ==="

    # Obtener PID si existe
    local pid=$(systemctl show gestor-web --property MainPID | cut -d= -f2)

    if [[ "$pid" != "0" ]]; then
        imprimir "$COLOR_VERDE" "PID activo: $pid"

        # Uso de CPU y memoria
        if command -v ps >/dev/null 2>&1; then
            echo "Uso de recursos:"
            ps -p "$pid" -o pid,vsz,rss,cpu,comm
        fi

        # Puerto en uso
        if command -v ss >/dev/null 2>&1; then
            echo ""
            echo "Puertos en escucha:"
            ss -tlpn | grep "$pid" || echo "No hay puertos abiertos"
        fi
    else
        imprimir "$COLOR_AMARILLO" "Servicio no activo"
    fi
}

# Función para analizar logs
analizar_logs() {
    imprimir "$COLOR_AZUL" "=== Análisis de logs del servicio ==="

    # Contar mensajes por nivel
    echo "Mensajes por nivel de log:"
    journalctl -u gestor-web --since "1 hour ago" | \
        awk '{if ($5 ~ /\[INFO\]/) info++;
              if ($5 ~ /\[WARN\]/) warn++;
              if ($5 ~ /\[ERROR\]/) error++}
         END {print "  INFO: " info "\n  WARN: " warn "\n  ERROR: " error}'

    echo ""
    echo "Errores en la última hora:"
    journalctl -u gestor-web --since "1 hour ago" | \
        grep "ERROR" | \
        tail -5 || echo "No hay errores recientes"

    echo ""
    echo "Reinicios del servicio hoy:"
    journalctl -u gestor-web --since today | \
        grep "Started\|Stopped" | \
        wc -l
}

# Función para recargar configuración
recargar_config() {
    imprimir "$COLOR_AZUL" "=== Recargando configuración ==="

    # Verificar si el servicio está activo
    if ! systemctl is-active --quiet gestor-web; then
        imprimir "$COLOR_ROJO" "Error: El servicio no está activo"
        exit 1
    fi

    # Recargar
    systemctl reload gestor-web

    imprimir "$COLOR_VERDE" "✓ Configuración recargada"

    # Mostrar últimas líneas del log
    sleep 2
    journalctl -u gestor-web -n 5 --no-pager
}

# Función de ayuda
mostrar_ayuda() {
    cat <<EOF
Uso: $0 {instalar|desinstalar|estado|logs|recargar|ayuda}

Comandos disponibles:
  instalar      Instala el servicio systemd
  desinstalar   Desinstala el servicio systemd
  estado        Muestra el estado actual del servicio
  logs          Analiza los logs del servicio
  recargar      Recarga la configuración (SIGHUP)
  ayuda         Muestra esta ayuda

Ejemplos:
  sudo $0 instalar      # Instala el servicio
  sudo $0 estado        # Ver estado actual
  sudo $0 logs          # Analizar logs
  sudo $0 recargar      # Recargar configuración

Nota: La mayoría de comandos requieren permisos de root (sudo)
EOF
}

# Función principal
main() {
    local comando="${1:-ayuda}"

    case "$comando" in
        instalar)
            verificar_root
            instalar_servicio
            ;;
        desinstalar)
            verificar_root
            desinstalar_servicio
            ;;
        estado)
            mostrar_estado
            ;;
        logs)
            analizar_logs
            ;;
        recargar)
            verificar_root
            recargar_config
            ;;
        ayuda|--help|-h)
            mostrar_ayuda
            ;;
        *)
            imprimir "$COLOR_ROJO" "Comando desconocido: $comando"
            echo ""
            mostrar_ayuda
            exit 1
            ;;
    esac
}

# Ejecutar función principal
main "$@"