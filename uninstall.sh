#!/bin/bash
# uninstall.sh - Desinstalador de Mac Cleanup

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYMLINK_PATH="/usr/local/bin/mac-cleanup"
PLIST_DEST="$HOME/Library/LaunchAgents/com.user.macmaintenance.plist"

# Detectar modo force
FORCE_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# ============================================================================
# Mostrar banner
# ============================================================================
show_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║              Mac Cleanup - Desinstalador                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# Verificar qué está instalado
# ============================================================================
check_installation() {
    echo "🔍 Verificando instalación actual..."
    echo ""

    local has_command=false
    local has_launchagent=false

    # Verificar comando
    if [ -L "$SYMLINK_PATH" ]; then
        echo "  ✓ Comando encontrado: $SYMLINK_PATH"
        has_command=true
    else
        echo "  • Comando NO instalado"
    fi

    # Verificar LaunchAgent
    if [ -f "$PLIST_DEST" ]; then
        echo "  ✓ LaunchAgent encontrado: $PLIST_DEST"
        if launchctl list | grep -q "com.user.macmaintenance" 2>/dev/null; then
            echo "    (Estado: Cargado y activo)"
        else
            echo "    (Estado: No cargado)"
        fi
        has_launchagent=true
    else
        echo "  • LaunchAgent NO instalado"
    fi

    echo ""

    # Si no hay nada instalado
    if [ "$has_command" = false ] && [ "$has_launchagent" = false ]; then
        echo "ℹ️  No hay nada que desinstalar"
        echo ""
        return 1
    fi

    return 0
}

# ============================================================================
# Pedir confirmación
# ============================================================================
ask_confirmation() {
    echo "⚠️  Esta acción removerá:"
    echo ""

    if [ -L "$SYMLINK_PATH" ]; then
        echo "  • Comando mac-cleanup ($SYMLINK_PATH)"
    fi

    if [ -f "$PLIST_DEST" ]; then
        echo "  • LaunchAgent (ejecución automática)"
    fi

    echo ""
    echo "📝 NO se eliminarán:"
    echo "  • Logs ($SCRIPT_DIR/logs/)"
    echo "  • Configuración ($SCRIPT_DIR/config/)"
    echo ""

    # Si está en modo force, no pedir confirmación
    if [ "$FORCE_MODE" = true ]; then
        echo "ℹ️  Modo force: Procediendo automáticamente..."
        echo ""
        return 0
    fi

    read -p "¿Continuar con la desinstalación? (yes/no): " response

    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0  # Continuar
            ;;
        *)
            echo ""
            echo "Desinstalación cancelada"
            return 1  # Cancelar
            ;;
    esac
}

# ============================================================================
# Remover LaunchAgent
# ============================================================================
remove_launchagent() {
    if [ ! -f "$PLIST_DEST" ]; then
        return 0
    fi

    echo "🗑️  Removiendo LaunchAgent..."

    # Descargar si está cargado
    if launchctl list | grep -q "com.user.macmaintenance" 2>/dev/null; then
        echo "  Descargando agente..."
        launchctl unload "$PLIST_DEST" 2>/dev/null

        # Verificar que se descargó
        sleep 1
        if launchctl list | grep -q "com.user.macmaintenance" 2>/dev/null; then
            echo "  ⚠️  Advertencia: El agente aún aparece cargado"
            echo "     Intenta: launchctl unload $PLIST_DEST"
        else
            echo "  ✓ Agente descargado"
        fi
    fi

    # Remover archivo
    if rm "$PLIST_DEST" 2>/dev/null; then
        echo "  ✓ Archivo plist removido"
        return 0
    else
        echo "  ✗ Error al remover archivo plist"
        return 1
    fi
}

# ============================================================================
# Remover comando
# ============================================================================
remove_command() {
    if [ ! -L "$SYMLINK_PATH" ]; then
        return 0
    fi

    echo "🗑️  Removiendo comando mac-cleanup..."

    # Intentar sin sudo primero
    if rm "$SYMLINK_PATH" 2>/dev/null; then
        echo "  ✓ Comando removido"
        return 0
    else
        # Requiere sudo
        echo "  Se requieren permisos de administrador..."
        if sudo rm "$SYMLINK_PATH"; then
            echo "  ✓ Comando removido (con sudo)"
            return 0
        else
            echo "  ✗ Error al remover comando"
            return 1
        fi
    fi
}

# ============================================================================
# Verificar desinstalación
# ============================================================================
verify_uninstall() {
    echo ""
    echo "🔍 Verificando desinstalación..."
    echo ""

    local all_clean=true

    # Verificar comando
    if [ -L "$SYMLINK_PATH" ]; then
        echo "  ✗ El comando aún existe: $SYMLINK_PATH"
        all_clean=false
    else
        echo "  ✓ Comando removido"
    fi

    # Verificar LaunchAgent
    if [ -f "$PLIST_DEST" ]; then
        echo "  ✗ LaunchAgent aún existe: $PLIST_DEST"
        all_clean=false
    else
        echo "  ✓ LaunchAgent removido"
    fi

    if launchctl list | grep -q "com.user.macmaintenance" 2>/dev/null; then
        echo "  ⚠️  LaunchAgent aún aparece cargado"
        echo "     Puede necesitar reiniciar la sesión"
        all_clean=false
    fi

    echo ""

    if [ "$all_clean" = true ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Mostrar resumen final
# ============================================================================
show_summary() {
    local success=$1

    echo ""
    if [ "$success" = "0" ]; then
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║              DESINSTALACIÓN COMPLETADA EXITOSAMENTE           ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
    else
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║        DESINSTALACIÓN COMPLETADA CON ADVERTENCIAS             ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
    fi

    echo ""
    echo "📂 Archivos preservados:"
    echo "   • Logs: $SCRIPT_DIR/logs/"
    echo "   • Config: $SCRIPT_DIR/config/"
    echo ""

    if [ -d "$SCRIPT_DIR/logs" ]; then
        echo "💡 Para eliminar también los logs y configuración:"
        echo "   rm -rf $SCRIPT_DIR/logs/"
        echo "   rm -rf $SCRIPT_DIR/config/"
        echo ""
    fi

    echo "🔄 Para reinstalar en el futuro:"
    echo "   cd $SCRIPT_DIR"
    echo "   ./install.sh"
    echo ""
}

# ============================================================================
# Opción de limpieza completa
# ============================================================================
clean_all_data() {
    echo ""
    echo "🧹 Limpieza completa de datos"
    echo ""
    echo "⚠️  Esta acción eliminará PERMANENTEMENTE:"
    echo "  • Todos los logs ($SCRIPT_DIR/logs/)"
    echo "  • Toda la configuración ($SCRIPT_DIR/config/)"
    echo "  • Todos los reportes ($SCRIPT_DIR/reports/)"
    echo ""

    # Si está en modo force, proceder sin confirmación
    if [ "$FORCE_MODE" = true ]; then
        confirm="yes"
        echo "ℹ️  Modo force: Eliminando datos automáticamente..."
        echo ""
    else
        read -p "¿Estás seguro? Esta acción NO se puede deshacer (yes/no): " confirm
    fi

    case "$confirm" in
        [Yy]|[Yy][Ee][Ss])
            echo ""
            echo "🗑️  Eliminando datos..."

            local deleted_something=false

            if [ -d "$SCRIPT_DIR/logs" ]; then
                rm -rf "$SCRIPT_DIR/logs"
                echo "  ✓ Logs eliminados"
                deleted_something=true
            fi

            if [ -d "$SCRIPT_DIR/config" ]; then
                rm -rf "$SCRIPT_DIR/config"
                echo "  ✓ Configuración eliminada"
                deleted_something=true
            fi

            if [ -d "$SCRIPT_DIR/reports" ]; then
                rm -rf "$SCRIPT_DIR/reports"
                echo "  ✓ Reportes eliminados"
                deleted_something=true
            fi

            echo ""
            if [ "$deleted_something" = true ]; then
                echo "✓ Limpieza completa finalizada"
            else
                echo "• No había datos para eliminar"
            fi
            ;;
        *)
            echo ""
            echo "Limpieza completa cancelada"
            ;;
    esac
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    show_banner

    # Verificar qué está instalado
    if ! check_installation; then
        exit 0
    fi

    # Pedir confirmación
    if ! ask_confirmation; then
        echo ""
        exit 0
    fi

    echo ""
    echo "🚀 Iniciando desinstalación..."
    echo ""

    # Remover componentes
    remove_launchagent
    remove_command

    # Verificar resultado
    if verify_uninstall; then
        show_summary 0

        # Preguntar si desea limpieza completa
        echo ""
        if [ "$FORCE_MODE" = true ]; then
            # En modo force, eliminar automáticamente
            clean_all_data
        else
            read -p "¿Deseas también eliminar logs y configuración? (yes/no): " clean_data

            case "$clean_data" in
                [Yy]|[Yy][Ee][Ss])
                    clean_all_data
                    ;;
                *)
                    echo ""
                    echo "Datos preservados"
                    ;;
            esac
        fi
    else
        show_summary 1
    fi

    echo ""
    echo "✅ Proceso completado"
    echo ""
}

# Ejecutar
main "$@"
