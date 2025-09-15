# Bitácora Sprint 1

## Día 1-2: Implementación Base

### Tareas Completadas - Melissa Iman Noriega

**Crear script base**

Se creó el archivo `src/gestor_procesos.sh` con la estructura inicial. El script incluye la configuración `set -euo pipefail` para manejo estricto de errores. Se definieron las variables globales necesarias como SCRIPT_DIR, PID_FILE y LOG_FILE. También se configuraron las variables de entorno PORT, MESSAGE y RELEASE con valores por defecto siguiendo los principios de 12-Factor App. Se establecieron 9 códigos de salida específicos para diferentes tipos de error.

Comando ejecutado para verificar la creación:
```bash
$ ls -la src/
-rwxr-xr-x  1 user  staff  2453  Sep 14 13:00 gestor_procesos.sh
```

**Implementar funciones básicas**

Se implementaron tres funciones fundamentales para la gestión de procesos. La función `iniciar_proceso()` verifica si existe un proceso activo mediante el archivo PID, crea el directorio de logs si no existe y simula el inicio de un proceso guardando el PID. La función `detener_proceso()` verifica la existencia del archivo PID, lo lee y elimina para simular la detención del proceso. La función `verificar_estado()` muestra si el proceso está activo o inactivo leyendo el archivo PID.

Pruebas realizadas:
```bash
$ ./src/gestor_procesos.sh estado
Estado: INACTIVO
Puerto configurado: 8080
Versión: v1.0.0

$ ./src/gestor_procesos.sh iniciar
[INFO] Iniciando proceso en puerto 8080...
[INFO] Proceso iniciado con PID 8909 en puerto 8080
[INFO] Logs en: /tmp/gestor-logs/gestor-web-20250914.log

$ ./src/gestor_procesos.sh detener
[INFO] Deteniendo proceso...
[INFO] Proceso con PID 8909 detenido
```

### Decisiones Técnicas

Se optó por usar archivos PID en `/tmp` para el control de procesos por ser una ubicación estándar temporal. Las funciones retornan códigos de salida específicos para facilitar el debugging. Se utilizó `readonly` para las variables globales garantizando inmutabilidad. El script está preparado para expansión en Sprint 2 donde se implementará el servicio web real.

### Commits Realizados

```bash
e1dceb7 Crear script base para gestión de procesos
79f1bc1 Implementar funciones básicas de gestión de procesos
```

### Tareas Completadas - Amir Canto

**Crear script base para monitoreo de redes**

Se creó el archivo `src/monitor_redes.sh` con la estructura inicial para el monitoreo de redes HTTP/DNS/TLS. El script incluye la configuración `set -euo pipefail` para manejo estricto de errores siguiendo las mismas convenciones que el gestor de procesos. Se definieron las variables globales necesarias como SCRIPT_DIR, LOG_DIR y RESULTS_FILE. Se configuraron las variables de entorno DNS_SERVER, TARGETS, CONFIG_URL y TIMEOUT con valores por defecto siguiendo los principios de 12-Factor App. Se establecieron los mismos 9 códigos de salida específicos para mantener consistencia.

Comando ejecutado para verificar la creación:
```bash
$ ls -la src/
-rwxr-xr-x  1 user  staff  4521  Sep 14 18:38 monitor_redes.sh
```

**Implementar verificación HTTP básica**

Se implementó la función `verificar_http()` que utiliza curl para realizar peticiones HTTP y verificar códigos de respuesta. La función captura el código de estado HTTP y el tiempo de respuesta, permitiendo verificar URLs específicas con códigos esperados personalizables. Se incluyó manejo de errores de conectividad y timeouts configurables. Se agregó función de logging estructurado con timestamps y niveles de información/error.

Pruebas realizadas:

![image-20250914194601121](/home/amirmiir/.config/Typora/typora-user-images/image-20250914194601121.png)

### Decisiones Técnicas

Se optó por usar curl con parámetros específicos `--max-time` y `--connect-timeout` para controlar timeouts. La función utiliza el formato de salida de curl `%{http_code}|%{time_total}` para capturar tanto el código de respuesta como el tiempo de ejecución en una sola llamada. Se implementó verificación de dependencias para curl, dig y openssl antes de ejecutar funciones. Los logs se almacenan en `/tmp/monitor-logs/` siguiendo la convención del gestor de procesos.

### Commits Realizados

```bash
38e894d Crear script base para monitoreo de redes
318c17f Agregar verificación HTTP con curl
```

