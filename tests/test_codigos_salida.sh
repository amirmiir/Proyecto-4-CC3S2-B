#!/bin/bash
# Script de prueba para códigos de salida

set -euo pipefail

# Colores para output
readonly COLOR_VERDE='\033[0;32m'
readonly COLOR_ROJO='\033[0;31m'
readonly COLOR_AMARILLO='\033[0;33m'
readonly COLOR_RESET='\033[0m'

# Cargar definiciones del script principal
source "$(dirname "$0")/../src/gestor_procesos.sh" 2>/dev/null || {
    echo "Error: No se pudo cargar gestor_procesos.sh"
    exit 1
}

echo "========================================="
echo "  PRUEBA DE CÓDIGOS DE SALIDA"
echo "========================================="
echo ""

# Test 1: Verificar todas las constantes definidas
echo "1. Verificando definición de constantes..."
echo ""

codigos_esperados=(
    "EXIT_SUCCESS:0"
    "EXIT_ERROR_GENERAL:1"
    "EXIT_ERROR_PERMISOS:2"
    "EXIT_ERROR_PROCESO:3"
    "EXIT_ERROR_RED:4"
    "EXIT_ERROR_CONFIGURACION:5"
    "EXIT_ERROR_SIGNAL:6"
    "EXIT_ERROR_TIMEOUT:7"
    "EXIT_ERROR_DEPENDENCIA:8"
    "EXIT_ERROR_VALIDACION:9"
    "EXIT_ERROR_ARCHIVO:10"
    "EXIT_ERROR_MEMORIA:11"
    "EXIT_ERROR_DISCO:12"
    "EXIT_ERROR_SERVICIO:13"
    "EXIT_ERROR_AUTENTICACION:14"
    "EXIT_ERROR_PROTOCOLO:15"
    "EXIT_ERROR_VERSION:16"
    "EXIT_ERROR_ESTADO:17"
    "EXIT_ERROR_RECURSO:18"
    "EXIT_ERROR_LIMITE:19"
    "EXIT_ERROR_USUARIO:20"
)

errores=0
for definicion in "${codigos_esperados[@]}"; do
    nombre="${definicion%%:*}"
    valor_esperado="${definicion##*:}"

    # Evaluar la variable
    if eval "test -n \"\${${nombre}+x}\""; then
        valor_actual=$(eval "echo \$${nombre}")
        if [[ "$valor_actual" == "$valor_esperado" ]]; then
            echo -e "  ${COLOR_VERDE}✓${COLOR_RESET} $nombre = $valor_actual"
        else
            echo -e "  ${COLOR_ROJO}✗${COLOR_RESET} $nombre = $valor_actual (esperado: $valor_esperado)"
            ((errores++))
        fi
    else
        echo -e "  ${COLOR_ROJO}✗${COLOR_RESET} $nombre no está definido"
        ((errores++))
    fi
done

echo ""
if [[ $errores -eq 0 ]]; then
    echo -e "${COLOR_VERDE}✓ Todas las constantes están correctamente definidas${COLOR_RESET}"
else
    echo -e "${COLOR_ROJO}✗ Se encontraron $errores errores en las constantes${COLOR_RESET}"
fi

# Test 2: Verificar función obtener_mensaje_error
echo ""
echo "2. Probando función obtener_mensaje_error()..."
echo ""

for codigo in {0..20} 130 143 137 999; do
    mensaje=$(obtener_mensaje_error $codigo)
    printf "  Código %3d: %s\n" "$codigo" "$mensaje"
done

# Test 3: Simular diferentes escenarios de error
echo ""
echo "3. Simulando escenarios de error..."
echo ""

# Función de prueba que simula diferentes errores
probar_escenario() {
    local descripcion="$1"
    local codigo="$2"

    echo -n "  $descripcion: "

    # Ejecutar en subshell para capturar salida
    (
        case $codigo in
            2)
                # Simular error de permisos
                if [[ ! -w "/root" ]]; then
                    salir_con_error $EXIT_ERROR_PERMISOS "No se puede escribir en /root"
                fi
                ;;
            4)
                # Simular puerto en uso
                if nc -z localhost 80 2>/dev/null; then
                    salir_con_error $EXIT_ERROR_RED "Puerto 80 en uso"
                fi
                ;;
            8)
                # Simular dependencia faltante
                if ! command -v comando_inexistente >/dev/null 2>&1; then
                    salir_con_error $EXIT_ERROR_DEPENDENCIA "comando_inexistente no encontrado"
                fi
                ;;
            *)
                salir_con_error $codigo
                ;;
        esac
    ) 2>/dev/null

    resultado=$?
    if [[ $resultado -eq $codigo ]]; then
        echo -e "${COLOR_VERDE}✓ Código $resultado${COLOR_RESET}"
    else
        echo -e "${COLOR_ROJO}✗ Código $resultado (esperado: $codigo)${COLOR_RESET}"
    fi
}

# Probar algunos escenarios
probar_escenario "Error de permisos" 2
probar_escenario "Error de red" 4
probar_escenario "Error de dependencia" 8

# Test 4: Verificar uso en el script principal
echo ""
echo "4. Verificando uso en script principal..."
echo ""

# Buscar usos de códigos de salida en el script
echo "  Buscando usos de EXIT_ERROR_*..."
grep -c "EXIT_ERROR_" ../src/gestor_procesos.sh | {
    read count
    echo "  Encontrados: $count usos de códigos de error"
}

# Verificar que no hay números mágicos
echo ""
echo "  Verificando ausencia de números mágicos..."
if grep -E "exit [0-9]+" ../src/gestor_procesos.sh | grep -v "EXIT_" | grep -v "#"; then
    echo -e "  ${COLOR_AMARILLO}⚠ Se encontraron números mágicos${COLOR_RESET}"
else
    echo -e "  ${COLOR_VERDE}✓ No se encontraron números mágicos${COLOR_RESET}"
fi

# Resumen final
echo ""
echo "========================================="
echo "  RESUMEN DE PRUEBAS"
echo "========================================="
echo ""

if [[ $errores -eq 0 ]]; then
    echo -e "${COLOR_VERDE}✓ Todas las pruebas pasaron exitosamente${COLOR_RESET}"
    echo ""
    echo "Los códigos de salida están:"
    echo "  • Correctamente definidos"
    echo "  • Con mensajes descriptivos"
    echo "  • Listos para usar en el script"
else
    echo -e "${COLOR_ROJO}✗ Se encontraron problemas en las pruebas${COLOR_RESET}"
fi

echo ""
echo "Documentación disponible en: docs/codigos-salida.md"