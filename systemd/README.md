# Configuración de Systemd para Gestor Web

## Instalación del Servicio

### 1. Preparar el entorno

```bash
# Crear directorios necesarios
sudo mkdir -p /opt/gestor-web
sudo mkdir -p /etc/gestor-web
sudo mkdir -p /var/log/gestor-web

# Copiar archivos del proyecto
sudo cp -r ../src /opt/gestor-web/
sudo cp gestor.conf.example /etc/gestor-web/gestor.conf

# Ajustar permisos
sudo chown -R nobody:nogroup /opt/gestor-web
sudo chown -R nobody:nogroup /var/log/gestor-web
sudo chmod +x /opt/gestor-web/src/gestor_procesos.sh
```

### 2. Instalar la unidad systemd

```bash
# Copiar archivo de servicio
sudo cp gestor-web.service /etc/systemd/system/

# Recargar configuración de systemd
sudo systemctl daemon-reload

# Habilitar el servicio para inicio automático
sudo systemctl enable gestor-web.service
```

### 3. Gestión del servicio

```bash
# Iniciar el servicio
sudo systemctl start gestor-web

# Detener el servicio
sudo systemctl stop gestor-web

# Reiniciar el servicio
sudo systemctl restart gestor-web

# Ver estado del servicio
sudo systemctl status gestor-web

# Recargar configuración sin reiniciar
sudo systemctl reload gestor-web
```

## Monitoreo con journalctl

```bash
# Ver logs del servicio
sudo journalctl -u gestor-web -f

# Ver últimas 100 líneas
sudo journalctl -u gestor-web -n 100

# Ver logs desde hace 1 hora
sudo journalctl -u gestor-web --since "1 hour ago"

# Filtrar por prioridad
sudo journalctl -u gestor-web -p err

# Exportar logs con formato JSON
sudo journalctl -u gestor-web -o json
```

## Análisis de logs con herramientas Unix

```bash
# Contar errores por hora usando awk
sudo journalctl -u gestor-web --since today | \
  awk '/ERROR/ {print $1, $2}' | \
  cut -d: -f1 | \
  sort | uniq -c

# Extraer tiempos de respuesta
sudo journalctl -u gestor-web | \
  grep "tiempo:" | \
  awk '{print $NF}' | \
  sort -n | \
  tee tiempos.log

# Monitorear en tiempo real con filtros
sudo journalctl -u gestor-web -f | \
  grep --line-buffered "ERROR\|WARN" | \
  tee -a errores.log
```

## Configuración del Servicio

### Variables de Entorno

El servicio lee configuración de:
1. Variables definidas en la unidad systemd
2. Archivo `/etc/gestor-web/gestor.conf`
3. Variables del sistema

### Seguridad

La unidad implementa las siguientes medidas de seguridad:

- **Usuario no privilegiado**: Ejecuta como `nobody:nogroup`
- **PrivateTmp**: Directorio `/tmp` aislado
- **ProtectSystem**: Sistema de archivos de solo lectura
- **ProtectHome**: Sin acceso a directorios home
- **NoNewPrivileges**: No puede elevar privilegios
- **Límites de recursos**: CPU 50%, Memoria 256MB

### Señales Soportadas

El servicio maneja las siguientes señales:

- `SIGTERM`: Apagado controlado (systemctl stop)
- `SIGHUP`: Recarga de configuración (systemctl reload)
- `SIGUSR1`: Muestra estado detallado
- `SIGUSR2`: Rotación de logs

Ejemplo de uso de señales:
```bash
# Obtener PID del servicio
sudo systemctl show gestor-web --property MainPID

# Enviar señal USR1 para estado
sudo kill -USR1 $(sudo systemctl show gestor-web --property MainPID | cut -d= -f2)
```

## Solución de Problemas

### El servicio no inicia

```bash
# Verificar errores
sudo systemctl status gestor-web -l
sudo journalctl -xe -u gestor-web

# Verificar permisos
ls -la /opt/gestor-web/src/gestor_procesos.sh
ls -la /var/log/gestor-web/
```

### Puerto en uso

```bash
# Verificar qué usa el puerto
sudo ss -tulpn | grep :8080
sudo lsof -i :8080

# Cambiar puerto en /etc/gestor-web/gestor.conf
```

### Consumo excesivo de recursos

```bash
# Ver métricas del servicio
sudo systemctl status gestor-web
sudo journalctl -u gestor-web -o verbose

# Ajustar límites en gestor-web.service
# CPUQuota=30%
# MemoryLimit=128M
```

## Integración con el Proyecto

### Makefile targets

```makefile
# Target para instalar el servicio
install-service:
	sudo mkdir -p /opt/gestor-web /etc/gestor-web /var/log/gestor-web
	sudo cp -r src /opt/gestor-web/
	sudo cp systemd/gestor.conf.example /etc/gestor-web/gestor.conf
	sudo cp systemd/gestor-web.service /etc/systemd/system/
	sudo systemctl daemon-reload
	sudo systemctl enable gestor-web

# Target para desinstalar
uninstall-service:
	sudo systemctl stop gestor-web || true
	sudo systemctl disable gestor-web || true
	sudo rm -f /etc/systemd/system/gestor-web.service
	sudo systemctl daemon-reload
```

## Notas de Implementación

Este servicio systemd sigue las mejores prácticas:

1. **12-Factor App**: Configuración mediante variables de entorno
2. **DevSecOps**: Logs centralizados con journald
3. **Seguridad**: Mínimos privilegios necesarios
4. **Robustez**: Reinicio automático en fallos
5. **Monitoreo**: Integración completa con journalctl

El servicio está preparado para producción con límites de recursos, manejo de señales y configuración flexible.