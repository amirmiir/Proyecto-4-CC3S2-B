#!/bin/bash
# Test de control via systemctl

set -euo pipefail

# Colores para output
readonly COLOR_VERDE='\033[0;32m'
readonly COLOR_ROJO='\033[0;31m'
readonly COLOR_RESET='\033[0m'

# Script a probar
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly GESTOR_SCRIPT="$SCRIPT_DIR/../src/gestor_procesos.sh"

echo "=== Pruebas de control via systemctl ==="
echo ""

# Test 1: Verificar ayuda
echo "1. Verificando comando de ayuda..."
if $GESTOR_SCRIPT | grep -q "Comandos systemd:"; then
    echo -e "${COLOR_VERDE}✓ Ayuda muestra comandos systemd${COLOR_RESET}"
else
    echo -e "${COLOR_ROJO}✗ Ayuda no muestra comandos systemd${COLOR_RESET}"
fi

# Test 2: Verificar disponibilidad de systemctl
echo ""
echo "2. Verificando disponibilidad de systemctl..."
if command -v systemctl >/dev/null 2>&1; then
    echo -e "${COLOR_VERDE}✓ systemctl está disponible${COLOR_RESET}"

    # Test 3: Verificar si el servicio está instalado
    echo ""
    echo "3. Verificando instalación del servicio..."
    if systemctl list-unit-files 2>/dev/null | grep -q "gestor-web.service"; then
        echo -e "${COLOR_VERDE}✓ Servicio gestor-web.service está instalado${COLOR_RESET}"

        # Test 4: Probar comando status
        echo ""
        echo "4. Probando comando status..."
        if $GESTOR_SCRIPT systemctl status >/dev/null 2>&1; then
            echo -e "${COLOR_VERDE}✓ Comando systemctl status funciona${COLOR_RESET}"
        else
            echo -e "${COLOR_ROJO}✗ Error en comando systemctl status${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_ROJO}✗ Servicio no instalado${COLOR_RESET}"
        echo "  Para instalar: sudo systemd/gestionar-servicio.sh instalar"
    fi
else
    echo -e "${COLOR_ROJO}✗ systemctl no está disponible en este sistema${COLOR_RESET}"
fi

# Test 5: Verificar alias de comandos
echo ""
echo "5. Verificando alias de comandos..."
for cmd in start stop restart reload; do
    if $GESTOR_SCRIPT 2>&1 | grep -q "$cmd.*systemctl"; then
        echo -e "${COLOR_VERDE}✓ Comando '$cmd' disponible${COLOR_RESET}"
    else
        echo -e "${COLOR_ROJO}✗ Comando '$cmd' no encontrado${COLOR_RESET}"
    fi
done

# Test 6: Proceso tradicional sigue funcionando
echo ""
echo "6. Verificando compatibilidad con proceso tradicional..."
$GESTOR_SCRIPT iniciar >/dev/null 2>&1
if $GESTOR_SCRIPT estado | grep -q "Proceso activo"; then
    echo -e "${COLOR_VERDE}✓ Proceso tradicional funciona${COLOR_RESET}"
    $GESTOR_SCRIPT detener >/dev/null 2>&1
else
    echo -e "${COLOR_ROJO}✗ Problema con proceso tradicional${COLOR_RESET}"
fi

echo ""
echo "=== Pruebas completadas ==="