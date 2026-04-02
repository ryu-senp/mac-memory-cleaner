#!/bin/bash
# remote-install.sh - Bootstrap installer para Mac Cleanup
# Uso: curl -fsSL https://raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/remote-install.sh | bash

set -e  # Exit on error

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Banner
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        Mac Cleanup - Remote Installer                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
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

# 2. Verificar permisos de admin
if ! groups | grep -q '\badmin\b'; then
    echo -e "${RED}✗ Tu usuario no tiene permisos de administrador${NC}"
    echo ""
    echo "Este script requiere que estés en el grupo 'admin'."
    echo "Contacta al administrador del sistema."
    exit 1
fi
echo -e "${GREEN}✓ Permisos de administrador verificados${NC}"
echo ""

# 3. Determinar directorio de instalación
INSTALL_DIR="$HOME/.mac-cleanup"
REPO_URL="https://github.com/ryu-senp/mac-memory-cleaner.git"

# 4. Clonar o actualizar repositorio
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}📁 Directorio ya existe, actualizando...${NC}"
    cd "$INSTALL_DIR"
    git pull origin main
    echo -e "${GREEN}✓ Repositorio actualizado${NC}"
else
    echo -e "${BLUE}📥 Descargando Mac Cleanup desde GitHub...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
    echo -e "${GREEN}✓ Descarga completa${NC}"
fi

echo ""

# 5. Ejecutar instalador local
cd "$INSTALL_DIR"
chmod +x install.sh
echo -e "${BLUE}🔧 Ejecutando instalador...${NC}"
echo ""
./install.sh "$@"

# 6. Mensaje final
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Instalación remota completada${NC}"
echo ""
echo "El código fuente está en: ${BLUE}$INSTALL_DIR${NC}"
echo "Puedes mantenerlo para futuras actualizaciones o eliminarlo si deseas."
echo ""
echo "Para actualizar en el futuro:"
echo "  cd $INSTALL_DIR && git pull"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
