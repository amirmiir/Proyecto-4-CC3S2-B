# Métricas y Umbrales del Sistema

## Descripción General

Este documento define las métricas de rendimiento, umbrales de alerta y criterios de salud del sistema para el gestor de procesos seguros. Las métricas se recolectan automáticamente y se evalúan según umbrales predefinidos para garantizar el funcionamiento óptimo del sistema.

## Códigos de Salida y Sus Umbrales

### Códigos de Salida Estándar

| Código | Descripción | Umbral Crítico | Umbral Advertencia | Acción Requerida |
|--------|-------------|----------------|-------------------|------------------|
| 0 | Éxito | N/A | N/A | Ninguna |
| 1 | Error general | >10/hora | >5/hora | Investigar logs |
| 2 | Error de permisos | >5/hora | >2/hora | Verificar permisos |
| 3 | Error de proceso | >8/hora | >3/hora | Revisar estado del proceso |
| 4 | Error de red | >15/hora | >7/hora | Verificar conectividad |
| 5 | Error de configuración | >3/hora | >1/hora | Revisar archivo .env |
| 6 | Error de señal | >20/hora | >10/hora | Verificar manejo de señales |
| 7 | Error de timeout | >12/hora | >6/hora | Ajustar timeouts |
| 8 | Error de dependencia | >5/hora | >2/hora | Verificar herramientas |
| 9 | Error de validación | >25/hora | >15/hora | Revisar parámetros |

## Métricas de Rendimiento HTTP/DNS

### Tiempos de Respuesta HTTP

| Métrica | Umbral Óptimo | Umbral Advertencia | Umbral Crítico |
|---------|---------------|-------------------|----------------|
| Tiempo total | <2.0s | 2.0-5.0s | >5.0s |
| Tiempo conexión | <0.5s | 0.5-1.0s | >1.0s |
| Tiempo primer byte | <1.0s | 1.0-3.0s | >3.0s |
| Velocidad descarga | >100KB/s | 50-100KB/s | <50KB/s |

### Resolución DNS

| Métrica | Umbral Óptimo | Umbral Advertencia | Umbral Crítico |
|---------|---------------|-------------------|----------------|
| Tiempo consulta | <100ms | 100-500ms | >500ms |
| Tasa éxito | >95% | 90-95% | <90% |
| Timeouts DNS | <2/hora | 2-5/hora | >5/hora |

## Métricas de Gestión de Procesos

### Ciclo de Vida del Proceso

| Métrica | Umbral Óptimo | Umbral Advertencia | Umbral Crítico |
|---------|---------------|-------------------|----------------|
| Tiempo inicio | <3s | 3-10s | >10s |
| Tiempo detención | <5s | 5-15s | >15s |
| Fallos de inicio | 0/día | 1-3/día | >3/día |
| Reinicios no planificados | 0/día | 1-2/día | >2/día |

### Gestión de Memoria y CPU

| Métrica | Umbral Óptimo | Umbral Advertencia | Umbral Crítico |
|---------|---------------|-------------------|----------------|
| Uso de memoria | <100MB | 100-200MB | >200MB |
| Uso de CPU | <30% | 30-50% | >50% |
| Archivos abiertos | <50 | 50-100 | >100 |
| Procesos hijo | <5 | 5-10 | >10 |

## Métricas de Conectividad y Puertos

### Verificación de Puertos

| Métrica | Umbral Óptimo | Umbral Advertencia | Umbral Crítico |
|---------|---------------|-------------------|----------------|
| Puerto principal disponible | 100% | 95-100% | <95% |
| Conexiones activas | <10 | 10-50 | >50 |
| Tiempo bind puerto | <100ms | 100-500ms | >500ms |
| Fallos de conexión | 0/hora | 1-5/hora | >5/hora |

### Análisis TLS/SSL

| Métrica | Umbral Óptimo | Umbral Advertencia | Umbral Crítico |
|---------|---------------|-------------------|----------------|
| Tiempo handshake TLS | <300ms | 300-1000ms | >1000ms |
| Certificados válidos | 100% | 95-100% | <95% |
| Versiones TLS obsoletas | 0% | 1-5% | >5% |
| Fallos verificación SSL | 0/día | 1-3/día | >3/día |

## Logging y Diagnóstico

### Métricas de Logs

| Métrica | Umbral Óptimo | Umbral Advertencia | Umbral Crítico |
|---------|---------------|-------------------|----------------|
| Tamaño archivos log | <50MB/día | 50-100MB/día | >100MB/día |
| Mensajes ERROR/hora | <5 | 5-20 | >20 |
| Mensajes WARN/hora | <15 | 15-50 | >50 |
| Rotación logs | Éxito | 1 fallo/semana | >1 fallo/semana |

### Puntuación de Salud del Sistema

La puntuación de salud se calcula usando la siguiente fórmula:

```bash
Puntuación = 100 - (errores_críticos * 20) - (errores_advertencia * 5) - (timeouts * 3)
```

| Rango | Estado | Acción Requerida |
|-------|--------|------------------|
| 90-100 | EXCELENTE | Ninguna |
| 75-89 | BUENO | Monitoreo rutinario |
| 50-74 | REGULAR | Investigación recomendada |
| 25-49 | MALO | Acción correctiva requerida |
| 0-24 | CRÍTICO | Intervención inmediata |

## Alertas y Notificaciones

### Configuración de Alertas

#### Alertas Críticas (Inmediatas)
- Múltiples errores de código 5 (configuración)
- Tiempo de respuesta HTTP >5 segundos
- Fallos DNS >5/hora
- Puntuación de salud <25

#### Alertas de Advertencia (Dentro de 1 hora)
- Errores de red >7/hora
- Tiempo de respuesta HTTP 2-5 segundos
- Uso de memoria >100MB
- Puntuación de salud 25-49

### Comandos de Monitoreo

```bash
# Verificar métricas en tiempo real
make status

# Analizar métricas históricas
./src/gestor_procesos.sh metricas

# Verificar estado de sockets
./src/gestor_procesos.sh sockets

# Monitoreo de redes completo
./src/monitor_redes.sh todo
```

## Configuración de Umbrales

### Variables de Entorno para Umbrales

```bash
# Timeouts
export TIMEOUT=10                    # Timeout general (segundos)
export HTTP_TIMEOUT=5               # Timeout HTTP específico
export DNS_TIMEOUT=3                # Timeout DNS específico

# Límites de rendimiento
export MAX_MEMORY_MB=200            # Memoria máxima permitida
export MAX_CPU_PERCENT=50           # CPU máximo permitido
export MAX_CONNECTIONS=50           # Conexiones máximas

# Umbrales de error
export MAX_ERRORS_PER_HOUR=10       # Errores máximos por hora
export MAX_WARNINGS_PER_HOUR=25     # Advertencias máximas por hora

# Configuración de logs
export MAX_LOG_SIZE_MB=100          # Tamaño máximo de logs
export LOG_RETENTION_DAYS=7         # Días de retención de logs
```

## Procedimientos de Escalamiento

### Nivel 1: Alertas de Advertencia
1. Incrementar frecuencia de monitoreo
2. Revisar logs para patrones
3. Verificar recursos del sistema
4. Documentar en bitácora

### Nivel 2: Alertas Críticas
1. Notificación inmediata al equipo
2. Ejecución de diagnósticos automatizados
3. Revisión de configuración del sistema
4. Implementación de medidas correctivas
5. Escalamiento a Nivel 3 si no se resuelve en 30 minutos

### Nivel 3: Emergencia del Sistema
1. Parada controlada del sistema
2. Análisis forense de logs
3. Identificación de causa raíz
4. Implementación de fix
5. Reinicio controlado con monitoreo intensivo

## Tests de Métricas

Los siguientes tests validan que las métricas se mantienen dentro de umbrales aceptables:

```bash
# Ejecutar tests de métricas
bats tests/test_procesos.bats    # Incluye validación de códigos de salida
bats tests/test_redes.bats       # Incluye métricas de red
bats tests/test_systemd.bats     # Incluye métricas de sistema

# Verificar todos los umbrales
make test
```

## Historial de Cambios

| Fecha | Versión | Cambios |
|-------|---------|---------|
| 2025-09-19 | 1.0.0 | Creación inicial del documento |
| 2025-09-19 | 1.1.0 | Agregados umbrales de TLS y DNS |
| 2025-09-19 | 1.2.0 | Configuración de alertas y escalamiento |

---
