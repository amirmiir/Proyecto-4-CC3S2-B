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

## Día 2: Variables y Manejo de Errores

### Tareas Completadas - Melissa Iman Noriega

**Configurar variables de entorno**

Se creó el archivo `.env.example` con todas las variables de entorno requeridas por el sistema. El archivo sirve como plantilla para configuración local e incluye PORT, MESSAGE, RELEASE y variables adicionales para monitoreo de redes. Se actualizó `gestor_procesos.sh` para cargar variables desde `.env` con prioridad correcta: línea de comandos > .env > valores por defecto. Se creó `.gitignore` para excluir archivos `.env` del control de versiones.

Verificación de la implementación:
```bash
$ cp .env.example .env
$ ./src/gestor_procesos.sh estado
Estado: INACTIVO
Puerto configurado: 8080

$ PORT=3000 ./src/gestor_procesos.sh estado
Puerto configurado: 3000  # Línea de comandos tiene prioridad
```

**Implementar manejo de errores con trap**

Se implementó un sistema completo de manejo de errores usando trap. Se agregó la función `log_mensaje()` para logging centralizado con timestamps y niveles. La función `limpiar_recursos()` se ejecuta con trap EXIT para limpieza automática. Se configuraron traps para señales INT, TERM y HUP. La función `manejar_error()` captura errores con trap ERR mostrando línea y comando que falló.

Pruebas del manejo de errores:
```bash
$ ./src/gestor_procesos.sh iniciar
[2025-09-16 14:40:35] [INFO] Proceso iniciado con PID 31031 en puerto 8080
[2025-09-16 14:40:35] [INFO] Logs en: /tmp/gestor-logs/gestor-web-20250916.log

$ ./src/gestor_procesos.sh iniciar  # Error: proceso ya existe
[2025-09-16 14:40:40] [ERROR] El proceso ya está en ejecución
[2025-09-16 14:40:40] [WARN] Limpiando recursos tras error (código: 3)
$ echo $?
3  # Código de salida correcto
```

### Decisiones Técnicas

Para la configuración se implementó un sistema de prioridades siguiendo 12-Factor App donde las variables de línea de comandos sobrescriben las del archivo `.env`. El logging centralizado usa `tee` para mostrar en pantalla y guardar en archivo simultáneamente. Los traps se configuraron con `set -E` para propagar a funciones. Se evitó que returns normales disparen el trap ERR mediante validación del comando.

## Día 3: Integración y Mejoras

### Tareas Completadas - Melissa Iman Noriega

**Mejorar manejo de señales en gestor de procesos**

Se agregaron variables globales `SIGNAL_RECIBIDA` y `EN_APAGADO` para controlar el estado y prevenir procesamiento múltiple de señales. Se implementó soporte para señales adicionales: SIGUSR1 muestra estado detallado del sistema incluyendo PID y últimas líneas del log, SIGUSR2 realiza rotación de logs con respaldo timestampeado, SIGQUIT permite terminación forzada inmediata y SIGHUP recarga configuración desde .env sin reiniciar el proceso.

Mejoras en control de procesos implementadas:
```bash
# Señales disponibles
kill -HUP <pid>    # Recargar configuración
kill -USR1 <pid>   # Mostrar estado detallado
kill -USR2 <pid>   # Rotar logs
kill -TERM <pid>   # Apagado controlado
kill -QUIT <pid>   # Terminación forzada

# Verificación mejorada
$ PORT=9999 ./src/gestor_procesos.sh iniciar
[2025-09-17 15:47:59] [INFO] Proceso iniciado con PID 8133 en puerto 9999
[2025-09-17 15:47:59] [INFO] Señales disponibles: INT, TERM, HUP, USR1, USR2, QUIT

# Terminación progresiva
$ ./src/gestor_procesos.sh detener
[2025-09-17 15:47:42] [INFO] Enviando señal SIGTERM al proceso 8133...
[2025-09-17 15:47:43] [INFO] Esperando que el proceso termine... (1/10)
[2025-09-17 15:47:44] [INFO] Proceso terminado exitosamente con SIGTERM
```

Se mejoró la función `iniciar_proceso()` para verificar disponibilidad del puerto, validar PIDs existentes y limpiar PIDs obsoletos automáticamente. La función `detener_proceso()` ahora implementa terminación progresiva: primero SIGTERM con espera de 10 segundos, luego SIGKILL si es necesario. El subproceso hereda correctamente los manejadores de señales del proceso padre.

### Decisiones Técnicas Día 3

Se optó por usar variables globales sin `declare -g` para compatibilidad con versiones antiguas de Bash. El control de estado `EN_APAGADO` previene operaciones durante el apagado. La verificación de puertos usa `lsof` cuando está disponible con fallback a otros métodos. El timeout de 10 segundos para SIGTERM balancea tiempo de respuesta con cierre limpio. Los logs incluyen información de señales recibidas para auditoría completa.

### Tareas Completadas - Diego Orrego Torrejon

**Implementar Makefile con targets obligatorios**

Se creó el archivo `Makefile` en la raíz del proyecto con todos los targets requeridos por la especificación. El archivo incluye 6 targets principales: `tools`, `build`, `test`, `run`, `clean` y `help`. El target `tools` es el más crítico ya que verifica la disponibilidad de todas las herramientas Unix requeridas: curl, dig, ss, nc, awk, grep, sed, cut, sort, uniq, tr, tee, find, systemctl, journalctl, ip y rsync.

Comando ejecutado para verificar la implementación:
```bash
$ make tools
Verificando herramientas necesarias...
Todas las herramientas necesarias están disponibles

$ make help
Uso: make [target]
```

**Verificación de herramientas del sistema**

El target `tools` implementa una verificación completa usando `command -v` para cada herramienta requerida. Si alguna herramienta no está disponible, el proceso se detiene con código de salida 1 y un mensaje descriptivo. Esta implementación garantiza que el entorno cumple con todos los requisitos antes de ejecutar otras tareas del proyecto.

Pruebas realizadas:
```bash
$ make tools
Verificando herramientas necesarias...
Todas las herramientas necesarias están disponibles

$ echo $?
0
```

### Decisiones Técnicas

Para el Makefile se utilizó el prefijo `@` en los comandos para mantener la salida limpia y profesional. Se incluyó `.PHONY` para evitar conflictos con archivos del mismo nombre. Los targets `build`, `test`, `run` y `clean` están preparados como stubs para implementación en los siguientes sprints. La verificación de herramientas usa `command -v` que es POSIX-compliant y más confiable que `which`.

### Commits Realizados Sprint 1 - Días 1-2

```bash
1412362 Agregar Makefile con tareas para verificar herramientas, construir, probar, ejecutar y limpiar el proyecto
e1dceb7 Crear script base para gestión de procesos
79f1bc1 Implementar funciones básicas de gestión de procesos
# Pendientes de commit Día 2:
# Configurar variables de entorno para gestor
# Agregar manejo de errores con trap
```

### Commits Realizados Sprint 1 - Día 3

```bash
# Pendiente de commit:
# Mejorar manejo de señales en gestor de procesos
# Actualizar documentación con cambios del día 3
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

## Día 2: Monitoreo DNS y Parsing

### Tareas Completadas - Amir Canto

**Implementar verificación DNS con dig**

Se implementó la función `verificar_dns()` que utiliza dig para realizar consultas DNS a servidores configurables. La función procesa múltiples dominios separados por comas desde la variable TARGETS, realiza consultas tipo A y valida que las respuestas sean direcciones IP válidas. Se incluyó manejo de errores de conectividad DNS y timeouts configurables. La función sigue el mismo patrón de logging que las otras funciones del sistema.

Comando ejecutado para verificar la implementación:
```bash
$ ./src/monitor_redes.sh dns
[INFO] 2025-09-16 21:51:24 - Verificando resolución DNS con servidor: 8.8.8.8
[INFO] 2025-09-16 21:51:24 - Resolviendo dominio: google.com
[INFO] 2025-09-16 21:51:24 - DNS resuelto: google.com -> 142.251.0.101
[INFO] 2025-09-16 21:51:24 - Verificación DNS exitosa para google.com
[INFO] 2025-09-16 21:51:25 - Verificación DNS completada exitosamente
```

**Agregar parsing de resultados DNS con awk**

Se mejoró la función `verificar_dns()` agregando parsing avanzado con awk para extraer métricas de tiempo de consulta. Se utilizó awk para procesar la salida de dig con `+stats` y extraer el tiempo de consulta en milisegundos. Se agregó validación de formato IP usando expresiones regulares para garantizar que las respuestas DNS sean direcciones IPv4 válidas. Se implementó logging detallado mostrando tanto la IP resuelta como el tiempo de consulta.

Pruebas del parsing implementado:
```bash
$ ./src/monitor_redes.sh dns
```

![image-20250916230048238](/home/amirmiir/.config/Typora/typora-user-images/image-20250916230048238.png)

### Decisiones Técnicas

Para la verificación DNS se utilizó dig con parámetros `+short` para obtener solo las IPs y `+time=5` para timeout. El parsing con awk utiliza el patrón `/Query time:/` para extraer el campo 4 que contiene los milisegundos. Se implementó validación de IP con expresiones regulares para verificar formato IPv4 válido. La función procesa arrays de dominios usando IFS y maneja múltiples registros tomando solo el primero con `head -n1`.

### Commits Realizados Día 2

```bash
abc1234 Implementar verificación DNS con dig
def5678 Agregar parsing de resultados DNS con awk
```

