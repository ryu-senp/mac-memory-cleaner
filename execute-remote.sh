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

# 0. Determinar directorio de instalación PRIMERO (antes de verificar nada)
DEFAULT_INSTALL_DIR="$HOME/.mac-cleanup"
REPO_URL="https://github.com/ryu-senp/mac-memory-cleaner.git"

if [ "$MODE" = "install" ]; then
    # Preguntar DIRECTORIO BASE (no la ruta completa del repo)
    echo "📁 Directorio base de instalación:"
    echo "   (El repositorio .mac-cleanup se creará dentro)"

    # Usar /dev/tty para leer desde el terminal incluso con curl | bash
    if [ -t 0 ]; then
        # Modo interactivo normal
        read -p "   [default: $HOME]: " BASE_DIR
    else
        # Ejecutado con curl | bash - usar /dev/tty
        echo -n "   [default: $HOME]: "
        read -r BASE_DIR </dev/tty
    fi

    # Si está vacío, usar $HOME por defecto
    BASE_DIR="${BASE_DIR:-$HOME}"

    # Expand ~ to full path if needed
    BASE_DIR="${BASE_DIR/#\~/$HOME}"

    # Construir ruta completa: BASE_DIR/.mac-cleanup
    INSTALL_DIR="$BASE_DIR/.mac-cleanup"

    echo ""
    echo -e "${BLUE}📂 Se instalará en: ${INSTALL_DIR}${NC}"
    echo ""

    # Verificar si ya existe instalación en esa ruta
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${RED}✗ Error: Ya existe instalación en $INSTALL_DIR${NC}"
        echo ""
        echo "Para reinstalar, primero desinstala:"
        echo "  cd $INSTALL_DIR"
        echo "  ./uninstall.sh"
        echo ""
        echo "O usa el desinstalador remoto:"
        echo "  curl -fsSL https://raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/execute-remote.sh | bash -s -- --uninstall"
        echo ""
        exit 1
    fi
else
    # Uninstall mode: use existing env var or default
    INSTALL_DIR="${MAC_CLEANUP_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
fi

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

# ============================================================================
# Función: Guardar variable de entorno en shell config
# ============================================================================
save_to_shell_config() {
    local export_line="$1"

    # Detect shell
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "$(which zsh)" 2>/dev/null ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    else
        SHELL_CONFIG="$HOME/.bashrc"
    fi

    # Check if already exists
    if ! grep -q "MAC_CLEANUP_INSTALL_DIR" "$SHELL_CONFIG" 2>/dev/null; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Mac Cleanup installation directory" >> "$SHELL_CONFIG"
        echo "$export_line" >> "$SHELL_CONFIG"
        echo -e "${GREEN}✓ Variable de entorno agregada a $SHELL_CONFIG${NC}"
        echo "  Ejecuta: source $SHELL_CONFIG (o reinicia la terminal)"
    fi
}

# 3. Guardar variable de entorno si se eligió directorio base personalizado
# Solo si BASE_DIR es diferente de $HOME (default)
if [ "$MODE" = "install" ] && [ "$BASE_DIR" != "$HOME" ]; then
    save_to_shell_config "export MAC_CLEANUP_INSTALL_DIR=\"$INSTALL_DIR\""
    # También exportar en la sesión actual para uso inmediato
    export MAC_CLEANUP_INSTALL_DIR="$INSTALL_DIR"
fi

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
    # Ejecutar en modo force para evitar problemas de stdin con curl | bash
    ./uninstall.sh --force

    # Preguntar si desea eliminar el código fuente descargado
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           ELIMINAR CÓDIGO FUENTE DESCARGADO                  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "${YELLOW}⚠️  El directorio con el código fuente aún existe:${NC}"
    echo "   $INSTALL_DIR"
    echo ""

    # Usar /dev/tty para leer desde el terminal incluso con curl | bash
    if [ -t 0 ]; then
        # Modo interactivo normal
        read -p "¿Deseas eliminarlo también? (yes/no): " delete_source
    else
        # Ejecutado con curl | bash - usar /dev/tty
        echo -n "¿Deseas eliminarlo también? (yes/no): "
        read -r delete_source </dev/tty
    fi

    case "$delete_source" in
        [Yy]|[Yy][Ee][Ss])
            echo ""
            echo -e "${BLUE}🗑️  Eliminando directorio $INSTALL_DIR...${NC}"
            cd "$HOME"  # Salir del directorio antes de eliminarlo
            if rm -rf "$INSTALL_DIR"; then
                echo -e "${GREEN}✓ Código fuente eliminado completamente${NC}"
                SOURCE_DELETED=true
            else
                echo -e "${RED}✗ Error al eliminar el directorio${NC}"
                SOURCE_DELETED=false
            fi
            ;;
        *)
            echo ""
            echo -e "${BLUE}ℹ️  Código fuente preservado en: $INSTALL_DIR${NC}"
            SOURCE_DELETED=false
            ;;
    esac
else
    # Modo instalación
    chmod +x install.sh
    echo -e "${BLUE}🔧 Ejecutando instalador...${NC}"
    echo ""
    ./install.sh "$@"
    SOURCE_DELETED=false
fi

# 6. Mensaje final
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$MODE" = "uninstall" ]; then
    echo -e "${GREEN}✓ Desinstalación remota completada${NC}"
    if [ "$SOURCE_DELETED" = true ]; then
        echo -e "${GREEN}✓ Código fuente eliminado${NC}"
    else
        echo ""
        echo "El código fuente está en: ${BLUE}$INSTALL_DIR${NC}"
        echo "Puedes eliminarlo manualmente con: rm -rf $INSTALL_DIR"
    fi
else
    echo -e "${GREEN}✓ Instalación remota completada${NC}"
    echo ""
    echo "El código fuente está en: ${BLUE}$INSTALL_DIR${NC}"
    echo "Puedes mantenerlo para futuras actualizaciones o eliminarlo si deseas."
    echo ""
    echo "Para actualizar en el futuro:"
    echo "  cd $INSTALL_DIR && git pull"
fi
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
