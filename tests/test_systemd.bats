#!/usr/bin/env bats
# Test suite para validación de configuración systemd

# Función de setup
setup() {
    # Directorio del proyecto
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_DIRNAME")" && pwd)"
    SYSTEMD_DIR="$PROJECT_ROOT/systemd"
    SERVICE_FILE="$SYSTEMD_DIR/gestor-web.service"
    CONFIG_FILE="$SYSTEMD_DIR/gestor.conf.example"
}

# Test: Archivo de servicio existe
@test "Archivo gestor-web.service existe" {
    [ -f "$SERVICE_FILE" ]
}

# Test: Archivo de configuración existe
@test "Archivo gestor.conf.example existe" {
    [ -f "$CONFIG_FILE" ]
}

# Test: Script de gestión existe y es ejecutable
@test "Script gestionar-servicio.sh es ejecutable" {
    [ -x "$SYSTEMD_DIR/gestionar-servicio.sh" ]
}

# Test: Validar sintaxis del archivo de servicio
@test "Sintaxis del archivo de servicio es válida" {
    # Verificar secciones principales
    grep -q "^\[Unit\]" "$SERVICE_FILE"
    grep -q "^\[Service\]" "$SERVICE_FILE"
    grep -q "^\[Install\]" "$SERVICE_FILE"
}

# Test: Configuración de Unit correcta
@test "Sección Unit tiene configuración requerida" {
    grep -q "^Description=" "$SERVICE_FILE"
    grep -q "^After=network.target" "$SERVICE_FILE"
}

# Test: Configuración de Service correcta
@test "Sección Service tiene configuración requerida" {
    grep -q "^Type=" "$SERVICE_FILE"
    grep -q "^ExecStart=" "$SERVICE_FILE"
    grep -q "^ExecStop=" "$SERVICE_FILE"
    grep -q "^PIDFile=" "$SERVICE_FILE"
}

# Test: Configuración de seguridad presente
@test "Configuración de seguridad implementada" {
    grep -q "^User=nobody" "$SERVICE_FILE"
    grep -q "^Group=nogroup" "$SERVICE_FILE"
    grep -q "^NoNewPrivileges=true" "$SERVICE_FILE"
    grep -q "^PrivateTmp=true" "$SERVICE_FILE"
    grep -q "^ProtectSystem=" "$SERVICE_FILE"
    grep -q "^ProtectHome=" "$SERVICE_FILE"
}

# Test: Límites de recursos configurados
@test "Límites de recursos configurados" {
    grep -q "^CPUQuota=" "$SERVICE_FILE"
    grep -q "^MemoryLimit=" "$SERVICE_FILE"
    grep -q "^LimitNOFILE=" "$SERVICE_FILE"
}

# Test: Manejo de reinicio configurado
@test "Política de reinicio configurada" {
    grep -q "^Restart=on-failure" "$SERVICE_FILE"
    grep -q "^RestartSec=" "$SERVICE_FILE"
}

# Test: Variables de entorno definidas
@test "Variables de entorno definidas en servicio" {
    grep -q "^Environment=\"PORT=" "$SERVICE_FILE"
    grep -q "^Environment=\"MESSAGE=" "$SERVICE_FILE"
    grep -q "^Environment=\"RELEASE=" "$SERVICE_FILE"
}

# Test: EnvironmentFile configurado
@test "EnvironmentFile configurado para archivo externo" {
    grep -q "^EnvironmentFile=-/etc/gestor-web/gestor.conf" "$SERVICE_FILE"
}

# Test: Configuración de logging
@test "Logging con journald configurado" {
    grep -q "^StandardOutput=journal" "$SERVICE_FILE"
    grep -q "^StandardError=journal" "$SERVICE_FILE"
    grep -q "^SyslogIdentifier=" "$SERVICE_FILE"
}

# Test: Señales configuradas correctamente
@test "Señales de parada configuradas" {
    grep -q "^KillSignal=SIGTERM" "$SERVICE_FILE"
    grep -q "^TimeoutStopSec=" "$SERVICE_FILE"
}

# Test: ExecReload para SIGHUP
@test "ExecReload configurado para recarga" {
    grep -q "^ExecReload=/bin/kill -HUP" "$SERVICE_FILE"
}

# Test: Target de instalación correcto
@test "WantedBy configurado correctamente" {
    grep -q "^WantedBy=multi-user.target" "$SERVICE_FILE"
}

# Test: Alias del servicio definido
@test "Alias del servicio definido" {
    grep -q "^Alias=gestor-procesos.service" "$SERVICE_FILE"
}

# Test: Archivo de configuración tiene todas las variables
@test "Archivo de configuración contiene todas las variables" {
    grep -q "^PORT=" "$CONFIG_FILE"
    grep -q "^MESSAGE=" "$CONFIG_FILE"
    grep -q "^RELEASE=" "$CONFIG_FILE"
    grep -q "^DNS_SERVER=" "$CONFIG_FILE"
    grep -q "^TARGETS=" "$CONFIG_FILE"
    grep -q "^CONFIG_URL=" "$CONFIG_FILE"
    grep -q "^TIMEOUT=" "$CONFIG_FILE"
}

# Test: README de systemd existe
@test "README de systemd existe con documentación" {
    [ -f "$SYSTEMD_DIR/README.md" ]
    grep -q "Instalación del Servicio" "$SYSTEMD_DIR/README.md"
    grep -q "journalctl" "$SYSTEMD_DIR/README.md"
}

# Test: Rutas en el servicio son absolutas
@test "Rutas en el servicio son absolutas" {
    grep "^ExecStart=" "$SERVICE_FILE" | grep -q "^ExecStart=/opt/"
    grep "^ExecStop=" "$SERVICE_FILE" | grep -q "^ExecStop=/opt/"
}

# Test: WorkingDirectory configurado
@test "WorkingDirectory está configurado" {
    grep -q "^WorkingDirectory=/opt/gestor-web" "$SERVICE_FILE"
}

# Test: ReadWritePaths para logs
@test "ReadWritePaths incluye directorios necesarios" {
    grep -q "^ReadWritePaths=.*\/var\/log\/gestor-web" "$SERVICE_FILE"
}

# Test: Script de gestión tiene función de instalación
@test "Script de gestión tiene función instalar" {
    grep -q "instalar_servicio()" "$SYSTEMD_DIR/gestionar-servicio.sh"
}

# Test: Script de gestión tiene función de estado
@test "Script de gestión tiene función estado" {
    grep -q "mostrar_estado()" "$SYSTEMD_DIR/gestionar-servicio.sh"
}

# Test: Script de gestión tiene análisis de logs
@test "Script de gestión puede analizar logs" {
    grep -q "analizar_logs()" "$SYSTEMD_DIR/gestionar-servicio.sh"
    grep -q "journalctl" "$SYSTEMD_DIR/gestionar-servicio.sh"
}