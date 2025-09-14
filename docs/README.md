# Proyecto 4 - Gestor de Procesos Seguros

## Descripción

Sistema de gestión de procesos con enfoque en monitoreo de redes. Implementa principios de 12-Factor App para configuración mediante variables de entorno.

## Instalación y Uso

El script principal se encuentra en `src/gestor_procesos.sh`. Para ejecutarlo se requiere Bash 4.0 o superior.

Comandos disponibles:
```bash
./src/gestor_procesos.sh iniciar  # Inicia el proceso
./src/gestor_procesos.sh detener  # Detiene el proceso
./src/gestor_procesos.sh estado   # Muestra el estado
```

## Variables de Entorno

El sistema utiliza las siguientes variables de entorno con valores por defecto:

| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| PORT | Puerto del servicio | 8080 |
| MESSAGE | Mensaje del servidor | Servidor activo |
| RELEASE | Versión del sistema | v1.0.0 |

Para usar valores personalizados:
```bash
PORT=9090 MESSAGE="Mi servidor" ./src/gestor_procesos.sh iniciar
```

## Códigos de Salida

El script retorna códigos específicos según el tipo de error:

0 - Éxito
1 - Error general
2 - Error de permisos
3 - Error de proceso
4 - Error de red
5 - Error de configuración
6 - Error de señal
7 - Error de timeout
8 - Error de dependencia
9 - Error de validación


## Equipo

Grupo 12: Iman Noriega Melissa, Canto Amir, Orrego Torrejon Diego