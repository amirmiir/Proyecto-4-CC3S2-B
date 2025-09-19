.PHONY: tools build test run clean help
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
	@bats tests/test_basico.bats
	@echo "[INFO] Todos los tests completados exitosamente"

run: 
	@echo "Ejecutando la aplicación..."

clean:
	@echo "Limpiando archivos generados..."

help:
	@echo "Uso: make [target]"