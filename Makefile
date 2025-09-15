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

build: 
	@echo "Construyendo el proyecto..."

test: 
	@echo "Ejecutando pruebas..."

run: 
	@echo "Ejecutando la aplicación..."

clean:
	@echo "Limpiando archivos generados..."

help:
	@echo "Uso: make [target]"