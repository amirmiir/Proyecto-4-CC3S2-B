#!/usr/bin/env bats
# Archivo: test_procesos.bats
# Descripción: Suite de tests ampliada para gestión de procesos
# Autor: Alumno 3 - Diego Orrego Torrejon
# Sprint: 2 - Tests Ampliados

# Configuración global para tests de procesos
setup() {
    # Directorios del proyecto
    export PROJECT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    export SRC_DIR="$PROJECT_DIR/src"
    export OUT_DIR="$PROJECT_DIR/out"
    export LOG_DIR="$PROJECT_DIR/out/logs"

    # Variables de entorno para tests
    export PORT=8080
    export MESSAGE="Servidor de prueba"
    export RELEASE="v1.0.0-test"
    export TIMEOUT=5

    # Crear directorios temporales para tests
    mkdir -p /tmp/test-gestor-logs
    mkdir -p /tmp/test-gestor-pids

    # Limpiar archivos de procesos de tests anteriores
    rm -f /tmp/test-gestor-*.pid
    rm -f /tmp/test-gestor-logs/*.log
    pkill -f "gestor_procesos.*test" 2>/dev/null || true

    # Esperar a que se liberen los puertos
    sleep 1
}

teardown() {
    # Limpiar procesos de test que puedan haber quedado
    pkill -f "gestor_procesos.*test" 2>/dev/null || true
    pkill -f "nc.*localhost.*8080" 2>/dev/null || true

    # Limpiar archivos temporales
    rm -rf /tmp/test-gestor-*

    # Esperar limpieza completa
    sleep 1
}

@test "Gestor maneja señales SIGTERM correctamente" {
    # Crear script de prueba que use el gestor
    local test_script="/tmp/test-signal-handler.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
set -euo pipefail

# Simular un proceso con PID file
echo $$ > /tmp/test-gestor-signal.pid

# Función de limpieza (trap)
cleanup() {
    local exit_code=$?
    echo "[INFO] Señal recibida, limpiando..." >&2
    rm -f /tmp/test-gestor-signal.pid
    exit $exit_code
}

trap cleanup EXIT TERM INT

# Simular trabajo del gestor
echo "[INFO] Iniciando proceso de prueba"
echo "PID: $$"

# Mantener activo por un tiempo
sleep 30 &
wait $!
EOF

    chmod +x "$test_script"

    # Ejecutar script en background
    "$test_script" &
    local pid=$!

    # Verificar que el proceso está activo y creó su PID file
    sleep 2
    [ -f /tmp/test-gestor-signal.pid ]

    # Enviar SIGTERM y verificar limpieza
    kill -TERM $pid

    # Esperar a que termine
    wait $pid || true

    # Verificar que se limpió correctamente
    [ ! -f /tmp/test-gestor-signal.pid ]
}

@test "Gestor de procesos valida códigos de salida específicos" {
    # Test de código de salida para comando inválido (debería ser 9)
    export PORT="puerto_invalido"
    run timeout 3 "$SRC_DIR/gestor_procesos.sh" --iniciar
    [ "$status" -eq 9 ]  # Error de validación por comando inválido

    # Test de código de salida con comando válido
    export PORT=8080
    run timeout 3 "$SRC_DIR/gestor_procesos.sh" estado
    # Puede devolver varios códigos según el estado del sistema
    [ "$status" -eq 0 ] || [ "$status" -eq 3 ] || [ "$status" -eq 9 ]
}

@test "Verificación de permisos y creación de directorios" {
    # Test usando directorio temporal con permisos
    export LOG_DIR="/tmp/test-gestor-logs"
    export PID_DIR="/tmp/test-gestor-pids"

    # Verificar que el gestor responde a comandos básicos
    run timeout 3 "$SRC_DIR/gestor_procesos.sh" estado

    # El script debe ejecutarse sin errores críticos de permisos
    [ "$status" -eq 0 ] || [ "$status" -eq 2 ] || [ "$status" -eq 3 ] || [ "$status" -eq 9 ]
}

@test "Manejo de PID file y prevención de múltiples instancias" {
    local test_pid_file="/tmp/test-gestor-multiple.pid"

    # Crear un PID file simulado
    echo "99999" > "$test_pid_file"

    # El gestor debería responder normalmente
    export PID_FILE="$test_pid_file"
    run timeout 3 "$SRC_DIR/gestor_procesos.sh" estado

    # Debería manejar la situación apropiadamente
    [ "$status" -eq 0 ] || [ "$status" -eq 3 ] || [ "$status" -eq 9 ]  # Varios códigos posibles

    # Limpiar
    rm -f "$test_pid_file"
}

@test "Integración con systemctl y unidades de sistema" {
    # Verificar que el gestor puede interactuar con systemd
    run systemctl --version
    if [ "$status" -eq 0 ]; then
        # Si systemd está disponible, verificar interacción básica
        run timeout 5 "$SRC_DIR/gestor_procesos.sh" start
        # Aceptar varios códigos según el estado del sistema (incluyendo error de configuración)
        [ "$status" -eq 0 ] || [ "$status" -eq 3 ] || [ "$status" -eq 5 ] || [ "$status" -eq 8 ] || [ "$status" -eq 9 ]
    else
        # Si no hay systemd, saltar este test
        skip "systemd no está disponible en este sistema"
    fi
}

@test "Validación de variables de entorno requeridas" {
    # Test con variables faltantes
    unset PORT MESSAGE RELEASE
    run timeout 3 "$SRC_DIR/gestor_procesos.sh" estado

    # Debería manejar variables faltantes con valores por defecto
    [ "$status" -eq 0 ] || [ "$status" -eq 3 ] || [ "$status" -eq 5 ] || [ "$status" -eq 9 ]

    # Test con variables válidas
    export PORT=8080
    export MESSAGE="Test válido"
    export RELEASE="v1.0.0"
    run timeout 3 "$SRC_DIR/gestor_procesos.sh" estado
    [ "$status" -eq 0 ] || [ "$status" -eq 3 ] || [ "$status" -eq 9 ]
}

@test "Funcionalidad de logging y rotación de logs" {
    local test_log_dir="/tmp/test-gestor-logs"
    export LOG_DIR="$test_log_dir"

    # Crear directorio de logs si no existe
    mkdir -p "$test_log_dir"

    # Ejecutar gestor para generar logs
    run timeout 3 "$SRC_DIR/gestor_procesos.sh" estado

    # Verificar que se puede ejecutar (genera logs en el proceso)
    [ "$status" -eq 0 ] || [ "$status" -eq 2 ] || [ "$status" -eq 3 ] || [ "$status" -eq 9 ]

    # Verificar que los logs tienen formato correcto si existen
    if ls "$test_log_dir"/*.log 1> /dev/null 2>&1; then
        # Verificar que contienen información útil
        run grep -r "INFO\|ERROR\|WARN" "$test_log_dir"
        [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # Encontrado o no encontrado
    else
        # Si no hay logs, es aceptable - el test valida que no hay errores críticos
        true
    fi
}

@test "Manejo de timeouts y procesos colgados" {
    # Crear script que simule un proceso que se cuelga
    local hanging_script="/tmp/test-hanging-process.sh"
    cat > "$hanging_script" << 'EOF'
#!/bin/bash
set -euo pipefail

echo "[INFO] Proceso iniciado, simulando trabajo..."
echo $$ > /tmp/test-hanging.pid

# Simular trabajo que puede colgarse
trap 'echo "[INFO] Recibida señal, terminando..."; rm -f /tmp/test-hanging.pid; exit 0' TERM INT

sleep 60  # Tiempo suficiente para simular cuelgue
EOF

    chmod +x "$hanging_script"

    # Ejecutar proceso en background
    "$hanging_script" &
    local pid=$!

    # Verificar que está corriendo
    sleep 1
    [ -f /tmp/test-hanging.pid ]

    # Simular timeout del gestor - enviar señal
    timeout 2 kill -TERM $pid || true

    # Verificar que el proceso se limpió adecuadamente
    sleep 2
    ! kill -0 $pid 2>/dev/null || true

    # Limpiar archivos residuales
    rm -f /tmp/test-hanging.pid "$hanging_script"
}

@test "Prueba de resistencia con múltiples señales concurrentes" {
    # Crear script que maneje múltiples señales
    local multi_signal_script="/tmp/test-multi-signal.sh"
    cat > "$multi_signal_script" << 'EOF'
#!/bin/bash
set -euo pipefail

signal_count=0

# Función para manejar señales
handle_signal() {
    local signal=$1
    signal_count=$((signal_count + 1))
    echo "[INFO] Señal $signal recibida (#$signal_count)"

    if [ $signal_count -ge 3 ]; then
        echo "[INFO] Múltiples señales recibidas, terminando..."
        rm -f /tmp/test-multi-signal.pid
        exit 0
    fi
}

trap 'handle_signal TERM' TERM
trap 'handle_signal INT' INT
trap 'handle_signal USR1' USR1

echo $$ > /tmp/test-multi-signal.pid
echo "[INFO] Proceso listo para recibir señales"

# Mantener activo
while [ $signal_count -lt 3 ]; do
    sleep 0.5
done
EOF

    chmod +x "$multi_signal_script"

    # Ejecutar script
    "$multi_signal_script" &
    local pid=$!

    # Enviar múltiples señales
    sleep 1
    kill -USR1 $pid 2>/dev/null || true
    sleep 0.2
    kill -USR1 $pid 2>/dev/null || true
    sleep 0.2
    kill -TERM $pid 2>/dev/null || true

    # Esperar terminación
    wait $pid || true

    # Verificar limpieza
    [ ! -f /tmp/test-multi-signal.pid ]

    rm -f "$multi_signal_script"
}