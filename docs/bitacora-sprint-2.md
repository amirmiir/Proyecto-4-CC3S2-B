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

Implementar análisis de logs con journalctl

**Decisión técnica**: Implementar función robusta de análisis de logs que funcione tanto con journalctl (systemd) como con logs tradicionales.

**Implementación**:
1. Nueva función `analizar_logs()` en `gestor_procesos.sh` que incluye:
   - Detección automática de journalctl
   - Análisis de logs del servicio systemd si está disponible
   - Fallback a logs tradicionales
   - Uso extensivo de awk para procesamiento

2. Análisis con journalctl (cuando disponible):
   - Conteo de mensajes por nivel (INFO, WARN, ERROR) usando awk
   - Mostrar últimos errores del servicio
   - Conteo de reinicios del día
   - Estado y tiempo de actividad del servicio

3. Análisis de logs tradicionales:
   - Tamaño y total de líneas del archivo
   - Versiones detectadas con awk
   - Puertos utilizados con awk
   - Últimas 10 entradas del log

4. Comando agregado al menú principal: `logs` o `analizar-logs`

**Evidencia**:
```bash
$ ./src/gestor_procesos.sh logs
[INFO] === Análisis de logs del sistema ===
[WARN] journalctl no disponible, analizando logs tradicionales

Archivo de log: /tmp/gestor-logs/gestor-web-20250919.log
Tamaño: 4.0K
Total de líneas: 55

Versiones detectadas:
  v1.0.0: 2 veces

Puertos utilizados:
  Puerto 8181: 1 veces
  Puerto 9090: 1 veces
```

**Uso de herramientas Unix**:
- `awk`: Procesamiento de logs, conteo de patrones, extracción de campos
- `grep`: Filtrado de mensajes por nivel
- `cut`: Extracción de campos específicos
- `tail`: Mostrar últimas líneas
- `sed`: Formateo de salida
- `wc`: Conteo de líneas
- `du`: Tamaño de archivos

Parsing avanzado con awk

**Decisión técnica**: Crear script especializado de análisis de métricas con uso intensivo de awk para procesamiento de logs.

**Implementación**:
1. Creación de `src/analizar_metricas.sh` con funciones especializadas:
   - `extraer_metricas_rendimiento()`: Distribución temporal y frecuencia
   - `analizar_errores_detallado()`: Clasificación de errores y códigos
   - `analizar_senales()`: Detección de señales y ciclos de vida
   - `analizar_puertos()`: Actividad de puertos y secuencias
   - `generar_resumen()`: Resumen ejecutivo con calificación de salud

2. Uso extensivo de awk para procesamiento:
   - Arrays asociativos para conteo de patrones
   - Cálculo de porcentajes y estadísticas
   - Extracción de campos con match() y substr()
   - Análisis multi-línea con BEGIN/END

3. Integración con gestor principal mediante comando `metricas`

**Evidencia**:
```bash
$ ./src/gestor_procesos.sh metricas
╔══════════════════════════════════════════╗
║   ANÁLISIS AVANZADO DE LOGS CON AWK     ║
╚══════════════════════════════════════════╝

Distribución temporal de eventos:
  Hora 13:00 - 14 eventos (100.0%)

Ciclos de vida del proceso:
  Inicios exitosos: 1
  Tasa de apagado limpio: 100.0%

Salud del sistema:
  Puntuación: 100/100 (EXCELENTE)
```

**Patrones de awk utilizados**:
- Procesamiento de campos con `$1, $2, $NF`
- Funciones match() y substr() para extracción
- Arrays asociativos para agregación
- Cálculos matemáticos y formateo con printf
- Análisis condicional con patrones regexp

### Implementar trap completo

**Decisión técnica**: Implementar manejo completo y robusto de señales con traps extendidos.

**Implementación**:
1. Nueva función `configurar_traps()` que configura todos los traps centralizadamente:
   - ERR: Manejo de errores con información de línea y comando
   - EXIT: Limpieza automática de recursos
   - INT, TERM, QUIT: Señales de terminación
   - HUP: Recarga de configuración
   - USR1, USR2: Señales de usuario personalizadas
   - TSTP, CONT: Pausa y reanudación de procesos
   - ALRM: Manejo de timeouts y alarmas
   - PIPE: Recuperación de pipes rotas

2. Variables de estado mejoradas:
   - `EN_APAGADO`: Previene manejo múltiple de señales de terminación
   - `TRAP_ACTIVO`: Evita recursión infinita en limpieza
   - `SIGNAL_RECIBIDA`: Tracking de señales recibidas

3. Función `limpiar_recursos()` mejorada:
   - Termina procesos hijos con `jobs -p`
   - Limpieza en dos fases (SIGTERM luego SIGKILL)
   - Eliminación de archivos temporales
   - Prevención de recursión con flag TRAP_ACTIVO

4. Nuevas señales manejadas:
   - SIGTSTP: Pausa proceso con kill -STOP
   - SIGCONT: Reanuda proceso con kill -CONT
   - SIGALRM: Verifica salud y reinicia si es necesario
   - SIGPIPE: Detecta y limpia procesos zombie

**Evidencia**:
```bash
$ ./src/gestor_procesos.sh iniciar
[INFO] Traps configurados para ERR, EXIT, INT, TERM, HUP, USR1, USR2, QUIT, TSTP, CONT, ALRM, PIPE
[INFO] Proceso iniciado con PID 2781 en puerto 8383
```

**Nota importante**: SIGKILL (9) no puede ser atrapado por diseño del sistema operativo

**Mejoras de robustez**:
- Prevención de condiciones de carrera
- Manejo de procesos zombie
- Limpieza garantizada con EXIT trap
- Información detallada en logs para debugging

### Códigos de salida específicos

**Decisión técnica**: Definir y documentar códigos de salida específicos para cada tipo de error.

**Implementación**:
1. Definición de 21 códigos de salida (0-20):
   - 0: EXIT_SUCCESS - Operación exitosa
   - 1-9: Errores básicos (general, permisos, proceso, red, configuración, etc.)
   - 10-20: Errores extendidos (archivo, memoria, disco, servicio, etc.)

2. Funciones helper implementadas:
   - `obtener_mensaje_error()`: Traduce código a mensaje descriptivo
   - `salir_con_error()`: Salida controlada con logging y limpieza

3. Documentación completa en `docs/codigos-salida.md`:
   - Tabla de todos los códigos
   - Ejemplos de uso
   - Mejores prácticas
   - Integración con systemd

4. Script de prueba `tests/test_codigos_salida.sh`:
   - Verifica definición de constantes
   - Prueba función de mensajes
   - Simula escenarios de error

**Evidencia**:
```bash
$ ./tests/test_codigos_salida.sh
✓ Todas las constantes están correctamente definidas
Código 4: Error de red - puerto o conexión
Código 8: Error de dependencia - herramienta faltante
```

**Mejores prácticas aplicadas**:
- Usar siempre constantes, nunca números mágicos
- Documentar cada código con su propósito
- Log antes de salir para facilitar debugging
- Propagar códigos en funciones
- Limpieza de recursos antes de salir

### Análisis TLS vs HTTP

**Decisión técnica**: Implementar análisis comparativo completo entre HTTP y HTTPS usando curl verbose.

**Implementación**:
1. Creación de `src/analizar_tls.sh` con funciones especializadas:
   - `analizar_http()`: Análisis detallado de protocolo HTTP
   - `analizar_tls()`: Análisis de HTTPS/TLS con certificados
   - `comparar_protocolos()`: Comparación lado a lado

2. Análisis HTTP incluye:
   - Headers de seguridad (HSTS, CSP, X-Frame-Options, etc.)
   - Análisis de cookies (Secure, HttpOnly, SameSite)
   - Métricas de rendimiento con curl
   - Códigos de respuesta y redirecciones

3. Análisis HTTPS/TLS incluye:
   - Versión de TLS y suite de cifrado
   - Información del certificado (emisor, validez, verificación)
   - Tiempo de handshake TLS
   - Protocolo ALPN y HTTP/2

4. Comparación con awk:
   - Cálculo de overhead TLS
   - Tabla comparativa de características
   - Recomendaciones de seguridad

5. Integración con `monitor_redes.sh`:
   - Nuevo comando `comparar` agregado
   - Análisis múltiple de dominios

**Evidencia**:
```bash
$ ./src/monitor_redes.sh comparar github.com
=== Análisis HTTP ===
Headers de seguridad:
  ✓ Strict-Transport-Security: max-age=31536000
  ✓ X-Frame-Options: deny
  ✓ Content-Security-Policy: [presente]

=== Análisis HTTPS/TLS ===
SSL connection using TLSv1.3
Suite de cifrado: AEAD-CHACHA20-POLY1305-SHA256
  ✓ Versión TLS moderna
Verificación SSL: EXITOSA

Overhead TLS: 0.060s
```

**Uso de curl verbose**:
- `curl -v` para análisis detallado
- `--write-out` para métricas personalizadas
- `--tlsv1.2` para forzar versión mínima
- Extracción de información con awk

### Verificación de sockets con ss

**Decisión técnica**: Implementar verificación completa de sockets y conexiones usando ss con fallback a netstat.

**Implementación**:
1. Creación de `src/verificar_sockets.sh` con análisis completo:
   - `analizar_puertos_tcp()`: Lista puertos escuchando con clasificación
   - `analizar_conexiones_activas()`: Estados y top IPs remotas
   - `verificar_puerto_especifico()`: Verifica puerto individual
   - `analizar_sockets_unix()`: Análisis de sockets locales
   - `analizar_rendimiento_red()`: Métricas de buffers y retransmisiones
   - `generar_resumen_sockets()`: Resumen ejecutivo

2. Compatibilidad multiplataforma:
   - Detección automática de ss disponibilidad
   - Fallback a netstat en sistemas sin ss (macOS)
   - Uso de lsof como alternativa para procesos

3. Análisis con awk implementado:
   - Clasificación de puertos por servicio
   - Conteo de conexiones por estado
   - Top 10 IPs con más conexiones
   - Cálculo de métricas de rendimiento
   - Detección de puertos peligrosos

4. Integración con gestor principal:
   - Comando `sockets` o `puertos` agregado
   - Verificación automática del puerto del gestor

**Evidencia**:
```bash
$ ./src/gestor_procesos.sh sockets puerto 8080
=== Verificación Puerto 8080 ===
  ✗ Puerto 8080 NO está escuchando
  ✓ Puerto 8080 está DISPONIBLE para usar

$ ./src/verificar_sockets.sh tcp
Puertos TCP escuchando:
  Puerto 22     - Estado: LISTEN    [SSH]
  Puerto 80     - Estado: LISTEN    [HTTP]
  Puerto 443    - Estado: LISTEN    [HTTPS]
```

**Características destacadas**:
- Clasificación automática de puertos conocidos
- Análisis de calidad con tasa de retransmisión
- Detección de puertos peligrosos (23, 135, 139, 445)
- Alertas de alto número de conexiones TIME_WAIT
- Recomendaciones de seguridad automáticas

### Procesamiento con Unix Toolkit

**Decisión técnica**: Integrar cut y tee para procesamiento avanzado de salidas y generación de reportes.

**Implementación**:
1. Creación de `src/procesador_toolkit.sh` con funciones especializadas:
   - `procesar_logs_sistema()`: Extrae campos de logs con cut
   - `procesar_salida_red()`: Procesa información de red
   - `procesar_info_procesos()`: Analiza procesos del sistema
   - `analisis_combinado()`: Pipeline complejo con múltiples herramientas
   - `generar_resumen()`: Crea reporte consolidado

2. Uso de cut para extracción de campos:
   - Timestamps de logs (campos 1-2)
   - Niveles de log con delimitadores
   - Primeros N caracteres de mensajes
   - Columnas específicas de salidas tabulares
   - IPs y puertos de conexiones de red

3. Uso de tee para procesamiento dual:
   - Mostrar en pantalla y guardar en archivo simultáneamente
   - Crear múltiples copias de datos procesados
   - Generar reportes persistentes
   - Mantener archivos temporales para análisis posterior

4. Pipelines complejos implementados:
   - `grep | cut | sort | uniq | tee` para análisis de patrones
   - `ps | sort | head | cut | tee` para top procesos
   - `df | cut | tee` para uso de disco
   - `netstat | grep | cut | tee` para conexiones activas

5. Integración con gestor principal:
   - Comando `toolkit` o `procesar` agregado
   - Procesamiento modular por categorías

**Evidencia**:
```bash
$ ./src/gestor_procesos.sh toolkit logs
Procesamiento de Logs con Unix Toolkit
Extrayendo timestamps (campo 1-2):
2025-09-19 13:45:14
2025-09-19 13:45:14

Niveles de log encontrados:
  4 ERROR
  33 INFO
  2 WARN

Puertos detectados: 1923, 2781, 8282, 8383
Reporte guardado en: /tmp/toolkit-logs/reporte-20250919.txt
```

**Características del procesamiento**:
- Extracción precisa de campos con cut
- Salida dual pantalla/archivo con tee
- Reportes estructurados y timestamped
- Análisis de múltiples fuentes de datos
- Compatibilidad con diferentes sistemas Unix

### Tests con netcat

**Decisión técnica**: Implementar suite completa de tests de red usando netcat (nc) para verificación de puertos y servicios.

**Implementación**:
1. Creación de `src/test_puertos_nc.sh` con funciones especializadas:
   - `escanear_puerto()`: Verifica puerto individual
   - `escanear_rango_puertos()`: Escaneo de rango con identificación de servicios
   - `test_conectividad_tcp()`: Test completo TCP con banner grabbing
   - `crear_servidor_prueba()`: Servidor HTTP simple con nc
   - `test_transferencia_archivos()`: Envío/recepción de archivos
   - `test_udp()`: Verificación de puertos UDP
   - `analizar_servicios_comunes()`: Análisis de servicios estándar

2. Características implementadas:
   - Detección automática de versión de nc (OpenBSD/GNU)
   - Identificación de servicios por puerto (SSH, HTTP, MySQL, etc.)
   - Banner grabbing para obtener versiones de servicios
   - Servidor de prueba HTTP con respuesta automática
   - Transferencia bidireccional de archivos
   - Tests UDP con verificación de envío

3. Integración con monitor_redes.sh:
   - Comando `netcat` o `nc` agregado
   - Análisis automático de servicios comunes
   - Verificación de puertos críticos

**Evidencia**:
```bash
$ ./src/monitor_redes.sh netcat servicios localhost
Análisis de Servicios Comunes:
  SSH (puerto 22): INACTIVO
  HTTP (puerto 80): ACTIVO
    Server: nginx/1.29.1
  HTTPS (puerto 443): ACTIVO
  MySQL (puerto 3306): INACTIVO
  HTTP-Alt (puerto 8080): ACTIVO

$ ./src/test_puertos_nc.sh rango localhost 8000 8100
Escaneando rango 8000-8100:
  Puerto 8080: ABIERTO
  Puerto 8081: ABIERTO
Resumen: 2 puertos abiertos, 99 cerrados
```

**Casos de uso de netcat**:
- Verificación rápida de disponibilidad de puertos
- Banner grabbing para identificación de servicios
- Creación de servidores de prueba temporales
- Transferencia de archivos sin SSH/FTP
- Debugging de protocolos de red
- Tests de conectividad UDP

