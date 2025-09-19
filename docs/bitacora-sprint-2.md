# Bitácora Sprint 2 - Desarrollo con systemd y monitoreo

Crear unidad systemd para gestor de procesos

**Decisión técnica**: Implementar archivo de servicio systemd completo con configuración de seguridad y límites de recursos.

**Implementación**:
1. Creación de `systemd/gestor-web.service` con:
   - Tipo forking para compatibilidad con script existente
   - Usuario no privilegiado (nobody:nogroup)
   - Restricciones de seguridad (PrivateTmp, ProtectSystem, NoNewPrivileges)
   - Límites de recursos (CPU 50%, Memory 256MB)
   - Reinicio automático en fallos

2. Archivo de configuración `systemd/gestor.conf.example` con variables de entorno

3. Script auxiliar `systemd/gestionar-servicio.sh` con funciones:
   - instalar_servicio(): Instalación completa del servicio
   - desinstalar_servicio(): Limpieza del sistema
   - mostrar_estado(): Estado detallado con métricas
   - analizar_logs(): Análisis de logs con journald
   - recargar_config(): Recarga con SIGHUP

4. Documentación completa en `systemd/README.md`

**Evidencia**:
```bash
$ ls -la systemd/
-rwxr-xr-x  gestionar-servicio.sh
-rw-r--r--  gestor-web.service
-rw-r--r--  gestor.conf.example
-rw-r--r--  README.md
```

Implementar control via systemctl

**Decisión técnica**: Agregar soporte completo de systemctl al script principal manteniendo compatibilidad con comandos tradicionales.

**Implementación**:
1. Nueva función `controlar_servicio_systemd()` en `gestor_procesos.sh` que soporta:
   - start: Inicia servicio via systemctl
   - stop: Detiene servicio via systemctl
   - restart: Reinicia servicio
   - reload: Recarga configuración
   - status: Estado detallado con journald
   - enable: Habilita inicio automático
   - disable: Deshabilita inicio automático

2. Verificaciones implementadas:
   - Disponibilidad de systemctl
   - Instalación del servicio
   - Fallback a comandos tradicionales

3. Actualización del menú de ayuda con todos los comandos

**Evidencia**:
```bash
$ ./src/gestor_procesos.sh
Uso: gestor_procesos.sh {iniciar|detener|estado|start|stop|restart|reload|systemctl}

Comandos básicos (sin systemd):
  iniciar  - Inicia el proceso gestor
  detener  - Detiene el proceso gestor
  estado   - Muestra el estado actual

Comandos systemd:
  start    - Inicia servicio via systemctl
  stop     - Detiene servicio via systemctl
  restart  - Reinicia servicio via systemctl
  reload   - Recarga configuración via systemctl
```

**Pruebas realizadas**:
```bash
# Comandos tradicionales funcionando
$ PORT=8181 ./src/gestor_procesos.sh iniciar
[INFO] Proceso iniciado con PID 3810 en puerto 8181

$ ./src/gestor_procesos.sh estado
Estado: ACTIVO
PID: 3810

$ ./src/gestor_procesos.sh detener
[INFO] Proceso terminado exitosamente con SIGTERM

# Detección de systemctl en macOS
$ ./src/gestor_procesos.sh start
[ERROR] systemctl no está disponible en este sistema
```

### Decisiones de diseño

1. **Compatibilidad dual**: El script mantiene comandos tradicionales (`iniciar`, `detener`, `estado`) y agrega comandos systemd (`start`, `stop`, `restart`, `reload`)

2. **Detección automática**: El script detecta si systemctl está disponible y si el servicio está instalado

3. **Manejo de errores robusto**: Códigos de salida específicos para cada tipo de error (DEPENDENCIA, CONFIGURACION)

4. **Seguridad en systemd**: Usuario no privilegiado, directorios temporales aislados, límites de recursos

