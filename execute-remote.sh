#!/bin/bash
# execute-remote.sh - Bootstrap installer/uninstaller para Mac Cleanup
#
# Uso:
#   Instalar:    curl -fsSL https://raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/execute-remote.sh | bash
#   Desinstalar: curl -fsSL https://raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/execute-remote.sh | bash -s -- --uninstall

set -e  # Exit on error

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Detectar modo de operación
MODE="install"  # Por defecto: instalación

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--uninstall)
            MODE="uninstall"
            shift
            ;;
        *)
            echo -e "${YELLOW}⚠️  Opción desconocida: $1${NC}"
            echo ""
            echo "Uso:"
            echo "  Instalar:    curl ... | bash"
            echo "  Desinstalar: curl ... | bash -s -- --uninstall"
            exit 1
            ;;
    esac
done

# Banner
echo ""
if [ "$MODE" = "uninstall" ]; then
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║        Mac Cleanup - Remote Uninstaller                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
else
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║        Mac Cleanup - Remote Installer                        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
fi
echo ""

# 1. Verificar Git
echo -e "${BLUE}🔍 Verificando requisitos...${NC}"
if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ Git no está instalado${NC}"
    echo ""
    echo "Instálalo con Homebrew:"
    echo "  brew install git"
    echo ""
    echo "O descarga manualmente desde:"
    echo "  https://github.com/ryu-senp/mac-memory-cleaner"
    exit 1
fi
echo -e "${GREEN}✓ Git encontrado${NC}"

# 2. Verificar permisos de admin (solo para instalación)
if [ "$MODE" = "install" ]; then
    if ! groups | grep -q '\badmin\b'; then
        echo -e "${RED}✗ Tu usuario no tiene permisos de administrador${NC}"
        echo ""
        echo "Este script requiere que estés en el grupo 'admin'."
        echo "Contacta al administrador del sistema."
        exit 1
    fi
    echo -e "${GREEN}✓ Permisos de administrador verificados${NC}"
fi
echo ""

# 3. Determinar directorio de instalación
INSTALL_DIR="$HOME/.mac-cleanup"
REPO_URL="https://github.com/ryu-senp/mac-memory-cleaner.git"

# 4. Clonar o actualizar repositorio
if [ -d "$INSTALL_DIR" ]; then
    # Verificar si es un repositorio git válido
    if [ -d "$INSTALL_DIR/.git" ]; then
        echo -e "${YELLOW}📁 Directorio ya existe, actualizando...${NC}"
        cd "$INSTALL_DIR"

        # Fetch cambios remotos
        echo -e "${YELLOW}   Obteniendo última versión...${NC}"
        git fetch origin main 2>&1

        # Asegurar que estamos en la rama main
        git checkout main 2>/dev/null || git checkout -b main

        # Forzar reset a la versión remota (descarta cambios locales)
        # Esto es seguro porque es un directorio de instalación, no de desarrollo
        git reset --hard origin/main 2>&1

        echo -e "${GREEN}✓ Repositorio actualizado a la última versión${NC}"
    else
        # Existe pero no es un repo git - eliminar y clonar de nuevo
        echo -e "${YELLOW}⚠️  Directorio existe pero no es un repositorio git${NC}"
        echo -e "${YELLOW}   Eliminando y clonando de nuevo...${NC}"
        rm -rf "$INSTALL_DIR"
        git clone "$REPO_URL" "$INSTALL_DIR"
        echo -e "${GREEN}✓ Descarga completa${NC}"
    fi
else
    echo -e "${BLUE}📥 Descargando Mac Cleanup desde GitHub...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
    echo -e "${GREEN}✓ Descarga completa${NC}"
fi

echo ""

# 5. Ejecutar installer o uninstaller según el modo
cd "$INSTALL_DIR"

if [ "$MODE" = "uninstall" ]; then
    # Modo desinstalación
    chmod +x uninstall.sh
    echo -e "${BLUE}🗑️  Ejecutando desinstalador...${NC}"
    echo ""
    ./uninstall.sh "$@"
else
    # Modo instalación
    chmod +x install.sh
    echo -e "${BLUE}🔧 Ejecutando instalador...${NC}"
    echo ""
    ./install.sh "$@"
fi

# 6. Mensaje final
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$MODE" = "uninstall" ]; then
    echo -e "${GREEN}✓ Desinstalación remota completada${NC}"
else
    echo -e "${GREEN}✓ Instalación remota completada${NC}"
fi
echo ""
echo "El código fuente está en: ${BLUE}$INSTALL_DIR${NC}"
if [ "$MODE" = "install" ]; then
    echo "Puedes mantenerlo para futuras actualizaciones o eliminarlo si deseas."
    echo ""
    echo "Para actualizar en el futuro:"
    echo "  cd $INSTALL_DIR && git pull"
fi
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
