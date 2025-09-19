# Proyecto 4 - Gestor de Procesos Seguros

## Descripción

Sistema de gestión de procesos con enfoque en monitoreo de redes. Implementa principios de 12-Factor App para configuración mediante variables de entorno.

## Configuración

Para configurar el sistema, copiar el archivo de ejemplo y ajustar las variables según necesidad:
```bash
cp .env.example .env
# Editar .env con valores personalizados
```

El archivo `.env` no se versiona en Git para mantener la configuración local separada del código.

## Instalación y Uso

El sistema incluye dos scripts principales que requieren Bash 4.0 o superior:

### Gestor de Procesos
```bash
./src/gestor_procesos.sh iniciar  # Inicia el proceso
./src/gestor_procesos.sh detener  # Detiene el proceso
./src/gestor_procesos.sh estado   # Muestra el estado
```

### Monitor de Redes
```bash
./src/monitor_redes.sh http                           # Verificar HTTP por defecto
./src/monitor_redes.sh http https://ejemplo.com 200   # Verificar URL específica
./src/monitor_redes.sh dns                            # Verificar DNS (Sprint 2)
./src/monitor_redes.sh tls                            # Verificar TLS (Sprint 2)
./src/monitor_redes.sh ayuda                          # Mostrar ayuda
```

## Variables de Entorno

El sistema utiliza las siguientes variables de entorno con valores por defecto:

### Gestor de Procesos
| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| PORT | Puerto del servicio | 8080 |
| MESSAGE | Mensaje del servidor | Servidor activo |
| RELEASE | Versión del sistema | v1.0.0 |

### Monitor de Redes
| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| DNS_SERVER | Servidor DNS a usar | 8.8.8.8 |
| TARGETS | Hosts separados por comas | google.com,github.com |
| CONFIG_URL | URL para pruebas HTTP | http://httpbin.org/status/200 |
| TIMEOUT | Timeout en segundos | 10 |

Ejemplos de uso:
```bash
# Gestor de procesos
PORT=9090 MESSAGE="Mi servidor" ./src/gestor_procesos.sh iniciar

# Monitor de redes
TARGETS="ejemplo.com,test.com" ./src/monitor_redes.sh http
CONFIG_URL="https://api.github.com" ./src/monitor_redes.sh http
```

## Códigos de Salida

Ambos scripts utilizan códigos de salida específicos según el tipo de error:

| Código | Descripción |
|--------|-------------|
| 0 | Éxito |
| 1 | Error general |
| 2 | Error de permisos |
| 3 | Error de proceso |
| 4 | Error de red |
| 5 | Error de configuración |
| 6 | Error de señal |
| 7 | Error de timeout |
| 8 | Error de dependencia |
| 9 | Error de validación |

## Dependencias

### Monitor de Redes
- `curl` - Para peticiones HTTP/HTTPS
- `dig` - Para consultas DNS (Sprint 2)
- `openssl` - Para verificación TLS (Sprint 2)

### Logs

Los scripts generan logs en:
- Gestor de procesos: `/tmp/gestor-logs/gestor-web-YYYYMMDD.log`
- Monitor de redes: `/tmp/monitor-logs/monitor-YYYYMMDD.log`

Todos los mensajes incluyen timestamp y nivel (INFO, WARN, ERROR). El sistema de logging centralizado facilita el debugging y auditoría.

## Manejo de Errores y Señales

El gestor de procesos implementa manejo robusto de errores mediante:
- **Trap ERR**: Captura errores y muestra línea y comando que falló
- **Trap EXIT**: Limpia recursos automáticamente al salir
- **Códigos de salida**: Retorna códigos específicos según el tipo de error

### Señales Soportadas

El sistema maneja las siguientes señales Unix:

| Señal | Comando | Acción |
|-------|---------|---------|
| SIGINT | `kill -INT <pid>` o Ctrl+C | Interrupción con limpieza de recursos |
| SIGTERM | `kill -TERM <pid>` | Apagado controlado con timeout |
| SIGHUP | `kill -HUP <pid>` | Recarga configuración desde .env |
| SIGUSR1 | `kill -USR1 <pid>` | Muestra estado detallado del sistema |
| SIGUSR2 | `kill -USR2 <pid>` | Rota archivos de log con backup |
| SIGQUIT | `kill -QUIT <pid>` | Terminación forzada inmediata |

Ejemplo de uso:
```bash
# Iniciar proceso
$ ./src/gestor_procesos.sh iniciar

# Mostrar estado detallado
$ kill -USR1 $(cat /tmp/gestor-web.pid)

# Recargar configuración
$ kill -HUP $(cat /tmp/gestor-web.pid)

# Detener con apagado controlado
$ ./src/gestor_procesos.sh detener
```


## Equipo

Grupo 12: Iman Noriega Melissa, Canto Amir, Orrego Torrejon Diego