#!/bin/bash
# install.sh - Instalador Maestro para Mac Cleanup
# Configura: symlink + LaunchAgent con intervalo personalizable

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/mac-maintenance.sh"
SYMLINK_PATH="/usr/local/bin/mac-cleanup"
PLIST_TEMPLATE="$SCRIPT_DIR/templates/com.user.macmaintenance.plist.template"
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.macmaintenance.plist"

# Variable global para almacenar intervalo
INTERVAL_HOURS=6

# ============================================================================
# Mostrar banner
# ============================================================================
show_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║        Mac Cleanup - Instalador de Sistema de Mantenimiento  ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# Crear estructura de directorios
# ============================================================================
setup_directories() {
    echo "📁 Creando estructura de directorios..."

    mkdir -p "$SCRIPT_DIR/logs"
    mkdir -p "$SCRIPT_DIR/config"
    mkdir -p "$SCRIPT_DIR/reports"

    # Verificar que las bibliotecas existen
    if [ ! -d "$SCRIPT_DIR/lib" ]; then
        echo "✗ Error: Directorio lib/ no encontrado"
        echo "   Asegúrate de que todos los archivos estén en su lugar"
        exit 1
    fi

    echo "✓ Directorios creados"
}

# ============================================================================
# Hacer ejecutables los scripts
# ============================================================================
make_executable() {
    echo ""
    echo "🔧 Configurando permisos de ejecución..."

    chmod +x "$SCRIPT_PATH"
    chmod +x "$SCRIPT_DIR"/lib/*.sh 2>/dev/null

    echo "✓ Permisos configurados"
}

# ============================================================================
# Instalar comando a nivel SO
# ============================================================================
install_command() {
    echo ""
    echo "🔧 Instalando comando mac-cleanup a nivel sistema..."

    # Verificar que el script principal existe
    if [ ! -f "$SCRIPT_PATH" ]; then
        echo "✗ Error: mac-maintenance.sh no encontrado en $SCRIPT_PATH"
        exit 1
    fi

    # Verificar si /usr/local/bin existe, si no crearlo
    if [ ! -d "/usr/local/bin" ]; then
        echo "  Creando directorio /usr/local/bin..."
        sudo mkdir -p "/usr/local/bin"
    fi

    # Remover symlink anterior si existe
    if [ -L "$SYMLINK_PATH" ]; then
        echo "  Removiendo symlink anterior..."
        rm "$SYMLINK_PATH" 2>/dev/null || sudo rm "$SYMLINK_PATH"
    fi

    # Crear symlink
    if ln -s "$SCRIPT_PATH" "$SYMLINK_PATH" 2>/dev/null; then
        echo "✓ Symlink creado sin permisos especiales"
    else
        echo "  Se requieren permisos de administrador para crear el symlink..."
        if sudo ln -s "$SCRIPT_PATH" "$SYMLINK_PATH"; then
            echo "✓ Symlink creado con sudo"
        else
            echo "✗ Error al crear symlink"
            echo "   Puedes ejecutar el script directamente: $SCRIPT_PATH"
            return 1
        fi
    fi

    # Verificar instalación
    if [ -L "$SYMLINK_PATH" ]; then
        echo "✓ Comando instalado: mac-cleanup"
        echo "  Ubicación: $SYMLINK_PATH"
        return 0
    else
        echo "⚠️  Advertencia: El comando no se pudo instalar globalmente"
        echo "   Puedes ejecutar el script directamente: $SCRIPT_PATH"
        return 1
    fi
}

# ============================================================================
# Configurar LaunchAgent (Ejecución Automática)
# ============================================================================
setup_launchagent() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║            CONFIGURACIÓN DE EJECUCIÓN AUTOMÁTICA              ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Mac Cleanup puede ejecutarse automáticamente en segundo plano"
    echo "para mantener tu sistema optimizado."
    echo ""

    # Preguntar si quiere ejecución automática
    while true; do
        read -p "¿Configurar ejecución automática periódica? (yes/no): " setup_auto
        setup_auto=$(echo "$setup_auto" | tr '[:upper:]' '[:lower:]')

        case "$setup_auto" in
            yes|y|si|s)
                # Usuario dijo SÍ - continuar con configuración
                break
                ;;
            no|n)
                echo ""
                echo "⊘ Ejecución automática NO configurada"
                echo "  Podrás ejecutar manualmente cuando lo necesites: mac-cleanup"
                echo ""
                return 0
                ;;
            *)
                echo "❌ Por favor responde 'yes' o 'no'"
                ;;
        esac
    done

    # Preguntar intervalo (opciones simplificadas)
    echo ""
    echo "⏰ ¿Cada cuántas horas debe ejecutarse?"
    echo ""
    echo "  1) Cada 1 hora"
    echo "  2) Cada 3 horas"
    echo "  3) Cada 6 horas (recomendado)"
    echo "  4) Cada 12 horas"
    echo "  5) Cada 24 horas (una vez al día)"
    echo ""

    while true; do
        read -p "Selecciona una opción (1-5) [default: 3]: " interval_option
        interval_option=${interval_option:-3}

        case $interval_option in
            1) INTERVAL_HOURS=1; break ;;
            2) INTERVAL_HOURS=3; break ;;
            3) INTERVAL_HOURS=6; break ;;
            4) INTERVAL_HOURS=12; break ;;
            5) INTERVAL_HOURS=24; break ;;
            *)
                echo "❌ Opción inválida. Por favor selecciona 1-5"
                ;;
        esac
    done

    # Convertir horas a segundos
    local interval_seconds=$((INTERVAL_HOURS * 3600))

    echo ""
    echo "📅 Configurando ejecución automática cada $INTERVAL_HOURS hora(s)..."
    echo "   (Usando LaunchAgent de macOS - equivalente a cron)"

    # Verificar que el template existe
    if [ ! -f "$PLIST_TEMPLATE" ]; then
        echo "✗ Error: Template del LaunchAgent no encontrado"
        echo "   Esperado en: $PLIST_TEMPLATE"
        exit 1
    fi

    # Crear directorio de LaunchAgents si no existe
    mkdir -p "$HOME/Library/LaunchAgents"

    # Generar plist desde template
    sed "s|{{INTERVAL_SECONDS}}|$interval_seconds|g; s|{{SCRIPT_PATH}}|$SYMLINK_PATH|g" \
        "$PLIST_TEMPLATE" > "$PLIST_DEST"

    # Verificar que se creó
    if [ ! -f "$PLIST_DEST" ]; then
        echo "✗ Error al generar archivo plist"
        exit 1
    fi

    # Descargar si ya existe (evitar duplicados)
    launchctl unload "$PLIST_DEST" 2>/dev/null

    # Cargar LaunchAgent
    if launchctl load "$PLIST_DEST" 2>/dev/null; then
        echo "✓ LaunchAgent cargado exitosamente"
    else
        echo "⚠️  Advertencia: Hubo un problema al cargar el LaunchAgent"
        echo "   Puedes intentar manualmente con:"
        echo "   launchctl load $PLIST_DEST"
    fi

    # Verificar que está cargado
    sleep 1
    if launchctl list | grep -q "com.user.macmaintenance"; then
        echo "✓ LaunchAgent instalado y activo"
        echo "  Se ejecutará cada $INTERVAL_HOURS hora(s)"
        return 0
    else
        echo "⚠️  Advertencia: El LaunchAgent no aparece en la lista"
        echo "   Puede necesitar reiniciar la sesión"
        return 1
    fi
}

# ============================================================================
# Mostrar resumen de instalación
# ============================================================================
show_summary() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    INSTALACIÓN COMPLETADA                     ║"
    echo "╠═══════════════════════════════════════════════════════════════╣"

    # Verificar comando
    if [ -L "$SYMLINK_PATH" ]; then
        echo "║ ✓ Comando instalado:    mac-cleanup                          ║"
        echo "║   Ubicación:            $SYMLINK_PATH"
    else
        echo "║ ⊘ Comando no instalado globalmente                           ║"
        echo "║   Usar:                 $SCRIPT_PATH"
    fi

    echo "║                                                               ║"
    echo "║ Comandos disponibles:                                         ║"
    echo "║   mac-cleanup              # Modo interactivo (muestra tabla) ║"
    echo "║   mac-cleanup --force      # Sin confirmación                 ║"
    echo "║   mac-cleanup --dry-run    # Solo simular                     ║"
    echo "║   mac-cleanup --aggressive # Limpieza profunda                ║"
    echo "║   mac-cleanup --help       # Mostrar ayuda                    ║"
    echo "║                                                               ║"

    # Verificar LaunchAgent
    if launchctl list | grep -q "com.user.macmaintenance" 2>/dev/null; then
        echo "║ ✓ Ejecución Automática: ACTIVADA                             ║"
        printf "║   • Frecuencia:         Cada %d hora(s)                       ║\n" $INTERVAL_HOURS
        echo "║   • Método:             LaunchAgent (macOS daemon)            ║"
        echo "║   • Comando ejecutado:  mac-cleanup --force                   ║"
    else
        echo "║ ⊘ Ejecución Automática: NO CONFIGURADA                       ║"
        echo "║   • Ejecuta manualmente cuando lo necesites                   ║"
        echo "║   • Comando:            mac-cleanup                           ║"
    fi

    echo "║                                                               ║"
    echo "║ Archivos:                                                     ║"
    echo "║   Logs:                 $SCRIPT_DIR/logs/"
    echo "║   Config:               $SCRIPT_DIR/config/maintenance.conf"
    echo "║                                                               ║"
    echo "║ Desinstalar:            ./uninstall.sh                        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # Sugerencias
    echo "💡 Próximos pasos:"
    echo "   1. Prueba el comando: mac-cleanup --dry-run"
    echo "   2. Ejecuta interactivamente: mac-cleanup"
    echo "   3. Revisa los logs en: $SCRIPT_DIR/logs/maintenance.log"
    echo ""
}


# ============================================================================
# MAIN
# ============================================================================
main() {
    show_banner
    setup_directories
    make_executable
    install_command
    setup_launchagent
    show_summary

    echo "✅ Instalación finalizada exitosamente"
    echo ""
}

# Ejecutar main
main "$@"
