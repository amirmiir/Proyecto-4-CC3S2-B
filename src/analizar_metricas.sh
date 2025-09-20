#!/bin/bash
# Descripción: Script de parsing avanzado con awk para análisis de logs y métricas
# Autor: Equipo 12
# Fecha: 2025-09-19

set -euo pipefail

# Colores para output
readonly COLOR_VERDE='\033[0;32m'
readonly COLOR_AMARILLO='\033[0;33m'
readonly COLOR_ROJO='\033[0;31m'
readonly COLOR_AZUL='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# Directorio de logs
readonly LOG_DIR="${LOG_DIR:-/tmp/gestor-logs}"
readonly LOG_FILE="$LOG_DIR/gestor-web-$(date +%Y%m%d).log"

# Función para extraer métricas de rendimiento
extraer_metricas_rendimiento() {
    echo -e "${COLOR_AZUL}=== Métricas de Rendimiento ===${COLOR_RESET}"

    if [[ ! -f "$LOG_FILE" ]]; then
        echo "No se encontró archivo de log: $LOG_FILE"
        return 1
    fi

    # Análisis temporal con awk
    echo ""
    echo "Distribución temporal de eventos:"
    awk '
    /^\[/ {
        hora = substr($2, 1, 2)
        horas[hora]++
        total++
    }
    END {
        for (h in horas) {
            porcentaje = (horas[h] * 100) / total
            printf "  Hora %s:00 - %d eventos (%.1f%%)\n", h, horas[h], porcentaje
        }
        printf "\n  Total de eventos: %d\n", total
    }' "$LOG_FILE" | sort

    # Análisis de frecuencia de mensajes
    echo ""
    echo "Frecuencia de mensajes por minuto:"
    awk '
    /^\[/ {
        tiempo = substr($2, 1, 5)
        minutos[tiempo]++
    }
    END {
        max = 0
        for (m in minutos) {
            if (minutos[m] > max) {
                max = minutos[m]
                max_minuto = m
            }
        }
        printf "  Pico de actividad: %s con %d mensajes\n", max_minuto, max

        # Promedio
        if (length(minutos) > 0) {
            suma = 0
            for (m in minutos) suma += minutos[m]
            promedio = suma / length(minutos)
            printf "  Promedio: %.2f mensajes/minuto\n", promedio
        }
    }' "$LOG_FILE"
}

# Función para análisis de errores detallado
analizar_errores_detallado() {
    echo ""
    echo -e "${COLOR_ROJO}=== Análisis Detallado de Errores ===${COLOR_RESET}"

    # Clasificación de errores con awk
    echo ""
    echo "Tipos de errores encontrados:"
    awk '
    /ERROR/ {
        # Extraer tipo de error
        if (/Error en línea/) {
            linea = $0
            gsub(/.*línea /, "", linea)
            gsub(/:.*/, "", linea)
            errores_linea[linea]++
        }
        else if (/Error de red/) errores["Red"]++
        else if (/Error de permisos/) errores["Permisos"]++
        else if (/Error de configuración/) errores["Configuración"]++
        else if (/Puerto .* ya está en uso/) errores["Puerto en uso"]++
        else if (/No se pudo/) errores["Operación fallida"]++
        else errores["General"]++

        total_errores++
    }
    END {
        if (total_errores > 0) {
            for (tipo in errores) {
                porcentaje = (errores[tipo] * 100) / total_errores
                printf "  %-20s: %d (%.1f%%)\n", tipo, errores[tipo], porcentaje
            }

            if (length(errores_linea) > 0) {
                printf "\n  Líneas con errores:\n"
                for (l in errores_linea) {
                    printf "    Línea %s: %d veces\n", l, errores_linea[l]
                }
            }

            printf "\n  Total de errores: %d\n", total_errores
        } else {
            print "  No se encontraron errores"
        }
    }' "$LOG_FILE"

    # Análisis de códigos de salida
    echo ""
    echo "Códigos de salida detectados:"
    awk '
    /código: [0-9]/ || /código [0-9]/ {
        # Buscar patrones de código
        if (match($0, /código: ([0-9]+)/)) {
            codigo = substr($0, RSTART + 8, RLENGTH - 8)
            codigos[codigo]++
        } else if (match($0, /código ([0-9]+)/)) {
            codigo = substr($0, RSTART + 7, RLENGTH - 7)
            codigos[codigo]++
        }
    }
    END {
        if (length(codigos) > 0) {
            for (c in codigos) {
                descripcion = "Desconocido"
                if (c == 0) descripcion = "Éxito"
                else if (c == 1) descripcion = "Error general"
                else if (c == 2) descripcion = "Error de permisos"
                else if (c == 3) descripcion = "Error de proceso"
                else if (c == 4) descripcion = "Error de red"
                else if (c == 5) descripcion = "Error de configuración"
                else if (c == 6) descripcion = "Error de señal"
                else if (c == 7) descripcion = "Error de timeout"
                else if (c == 8) descripcion = "Error de dependencia"
                else if (c == 9) descripcion = "Error de validación"

                printf "  Código %d (%s): %d veces\n", c, descripcion, codigos[c]
            }
        } else {
            print "  No se detectaron códigos de salida"
        }
    }' "$LOG_FILE"
}

# Función para análisis de señales
analizar_senales() {
    echo ""
    echo -e "${COLOR_AMARILLO}=== Análisis de Señales ===${COLOR_RESET}"

    # Detección de señales con awk
    echo ""
    echo "Señales procesadas:"
    awk '
    /SIG[A-Z]+/ || /señal/ {
        if (/SIGTERM/) senales["SIGTERM"]++
        else if (/SIGINT/) senales["SIGINT"]++
        else if (/SIGHUP/) senales["SIGHUP"]++
        else if (/SIGUSR1/) senales["SIGUSR1"]++
        else if (/SIGUSR2/) senales["SIGUSR2"]++
        else if (/SIGQUIT/) senales["SIGQUIT"]++
        else if (/SIGKILL/) senales["SIGKILL"]++
    }
    END {
        if (length(senales) > 0) {
            for (s in senales) {
                printf "  %-10s: %d veces\n", s, senales[s]
            }
        } else {
            print "  No se detectaron señales procesadas"
        }
    }' "$LOG_FILE"

    # Análisis de apagados
    echo ""
    echo "Ciclos de vida del proceso:"
    awk '
    /Iniciando proceso/ { inicios++ }
    /Proceso iniciado/ { iniciados++ }
    /Deteniendo proceso/ { detenciones++ }
    /Proceso terminado/ { terminados++ }
    /Proceso.*detenido completamente/ { completos++ }
    /Limpiando recursos/ { limpiezas++ }
    END {
        printf "  Inicios intentados:     %d\n", inicios+0
        printf "  Inicios exitosos:       %d\n", iniciados+0
        printf "  Detenciones intentadas: %d\n", detenciones+0
        printf "  Detenciones exitosas:   %d\n", terminados+0
        printf "  Apagados completos:     %d\n", completos+0
        printf "  Limpiezas de recursos:  %d\n", limpiezas+0

        if (iniciados > 0 && terminados > 0) {
            tasa = (terminados * 100) / iniciados
            printf "\n  Tasa de apagado limpio: %.1f%%\n", tasa
        }
    }' "$LOG_FILE"
}

# Función para análisis de puertos y conexiones
analizar_puertos() {
    echo ""
    echo -e "${COLOR_VERDE}=== Análisis de Puertos y Conexiones ===${COLOR_RESET}"

    # Análisis de puertos con awk
    echo ""
    echo "Actividad de puertos:"
    awk '
    /puerto [0-9]+|Puerto: [0-9]+/ {
        if (match($0, /[Pp]uerto: ([0-9]+)/)) {
            puerto = substr($0, RSTART + 8, RLENGTH - 8)
            puertos[puerto]++

            # Detectar si es inicio o error
            if (/Iniciando|iniciado/) {
                puertos_ok[puerto]++
            } else if (/ERROR|ya está en uso/) {
                puertos_error[puerto]++
            }
        }
    }
    END {
        for (p in puertos) {
            estado = "Usado"
            if (puertos_error[p] > 0) estado = "Con errores"
            else if (puertos_ok[p] > 0) estado = "Activo"

            printf "  Puerto %-5s: %d accesos (Estado: %s)\n", p, puertos[p], estado

            if (puertos_ok[p] > 0) {
                printf "    - Inicios exitosos: %d\n", puertos_ok[p]
            }
            if (puertos_error[p] > 0) {
                printf "    - Errores: %d\n", puertos_error[p]
            }
        }
    }' "$LOG_FILE"

    # Análisis de cambios de puerto
    echo ""
    echo "Secuencia de puertos utilizados:"
    awk '
    /Iniciando proceso en puerto [0-9]+/ {
        if (match($0, /puerto ([0-9]+)/)) {
            puerto = substr($0, RSTART + 7, RLENGTH - 7)
            tiempo = substr($1, 2, 8)
            printf "  %s -> Puerto %s\n", tiempo, puerto
        }
    }' "$LOG_FILE"
}

# Función para generar resumen ejecutivo
generar_resumen() {
    echo ""
    echo -e "${COLOR_AZUL}=== RESUMEN EJECUTIVO ===${COLOR_RESET}"
    echo ""

    # Resumen con awk en una sola pasada
    awk '
    BEGIN {
        inicio_tiempo = ""
        fin_tiempo = ""
    }
    /^\[/ {
        tiempo = substr($1, 2) " " $2
        if (inicio_tiempo == "") inicio_tiempo = tiempo
        fin_tiempo = tiempo
        total_lineas++

        if (/INFO/) info++
        else if (/WARN/) warn++
        else if (/ERROR/) error++
    }
    /Iniciando proceso/ { procesos_iniciados++ }
    /Proceso terminado/ { procesos_terminados++ }
    /puerto [0-9]+/ {
        if (match($0, /puerto ([0-9]+)/)) {
            puerto = substr($0, RSTART + 7, RLENGTH - 7)
            puertos[puerto] = 1
        }
    }
    END {
        print "  Período analizado:"
        if (inicio_tiempo != "") {
            printf "    Desde: %s\n", inicio_tiempo
            printf "    Hasta: %s\n", fin_tiempo
        }

        print "\n  Estadísticas generales:"
        printf "    Total de eventos:     %d\n", total_lineas
        printf "    Mensajes INFO:        %d (%.1f%%)\n", info, (info*100)/total_lineas
        printf "    Mensajes WARN:        %d (%.1f%%)\n", warn, (warn*100)/total_lineas
        printf "    Mensajes ERROR:       %d (%.1f%%)\n", error, (error*100)/total_lineas

        print "\n  Actividad del proceso:"
        printf "    Procesos iniciados:   %d\n", procesos_iniciados
        printf "    Procesos terminados:  %d\n", procesos_terminados
        printf "    Puertos únicos:       %d\n", length(puertos)

        # Calificación de salud
        salud = 100
        if (error > 0) salud -= (error * 5)
        if (warn > 0) salud -= (warn * 2)
        if (salud < 0) salud = 0

        print "\n  Salud del sistema:"
        if (salud >= 90) estado = "EXCELENTE"
        else if (salud >= 70) estado = "BUENA"
        else if (salud >= 50) estado = "REGULAR"
        else estado = "CRÍTICA"

        printf "    Puntuación: %d/100 (%s)\n", salud, estado

        # Recomendaciones
        print "\n  Recomendaciones:"
        if (error > 5) print "    ⚠ Alto número de errores - revisar configuración"
        if (warn > 10) print "    ⚠ Múltiples advertencias - verificar estado"
        if (procesos_iniciados > procesos_terminados) {
            print "    ⚠ Procesos sin terminar correctamente"
        }
        if (salud >= 90) print "    ✓ Sistema funcionando correctamente"
    }' "$LOG_FILE"
}

# Función principal
main() {
    echo -e "${COLOR_AZUL}╔══════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_AZUL}║   ANÁLISIS AVANZADO DE LOGS CON AWK     ║${COLOR_RESET}"
    echo -e "${COLOR_AZUL}╚══════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo "Archivo analizado: $LOG_FILE"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Verificar que existe el archivo
    if [[ ! -f "$LOG_FILE" ]]; then
        echo -e "${COLOR_ROJO}ERROR: No se encontró el archivo de log${COLOR_RESET}"
        exit 1
    fi

    # Ejecutar todos los análisis
    extraer_metricas_rendimiento
    analizar_errores_detallado
    analizar_senales
    analizar_puertos
    generar_resumen

    echo ""
    echo -e "${COLOR_VERDE}=== Análisis completado ===${COLOR_RESET}"
}

# Ejecutar si es llamado directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi