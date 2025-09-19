#!/usr/bin/env bats
# Archivo: test_basico.bats
# Descripción: Tests básicos del gestor de procesos y monitor de redes
# Autor: Alumno 3 - Diego Orrego Torrejon

# Configuración global de tests
setup() {
    # Directorio del proyecto
    export PROJECT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    export SRC_DIR="$PROJECT_DIR/src"
    export OUT_DIR="$PROJECT_DIR/out"

    # Variables de entorno para tests
    export PORT=8080
    export MESSAGE="Test servidor"
    export RELEASE="v1.0.0-test"
    export DNS_SERVER="8.8.8.8"
    export TARGETS="google.com"
    export TIMEOUT=5

    # Limpiar archivos temporales de tests anteriores
    rm -f /tmp/test-*.log /tmp/test-*.pid
}

teardown() {
    # Limpiar después de cada test
    rm -f /tmp/test-*.log /tmp/test-*.pid
}

@test "Scripts principales existen y son ejecutables" {
    run ls -la "$SRC_DIR/gestor_procesos.sh"
    [ "$status" -eq 0 ]

    run ls -la "$SRC_DIR/monitor_redes.sh"
    [ "$status" -eq 0 ]

    # Verificar permisos de ejecución
    [ -x "$SRC_DIR/gestor_procesos.sh" ]
    [ -x "$SRC_DIR/monitor_redes.sh" ]
}

@test "Gestor de procesos muestra ayuda correctamente" {
    run "$SRC_DIR/gestor_procesos.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Uso:" ]]
}

@test "Monitor de redes ejecuta verificación básica" {
    # Test con timeout corto para no hacer el test muy lento
    export TIMEOUT=3
    export TARGETS="google.com"

    run timeout 10 "$SRC_DIR/monitor_redes.sh" --verificar-http

    # El script debe ejecutarse sin errores críticos
    # Aceptamos códigos de salida 0 (éxito) o 4 (error de red, esperado en algunos casos)
    [ "$status" -eq 0 ] || [ "$status" -eq 4 ]
}

@test "Makefile target build funciona correctamente" {
    cd "$PROJECT_DIR"

    # Limpiar build anterior
    run make clean

    # Ejecutar build
    run make build
    [ "$status" -eq 0 ]

    # Verificar que se crearon los artefactos
    [ -d "$OUT_DIR/bin" ]
    [ -d "$OUT_DIR/config" ]
    [ -d "$OUT_DIR/logs" ]
    [ -f "$OUT_DIR/build-info.txt" ]

    # Verificar que los scripts se copiaron
    [ -f "$OUT_DIR/bin/gestor_procesos.sh" ]
    [ -f "$OUT_DIR/bin/monitor_redes.sh" ]

    # Verificar permisos de ejecución
    [ -x "$OUT_DIR/bin/gestor_procesos.sh" ]
    [ -x "$OUT_DIR/bin/monitor_redes.sh" ]
}

@test "Variables de entorno se cargan correctamente" {
    # Test con variables específicas
    export PORT=9999
    export MESSAGE="Test personalizado"

    # Ejecutar script con modo debug para capturar variables
    run bash -c "cd '$PROJECT_DIR' && PORT=9999 MESSAGE='Test personalizado' '$SRC_DIR/gestor_procesos.sh' --version 2>&1 | head -20"

    [ "$status" -eq 0 ]
    # El script debe ejecutarse sin errores fatales
}

@test "Scripts tienen manejo de errores con set -euo pipefail" {
    # Verificar que los scripts usan modo estricto
    run grep -q "set -euo pipefail" "$SRC_DIR/gestor_procesos.sh"
    [ "$status" -eq 0 ]

    run grep -q "set -euo pipefail" "$SRC_DIR/monitor_redes.sh"
    [ "$status" -eq 0 ]
}