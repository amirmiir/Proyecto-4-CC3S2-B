.PHONY: tools build test run stop status logs clean help
tools:
	@echo "Verificando herramientas necesarias..."
	@command -v curl >/dev/null 2>&1 || { echo "Error: curl no está instalado"; exit 1; }
	@command -v dig >/dev/null 2>&1 || { echo "Error: dig no está instalado"; exit 1; }
	@command -v ss >/dev/null 2>&1 || { echo "Error: ss no está instalado"; exit 1; }
	@command -v nc >/dev/null 2>&1 || { echo "Error: nc no está instalado"; exit 1; }
	@command -v awk >/dev/null 2>&1 || { echo "Error: awk no está instalado"; exit 1; }
	@command -v grep >/dev/null 2>&1 || { echo "Error: grep no está instalado"; exit 1; }
	@command -v sed >/dev/null 2>&1 || { echo "Error: sed no está instalado"; exit 1; }
	@command -v cut >/dev/null 2>&1 || { echo "Error: cut no está instalado"; exit 1; }
	@command -v sort >/dev/null 2>&1 || { echo "Error: sort no está instalado"; exit 1; }
	@command -v uniq >/dev/null 2>&1 || { echo "Error: uniq no está instalado"; exit 1; }
	@command -v tr >/dev/null 2>&1 || { echo "Error: tr no está instalado"; exit 1; }
	@command -v tee >/dev/null 2>&1 || { echo "Error: tee no está instalado"; exit 1; }
	@command -v find >/dev/null 2>&1 || { echo "Error: find no está instalado"; exit 1; }
	@command -v systemctl >/dev/null 2>&1 || { echo "Error: systemctl no está instalado"; exit 1; }
	@command -v journalctl >/dev/null 2>&1 || { echo "Error: journalctl no está instalado"; exit 1; }
	@command -v ip >/dev/null 2>&1 || { echo "Error: ip no está instalado"; exit 1; }
	@command -v rsync >/dev/null 2>&1 || { echo "Error: rsync no está instalado"; exit 1; }
	@echo "Todas las herramientas necesarias están disponibles"

build: tools
	@echo "Construyendo el proyecto..."
	@mkdir -p out/bin out/logs out/config
	@echo "[INFO] Creando directorios de artefactos en out/"

	# Copiar scripts ejecutables
	@cp src/gestor_procesos.sh out/bin/
	@cp src/monitor_redes.sh out/bin/
	@cp src/analizar_metricas.sh out/bin/ 2>/dev/null || true
	@cp src/verificar_sockets.sh out/bin/ 2>/dev/null || true
	@cp src/analizar_tls.sh out/bin/ 2>/dev/null || true
	@cp src/procesador_toolkit.sh out/bin/ 2>/dev/null || true
	@cp src/sincronizar_rsync.sh out/bin/ 2>/dev/null || true
	@cp src/test_puertos_nc.sh out/bin/ 2>/dev/null || true
	@chmod +x out/bin/*.sh

	# Crear archivo de configuración
	@if [ -f .env ]; then \
		cp .env out/config/; \
	else \
		cp .env.example out/config/.env; \
	fi

	# Crear estructura de logs
	@touch out/logs/.gitkeep

	# Generar información de build
	@echo "VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo 'desarrollo')" > out/build-info.txt
	@echo "BUILD_DATE=$(shell date -Iseconds)" >> out/build-info.txt
	@echo "BUILD_USER=$(shell whoami)" >> out/build-info.txt
	@echo "BUILD_HOST=$(shell hostname)" >> out/build-info.txt

	@echo "[INFO] Artefactos preparados en out/"
	@echo "[INFO] Verificando artefactos..."
	@ls -la out/
	@echo "[INFO] Build completado exitosamente"

test:
	@echo "Ejecutando pruebas..."
	@command -v bats >/dev/null 2>&1 || { echo "Error: bats no está instalado. Instalar con: sudo apt install bats"; exit 1; }
	@echo "[INFO] Ejecutando suite de tests Bats..."
	@echo "[INFO] Tests básicos..."
	@bats tests/test_basico.bats
	@echo "[INFO] Tests de procesos (Sprint 2)..."
	@bats tests/test_procesos.bats
	@echo "[INFO] Tests de redes HTTP/DNS/TLS (Sprint 2)..."
	@bats tests/test_redes.bats
	@echo "[INFO] Tests de systemd..."
	@bats tests/test_systemd.bats
	@echo "[INFO] Todos los tests completados exitosamente"

run: build
	@echo "Ejecutando flujo completo del gestor de procesos..."
	@echo "[INFO] =========================================="
	@echo "[INFO] INICIANDO EJECUCIÓN PRINCIPAL"
	@echo "[INFO] =========================================="
	@echo ""

	# Verificar configuración inicial
	@echo "[INFO] Paso 1: Verificando configuración del sistema..."
	@if [ -f .env ]; then \
		echo "[INFO] Archivo .env encontrado, cargando configuración..."; \
		source .env && echo "[INFO] Variables: PORT=$${PORT:-8080}, MESSAGE='$${MESSAGE:-Servidor activo}', RELEASE=$${RELEASE:-v1.0.0}"; \
	else \
		echo "[INFO] Usando configuración por defecto (.env no encontrado)"; \
	fi
	@echo ""

	# Ejecutar monitoreo de redes primero
	@echo "[INFO] Paso 2: Ejecutando monitoreo de redes..."
	@echo "[INFO] Verificando conectividad HTTP/DNS/TLS..."
	@./out/bin/monitor_redes.sh todo || { \
		echo "[WARN] Monitoreo de redes completado con advertencias"; \
		echo "[INFO] Continuando con la ejecución del gestor..."; \
	}
	@echo ""

	# Mostrar estado del sistema antes de iniciar
	@echo "[INFO] Paso 3: Verificando estado actual del gestor..."
	@./out/bin/gestor_procesos.sh estado || { \
		echo "[INFO] Gestor no está activo, procediendo con inicio..."; \
	}
	@echo ""

	# Iniciar el gestor de procesos
	@echo "[INFO] Paso 4: Iniciando gestor de procesos..."
	@./out/bin/gestor_procesos.sh iniciar || { \
		echo "[ERROR] Error al iniciar el gestor de procesos"; \
		echo "[INFO] Intentando diagnóstico..."; \
		./out/bin/gestor_procesos.sh logs 2>/dev/null || true; \
		exit 1; \
	}
	@echo ""

	# Verificar que el gestor está funcionando
	@echo "[INFO] Paso 5: Verificando funcionamiento del gestor..."
	@sleep 2
	@./out/bin/gestor_procesos.sh estado || { \
		echo "[ERROR] El gestor no responde correctamente"; \
		exit 1; \
	}
	@echo ""

	# Ejecutar verificaciones adicionales
	@echo "[INFO] Paso 6: Ejecutando verificaciones del sistema..."
	@./out/bin/gestor_procesos.sh sockets || echo "[WARN] Verificación de sockets completada con advertencias"
	@echo ""

	# Mostrar información del proceso activo
	@echo "[INFO] Paso 7: Mostrando métricas del sistema..."
	@./out/bin/gestor_procesos.sh metricas || echo "[WARN] Métricas completadas con advertencias"
	@echo ""

	# Información final
	@echo "[INFO] =========================================="
	@echo "[INFO] EJECUCIÓN PRINCIPAL COMPLETADA"
	@echo "[INFO] =========================================="
	@echo "[INFO] El gestor de procesos está activo y funcionando"
	@echo "[INFO] Para detener: make stop"
	@echo "[INFO] Para ver estado: make status"
	@echo "[INFO] Para ver logs: make logs"
	@echo ""

# Targets auxiliares para gestión del proceso
stop:
	@echo "Deteniendo gestor de procesos..."
	@if [ -f out/bin/gestor_procesos.sh ]; then \
		./out/bin/gestor_procesos.sh detener || echo "[WARN] El gestor ya estaba detenido"; \
	else \
		echo "[ERROR] Build requerido. Ejecutar: make build"; \
		exit 1; \
	fi
	@echo "[INFO] Gestor detenido exitosamente"

status:
	@echo "Verificando estado del gestor de procesos..."
	@if [ -f out/bin/gestor_procesos.sh ]; then \
		./out/bin/gestor_procesos.sh estado; \
	else \
		echo "[ERROR] Build requerido. Ejecutar: make build"; \
		exit 1; \
	fi

logs:
	@echo "Mostrando logs del gestor de procesos..."
	@if [ -f out/bin/gestor_procesos.sh ]; then \
		./out/bin/gestor_procesos.sh logs; \
	else \
		echo "[ERROR] Build requerido. Ejecutar: make build"; \
		exit 1; \
	fi

clean:
	@echo "Limpiando archivos generados..."
	@echo "[INFO] Deteniendo procesos activos..."
	@if [ -f out/bin/gestor_procesos.sh ]; then \
		./out/bin/gestor_procesos.sh detener 2>/dev/null || true; \
	fi
	@echo "[INFO] Eliminando directorios de build..."
	@rm -rf out/
	@rm -rf dist/
	@echo "[INFO] Limpiando archivos temporales..."
	@rm -f /tmp/gestor-*.pid /tmp/gestor-*.log 2>/dev/null || true
	@rm -f /tmp/monitor-*.log /tmp/monitor-results.json 2>/dev/null || true
	@echo "[INFO] Limpieza completada"

help:
	@echo "Uso: make [target]"
	@echo ""
	@echo "TARGETS PRINCIPALES:"
	@echo "  tools    - Verificar herramientas del sistema"
	@echo "  build    - Construir artefactos del proyecto"
	@echo "  test     - Ejecutar suite completa de tests"
	@echo "  run      - Ejecutar flujo completo (build + monitoreo + gestor)"
	@echo "  clean    - Limpiar archivos generados"
	@echo ""
	@echo "TARGETS DE GESTIÓN:"
	@echo "  stop     - Detener gestor de procesos"
	@echo "  status   - Ver estado del gestor"
	@echo "  logs     - Ver logs del gestor"
	@echo "  help     - Mostrar esta ayuda"
	@echo ""
	@echo "FLUJO TÍPICO:"
	@echo "  1. make tools    # Verificar dependencias"
	@echo "  2. make test     # Ejecutar tests"
	@echo "  3. make run      # Iniciar aplicación"
	@echo "  4. make status   # Verificar estado"
	@echo "  5. make stop     # Detener cuando termine"
	@echo ""
	@echo "VARIABLES DE ENTORNO:"
	@echo "  PORT     - Puerto del servicio (defecto: 8080)"
	@echo "  MESSAGE  - Mensaje del servidor (defecto: 'Servidor activo')"
	@echo "  RELEASE  - Versión del sistema (defecto: 'v1.0.0')"
	@echo ""
	@echo "Ejemplo: PORT=9090 MESSAGE='Mi servidor' make run"