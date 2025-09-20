# Documentación de Códigos de Salida

## Tabla de Códigos de Salida del Sistema

| Código | Constante | Descripción | Uso |
|--------|-----------|-------------|-----|
| 0 | EXIT_SUCCESS | Operación exitosa | Cuando todo funciona correctamente |
| 1 | EXIT_ERROR_GENERAL | Error general no especificado | Errores que no encajan en otras categorías |
| 2 | EXIT_ERROR_PERMISOS | Error de permisos | No se puede acceder/crear archivos o directorios |
| 3 | EXIT_ERROR_PROCESO | Error de proceso | Fallo al iniciar/detener procesos |
| 4 | EXIT_ERROR_RED | Error de red | Puerto en uso, conexión fallida |
| 5 | EXIT_ERROR_CONFIGURACION | Error de configuración | Archivo .env faltante o inválido |
| 6 | EXIT_ERROR_SIGNAL | Error de señal | Terminación por señal inesperada |
| 7 | EXIT_ERROR_TIMEOUT | Error de timeout | Operación excedió tiempo límite |
| 8 | EXIT_ERROR_DEPENDENCIA | Error de dependencia | Herramienta requerida no disponible |
| 9 | EXIT_ERROR_VALIDACION | Error de validación | Argumentos inválidos o faltantes |

## Códigos Extendidos (10-20)

| Código | Constante | Descripción | Uso |
|--------|-----------|-------------|-----|
| 10 | EXIT_ERROR_ARCHIVO | Error de archivo | Archivo no encontrado o corrupto |
| 11 | EXIT_ERROR_MEMORIA | Error de memoria | Sin memoria disponible |
| 12 | EXIT_ERROR_DISCO | Error de disco | Sin espacio en disco |
| 13 | EXIT_ERROR_SERVICIO | Error de servicio | Servicio systemd no disponible |
| 14 | EXIT_ERROR_AUTENTICACION | Error de autenticación | Credenciales inválidas |
| 15 | EXIT_ERROR_PROTOCOLO | Error de protocolo | Protocolo no soportado |
| 16 | EXIT_ERROR_VERSION | Error de versión | Versión incompatible |
| 17 | EXIT_ERROR_ESTADO | Error de estado | Estado inconsistente |
| 18 | EXIT_ERROR_RECURSO | Error de recurso | Recurso no disponible |
| 19 | EXIT_ERROR_LIMITE | Error de límite | Límite excedido |
| 20 | EXIT_ERROR_USUARIO | Error de usuario | Acción cancelada por usuario |

## Códigos de Señales Unix (128+n)

| Código | Señal | Descripción |
|--------|-------|-------------|
| 130 | SIGINT (2) | Interrupción (Ctrl+C) |
| 143 | SIGTERM (15) | Terminación solicitada |
| 137 | SIGKILL (9) | Terminación forzada |
| 129 | SIGHUP (1) | Desconexión de terminal |
| 131 | SIGQUIT (3) | Salida (Ctrl+\) |
| 141 | SIGPIPE (13) | Pipe rota |
| 142 | SIGALRM (14) | Temporizador expirado |

## Uso en el Script

### Ejemplo de implementación en bash:

```bash
#!/bin/bash
# Definición de códigos de salida
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR_GENERAL=1
readonly EXIT_ERROR_PERMISOS=2
readonly EXIT_ERROR_PROCESO=3
readonly EXIT_ERROR_RED=4
readonly EXIT_ERROR_CONFIGURACION=5
readonly EXIT_ERROR_SIGNAL=6
readonly EXIT_ERROR_TIMEOUT=7
readonly EXIT_ERROR_DEPENDENCIA=8
readonly EXIT_ERROR_VALIDACION=9
readonly EXIT_ERROR_ARCHIVO=10
readonly EXIT_ERROR_MEMORIA=11
readonly EXIT_ERROR_DISCO=12
readonly EXIT_ERROR_SERVICIO=13
readonly EXIT_ERROR_AUTENTICACION=14
readonly EXIT_ERROR_PROTOCOLO=15
readonly EXIT_ERROR_VERSION=16
readonly EXIT_ERROR_ESTADO=17
readonly EXIT_ERROR_RECURSO=18
readonly EXIT_ERROR_LIMITE=19
readonly EXIT_ERROR_USUARIO=20

# Función para traducir código a mensaje
obtener_mensaje_error() {
    local codigo=$1
    case $codigo in
        0) echo "Éxito" ;;
        1) echo "Error general" ;;
        2) echo "Error de permisos" ;;
        3) echo "Error de proceso" ;;
        4) echo "Error de red" ;;
        5) echo "Error de configuración" ;;
        6) echo "Error de señal" ;;
        7) echo "Error de timeout" ;;
        8) echo "Error de dependencia" ;;
        9) echo "Error de validación" ;;
        10) echo "Error de archivo" ;;
        11) echo "Error de memoria" ;;
        12) echo "Error de disco" ;;
        13) echo "Error de servicio" ;;
        14) echo "Error de autenticación" ;;
        15) echo "Error de protocolo" ;;
        16) echo "Error de versión" ;;
        17) echo "Error de estado" ;;
        18) echo "Error de recurso" ;;
        19) echo "Error de límite" ;;
        20) echo "Error de usuario" ;;
        *) echo "Error desconocido ($codigo)" ;;
    esac
}

# Función para manejar salida con código
salir_con_error() {
    local codigo=$1
    local mensaje="${2:-$(obtener_mensaje_error $codigo)}"

    log_mensaje "ERROR" "$mensaje (código: $codigo)"
    exit $codigo
}
```

## Ejemplos de Uso

### Verificación de permisos:
```bash
if [[ ! -w "$LOG_DIR" ]]; then
    salir_con_error $EXIT_ERROR_PERMISOS "No se puede escribir en $LOG_DIR"
fi
```

### Verificación de puerto:
```bash
if lsof -i:$PORT >/dev/null 2>&1; then
    salir_con_error $EXIT_ERROR_RED "Puerto $PORT ya está en uso"
fi
```

### Verificación de dependencias:
```bash
if ! command -v systemctl >/dev/null 2>&1; then
    salir_con_error $EXIT_ERROR_DEPENDENCIA "systemctl no está disponible"
fi
```

### Timeout en operación:
```bash
timeout 30 comando_largo || salir_con_error $EXIT_ERROR_TIMEOUT "Operación excedió 30 segundos"
```

## Convenciones y Mejores Prácticas

1. **Usar siempre constantes**, nunca números mágicos:
   - ✅ `exit $EXIT_ERROR_RED`
   - ❌ `exit 4`

2. **Documentar códigos personalizados** en el script:
   ```bash
   # Códigos de salida personalizados (21-30)
   readonly EXIT_ERROR_CUSTOM_DB=21  # Error de base de datos
   ```

3. **Propagar códigos en funciones**:
   ```bash
   funcion() {
       comando || return $EXIT_ERROR_PROCESO
   }
   ```

4. **Capturar y reenviar códigos**:
   ```bash
   funcion
   resultado=$?
   [[ $resultado -ne 0 ]] && exit $resultado
   ```

5. **Log antes de salir** para debugging:
   ```bash
   log_mensaje "ERROR" "Descripción del error"
   exit $EXIT_ERROR_ESPECIFICO
   ```

## Testing de Códigos de Salida

### Script de prueba:
```bash
#!/bin/bash
# test_exit_codes.sh

source ./gestor_procesos.sh

echo "Probando códigos de salida..."

# Test cada código
for codigo in {0..20}; do
    mensaje=$(obtener_mensaje_error $codigo)
    echo "Código $codigo: $mensaje"
done

# Verificar propagación
./gestor_procesos.sh comando_invalido
echo "Código de salida: $?"
```

## Integración con systemd

Los códigos de salida son importantes para systemd:

```ini
[Service]
# Reiniciar solo en ciertos códigos
RestartPreventExitStatus=9 20
# No reiniciar en errores de configuración
RestartPreventExitStatus=5
# Considerar exitoso algunos códigos
SuccessExitStatus=0 20
```

## Monitoreo y Alertas

Usar códigos para monitoreo automatizado:

```bash
# Monitor script
./gestor_procesos.sh estado
case $? in
    0) echo "Sistema funcionando" ;;
    4) alerta "Error de red detectado" ;;
    7) alerta "Timeout - posible sobrecarga" ;;
    *) alerta "Error desconocido: $?" ;;
esac
```