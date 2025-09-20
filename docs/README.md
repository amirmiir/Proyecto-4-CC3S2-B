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

#### Comandos básicos (sin systemd)
```bash
./src/gestor_procesos.sh iniciar  # Inicia el proceso
./src/gestor_procesos.sh detener  # Detiene el proceso
./src/gestor_procesos.sh estado   # Muestra el estado
```

#### Comandos systemd
```bash
./src/gestor_procesos.sh start     # Inicia via systemctl
./src/gestor_procesos.sh stop      # Detiene via systemctl
./src/gestor_procesos.sh restart   # Reinicia servicio
./src/gestor_procesos.sh reload    # Recarga configuración

# Control avanzado
./src/gestor_procesos.sh systemctl status   # Estado detallado
./src/gestor_procesos.sh systemctl enable   # Habilitar inicio automático
./src/gestor_procesos.sh systemctl disable  # Deshabilitar inicio automático
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

### Testing
- `bats` - Framework de testing para Bash
- `shellcheck` - Análisis estático de scripts (opcional)

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
| SIGTSTP | `kill -TSTP <pid>` o Ctrl+Z | Pausa el proceso |
| SIGCONT | `kill -CONT <pid>` | Reanuda proceso pausado |
| SIGALRM | `kill -ALRM <pid>` | Verifica salud y reinicia si necesario |
| SIGPIPE | (automática) | Maneja pipes rotas y procesos zombie |

**Nota**: SIGKILL (9) no puede ser atrapado por diseño del sistema operativo

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

## Testing

El proyecto incluye una suite completa de tests implementada con Bats (Bash Automated Testing System).

### Ejecutar Tests

```bash
# Ejecutar todos los tests
make test

# Ejecutar tests específicos
bats tests/test_basico.bats
bats tests/test_procesos.bats
bats tests/test_systemd.bats
```

### Suite de Tests Disponible

#### `tests/test_basico.bats`
- Verificación de scripts y permisos
- Tests básicos de funcionalidad
- Validación de Makefile targets

#### `tests/test_procesos.bats` (Sprint 2)
- Manejo de señales SIGTERM con trap
- Validación de códigos de salida específicos
- Verificación de permisos y directorios
- Gestión de PID files y múltiples instancias
- Integración con systemctl
- Tests de variables de entorno
- Funcionalidad de logging
- Manejo de timeouts y procesos colgados
- Pruebas de resistencia con señales concurrentes

#### `tests/test_systemd.bats`
- Verificación de archivos systemd
- Tests de instalación de servicios
- Validación de configuración

Los tests incluyen configuración automática de setup/teardown para limpiar procesos y archivos temporales, evitando interferencias entre ejecuciones.

## Equipo

Grupo 12: Iman Noriega Melissa, Canto Amir, Orrego Torrejon Diego