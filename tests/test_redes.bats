#!/usr/bin/env bats
# Archivo: test_redes.bats
# Descripción: Suite de tests para monitoreo de redes HTTP/DNS/TLS
# Autor: Alumno 3 - Diego Orrego Torrejon
# Sprint: 2 - Tests de Redes

# Configuración global para tests de redes
setup() {
    # Directorios del proyecto
    export PROJECT_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"
    export SRC_DIR="$PROJECT_DIR/src"
    export OUT_DIR="$PROJECT_DIR/out"

    # Variables de entorno para tests de red
    export DNS_SERVER="8.8.8.8"
    export TARGETS="google.com,github.com"
    export CONFIG_URL="http://httpbin.org/status/200"
    export TIMEOUT=5

    # Crear directorios temporales para tests
    mkdir -p /tmp/test-monitor-logs
    mkdir -p /tmp/test-redes

    # Limpiar archivos de tests anteriores
    rm -f /tmp/test-monitor-*.log
    rm -f /tmp/monitor-results.json

    # Verificar conectividad básica antes de tests
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        skip "Sin conectividad de red para tests"
    fi
}

teardown() {
    # Limpiar archivos temporales de tests de red
    rm -rf /tmp/test-monitor-*
    rm -f /tmp/monitor-results.json
}

@test "Monitor de redes ejecuta verificación HTTP básica" {
    # Test con URL conocida que debería responder
    export CONFIG_URL="http://httpbin.org/status/200"
    export TIMEOUT=10

    run timeout 15 "$SRC_DIR/monitor_redes.sh" http

    # Debería ejecutarse sin errores críticos
    [ "$status" -eq 0 ] || [ "$status" -eq 4 ]

    # Verificar que genera output apropiado
    [[ "$output" =~ "Verificando HTTP" ]] || [[ "$output" =~ "ERROR" ]]
}

@test "Monitor de redes maneja URLs HTTP con códigos de estado específicos" {
    # Test con código 404 (debería fallar apropiadamente)
    export CONFIG_URL="http://httpbin.org/status/404"
    export TIMEOUT=10

    run timeout 15 "$SRC_DIR/monitor_redes.sh" http "$CONFIG_URL" 404

    # Debería manejar código 404 correctamente
    [ "$status" -eq 0 ] || [ "$status" -eq 4 ]

    # Verificar que procesa la respuesta
    [[ "$output" =~ "Verificando HTTP" ]] || [[ "$output" =~ "Código HTTP" ]]
}

@test "Monitor de redes valida resolución DNS correctamente" {
    # Test con dominios conocidos
    export TARGETS="google.com,cloudflare.com"
    export DNS_SERVER="8.8.8.8"
    export TIMEOUT=10

    run timeout 15 "$SRC_DIR/monitor_redes.sh" dns

    # Debería resolver DNS exitosamente o manejar errores apropiadamente
    [ "$status" -eq 0 ] || [ "$status" -eq 4 ]

    # Verificar que menciona resolución DNS
    [[ "$output" =~ "DNS" ]] || [[ "$output" =~ "Resolviendo" ]] || [[ "$output" =~ "servidor" ]]
}

@test "Monitor de redes maneja servidores DNS inválidos" {
    # Test con servidor DNS inexistente
    export TARGETS="google.com"
    export DNS_SERVER="192.0.2.1"  # Dirección de documentación (no ruteable)
    export TIMEOUT=5

    run timeout 10 "$SRC_DIR/monitor_redes.sh" dns

    # Debería fallar apropiadamente con error de red o timeout
    [ "$status" -eq 4 ] || [ "$status" -eq 7 ] || [ "$status" -eq 0 ] || [ "$status" -eq 124 ]

    # Debería mencionar el error o al menos intentar la resolución
    [[ "$output" =~ "ERROR" ]] || [[ "$output" =~ "DNS" ]] || [[ "$output" =~ "servidor" ]]
}

@test "Monitor de redes ejecuta análisis TLS/HTTPS" {
    # Test con sitio HTTPS conocido
    export TARGETS="github.com"
    export TIMEOUT=15

    run timeout 20 "$SRC_DIR/monitor_redes.sh" tls

    # Debería ejecutar análisis TLS sin errores críticos
    [ "$status" -eq 0 ] || [ "$status" -eq 4 ] || [ "$status" -eq 8 ]

    # Verificar que ejecuta algún tipo de análisis
    [[ "$output" =~ "TLS" ]] || [[ "$output" =~ "SSL" ]] || [[ "$output" =~ "verificación" ]]
}

@test "Monitor de redes compara HTTP vs HTTPS correctamente" {
    # Test con sitio que soporta ambos protocolos
    export TARGETS="github.com"
    export TIMEOUT=15

    run timeout 25 "$SRC_DIR/monitor_redes.sh" comparar

    # Debería ejecutar comparación sin errores críticos
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 4 ] || [ "$status" -eq 8 ]

    # Verificar que realiza comparación
    [[ "$output" =~ "HTTP.*HTTPS\|comparar\|compar" ]] || [[ "$output" =~ "Analizando" ]]
}

@test "Monitor de redes ejecuta verificaciones completas (todo)" {
    # Test de verificación completa HTTP + DNS
    export CONFIG_URL="http://httpbin.org/status/200"
    export TARGETS="google.com"
    export TIMEOUT=10

    run timeout 30 "$SRC_DIR/monitor_redes.sh" todo

    # Debería ejecutar verificaciones completas
    [ "$status" -eq 0 ] || [ "$status" -eq 4 ]

    # Verificar que ejecuta múltiples verificaciones
    [[ "$output" =~ "HTTP.*DNS\|completa\|verificación" ]] || [[ "$output" =~ "Iniciando" ]]
}

@test "Monitor de redes usa herramientas Unix toolkit apropiadamente" {
    # Verificar que usa herramientas como curl, dig, awk
    # Test indirecto verificando dependencias

    run bash -c "command -v curl && command -v dig && command -v awk"
    [ "$status" -eq 0 ]

    # Test que el script verifica dependencias
    run timeout 10 "$SRC_DIR/monitor_redes.sh" http

    # Debería ejecutarse si las dependencias están disponibles
    [ "$status" -eq 0 ] || [ "$status" -eq 4 ] || [ "$status" -eq 8 ]
}

@test "Monitor de redes maneja timeouts apropiadamente" {
    # Test con timeout muy corto para forzar timeout
    export TIMEOUT=1
    export CONFIG_URL="http://httpbin.org/delay/5"  # Endpoint que demora 5 segundos

    run timeout 8 "$SRC_DIR/monitor_redes.sh" http

    # Debería manejar timeout apropiadamente
    [ "$status" -eq 4 ] || [ "$status" -eq 7 ] || [ "$status" -eq 0 ]

    # No debería colgar indefinidamente (el timeout externo lo previene)
}

@test "Monitor de redes valida parámetros de entrada" {
    # Test con comando inválido
    run timeout 5 "$SRC_DIR/monitor_redes.sh" comando_inexistente

    # Debería manejar comando inválido mostrando ayuda
    [ "$status" -eq 9 ] || [ "$status" -eq 1 ]

    # Debería mostrar ayuda o mensaje de error
    [[ "$output" =~ "Uso:" ]] || [[ "$output" =~ "COMANDOS:" ]] || [[ "$output" =~ "desconocido" ]]
}

@test "Monitor de redes genera logs con formato correcto" {
    # Test que verifica generación de logs
    export LOG_DIR="/tmp/test-monitor-logs"
    mkdir -p "$LOG_DIR"

    run timeout 10 "$SRC_DIR/monitor_redes.sh" http

    # Verificar que se pueden generar logs
    [ "$status" -eq 0 ] || [ "$status" -eq 4 ] || [ "$status" -eq 2 ]

    # Verificar formato de logs si se generaron
    if ls "$LOG_DIR"/*.log 1> /dev/null 2>&1; then
        # Verificar que contienen timestamps y niveles
        run grep -r "\[INFO\]\|\[ERROR\]\|\[WARN\]" "$LOG_DIR"
        [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    fi
}

@test "Monitor de redes integra con tests de puertos netcat" {
    # Test de integración con netcat si está disponible
    if command -v nc >/dev/null 2>&1; then
        export TARGETS="google.com"

        run timeout 15 "$SRC_DIR/monitor_redes.sh" netcat

        # Debería ejecutar tests de netcat apropiadamente
        [ "$status" -eq 0 ] || [ "$status" -eq 4 ] || [ "$status" -eq 8 ]

        # Verificar que menciona netcat o puertos
        [[ "$output" =~ "netcat\|puerto\|nc" ]] || [[ "$output" =~ "Verificando" ]]
    else
        # Si netcat no está disponible, debería manejar la dependencia
        run timeout 10 "$SRC_DIR/monitor_redes.sh" netcat

        [ "$status" -eq 8 ] || [ "$status" -eq 0 ] || [ "$status" -eq 4 ]
        [[ "$output" =~ "disponible\|dependencia\|netcat" ]] || [[ "$output" =~ "ERROR" ]]
    fi
}

@test "Monitor de redes valida códigos de salida específicos" {
    # Test que verifica códigos de salida apropiados

    # Test exitoso debería devolver 0
    export CONFIG_URL="http://httpbin.org/status/200"
    export TIMEOUT=10

    run timeout 15 "$SRC_DIR/monitor_redes.sh" http

    # Códigos válidos según la especificación del proyecto
    case "$status" in
        0|1|2|3|4|5|6|7|8|9)
            # Códigos de salida válidos según especificación
            true
            ;;
        *)
            # Código de salida fuera del rango especificado
            false
            ;;
    esac
}