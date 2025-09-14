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

