#!/bin/bash
# mac-maintenance.sh - Script principal de mantenimiento de macOS
# Orquesta limpieza de memoria, gestión de procesos y reportes

# ============================================================================
# CONFIGURACIÓN
# ============================================================================
# Resolver el directorio real del script (siguiendo symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/maintenance.conf"

# Variables globales
export FORCE_MODE=false
export DRY_RUN=false
export AGGRESSIVE=false

# ============================================================================
# Cargar configuración
# ============================================================================
load_configuration() {
    if [ -f "$CONFIG_FILE" ]; then
        # Source del archivo de configuración
        source "$CONFIG_FILE"
    else
        echo "⚠️  Archivo de configuración no encontrado: $CONFIG_FILE"
        echo "   Usando valores por defecto..."
    fi
}

# ============================================================================
# Source de módulos
# ============================================================================
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/progress-bar.sh"
source "$SCRIPT_DIR/lib/safety-checks.sh"
source "$SCRIPT_DIR/lib/memory-manager.sh"
source "$SCRIPT_DIR/lib/process-monitor.sh"
source "$SCRIPT_DIR/lib/summary-table.sh"

# ============================================================================
# Parsear argumentos
# ============================================================================
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                export FORCE_MODE=true
                shift
                ;;
            --dry-run)
                export DRY_RUN=true
                shift
                ;;
            --aggressive)
                export AGGRESSIVE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "❌ Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Verificar permisos de administrador
# ============================================================================
check_admin_permissions() {
    # Verificar si el usuario está en el grupo admin
    if ! groups | grep -q '\badmin\b'; then
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════════════╗"
        echo "║                    ⚠️  PERMISOS INSUFICIENTES                         ║"
        echo "╠═══════════════════════════════════════════════════════════════════════╣"
        echo "║                                                                       ║"
        echo "║  Este script requiere permisos de ADMINISTRADOR para funcionar.      ║"
        echo "║                                                                       ║"
        echo "║  Razones:                                                             ║"
        echo "║    • El comando 'purge' requiere permisos elevados                    ║"
        echo "║    • Limpieza de caches del sistema necesita acceso root             ║"
        echo "║    • Gestión de procesos requiere permisos administrativos           ║"
        echo "║                                                                       ║"
        echo "║  ⛔ SOLO ADMINISTRADORES PUEDEN EJECUTAR LIMPIEZA DEL SISTEMA        ║"
        echo "║                                                                       ║"
        echo "╠═══════════════════════════════════════════════════════════════════════╣"
        echo "║  Soluciones:                                                          ║"
        echo "║                                                                       ║"
        echo "║  1. Contacta al administrador del sistema                             ║"
        echo "║  2. Si eres el dueño de este Mac, agrega tu usuario al grupo admin:  ║"
        echo "║                                                                       ║"
        echo "║     sudo dseditgroup -o edit -a $(whoami) -t user admin              ║"
        echo "║                                                                       ║"
        echo "╚═══════════════════════════════════════════════════════════════════════╝"
        echo ""
        log_error "Usuario $(whoami) no tiene permisos de administrador"
        exit 1
    fi

    # Verificar que sudo está disponible
    if ! command -v sudo &> /dev/null; then
        echo ""
        echo "❌ ERROR: El comando 'sudo' no está disponible en este sistema"
        echo ""
        log_error "sudo no disponible"
        exit 1
    fi

    log_debug "Verificación de permisos de administrador: OK (usuario en grupo admin)"
}

# ============================================================================
# Mostrar ayuda
# ============================================================================
show_help() {
    cat << EOF
Mac Cleanup - Sistema de Mantenimiento de macOS

Uso: mac-cleanup [OPCIONES]

OPCIONES:
    -f, --force        Ejecutar sin confirmación (usado por LaunchAgent)
    --dry-run          Mostrar qué se haría sin ejecutar nada
    --aggressive       Limpieza más profunda
    -h, --help         Mostrar esta ayuda

EJEMPLOS:
    mac-cleanup                    # Modo interactivo (muestra tabla, pregunta)
    mac-cleanup --force            # Sin confirmación
    mac-cleanup --dry-run          # Solo simular
    mac-cleanup --aggressive       # Limpieza profunda

ARCHIVOS:
    Config:   $CONFIG_FILE
    Logs:     $SCRIPT_DIR/logs/maintenance.log
    Métricas: $SCRIPT_DIR/logs/metrics.log

Para más información, consulta el README.md
EOF
}

# ============================================================================
# Ejecutar limpieza con barra de progreso
# ============================================================================
execute_cleanup() {
    log_info "=== INICIANDO LIMPIEZA ==="

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                    EJECUTANDO LIMPIEZA DEL SISTEMA                    ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"

    # Activar modo silencioso (suprimir logs en consola)
    export SUPPRESS_CONSOLE_OUTPUT=true

    # Calcular total de pasos
    local total_steps=5
    init_progress $total_steps

    # Paso 1: Análisis inicial
    update_progress_bar "Analizando estado del sistema"
    get_memory_stats
    sleep 0.5
    complete_step "Análisis del sistema completado" "done"

    # Paso 2: Ejecutar purge
    if [ "${ENABLE_PURGE:-true}" = "true" ]; then
        update_progress_bar "Liberando memoria inactiva"
        # Limpiar barra antes de pedir password
        clear_progress_bar
        # Ejecutar purge (puede pedir password)
        if run_purge; then
            complete_step "Memoria inactiva liberada (${PURGE_FREED_GB:-0}GB)" "done"
        else
            complete_step "Purge omitido o falló" "skip"
        fi
    else
        complete_step "Purge deshabilitado en configuración" "skip"
    fi

    # Paso 3: Limpiar caches
    update_progress_bar "Limpiando caches de usuario"
    clean_user_caches
    complete_step "Caches limpiados (${CACHE_FREED_MB:-0}MB)" "done"

    # Paso 4: Flush DNS
    update_progress_bar "Limpiando cache DNS"
    flush_dns_cache
    sleep 0.3
    complete_step "Cache DNS limpiado" "done"

    # Paso 5: Gestionar procesos
    update_progress_bar "Gestionando procesos problemáticos"
    manage_problem_processes
    sleep 0.3
    complete_step "Procesos gestionados" "done"

    # Finalizar barra
    finish_progress

    # Desactivar modo silencioso
    export SUPPRESS_CONSOLE_OUTPUT=false

    log_info "=== LIMPIEZA COMPLETADA ==="
}

# ============================================================================
# Mostrar reporte de resultados
# ============================================================================
show_results_report() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║                        REPORTE DE RESULTADOS                          ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"

    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "║ MODO DRY-RUN - No se ejecutaron acciones reales                      ║"
        echo "╠═══════════════════════════════════════════════════════════════════════╣"
    fi

    # Memoria
    local freed_gb=${TOTAL_FREED_GB:-0}
    if [ $freed_gb -gt 0 ]; then
        printf "║ ✓ Memoria liberada:       %d GB                                        ║\n" $freed_gb
    else
        echo "║ • Memoria optimizada (sin cambio significativo)                       ║"
    fi

    # Caches
    local cache_mb=${CACHE_FREED_MB:-0}
    if [ $cache_mb -gt 0 ]; then
        printf "║ ✓ Caches limpiados:       %d MB                                        ║\n" $cache_mb
    fi

    # Procesos
    if [ ${PROBLEM_PROCESSES_COUNT:-0} -gt 0 ]; then
        printf "║ • Procesos detectados:    %d                                          ║\n" $PROBLEM_PROCESSES_COUNT

        if [ "${AUTO_KILL_ENABLED:-false}" = "true" ]; then
            echo "║ ✓ Procesos terminados automáticamente                                ║"
        else
            echo "║ • Procesos solo notificados (AUTO_KILL deshabilitado)                ║"
        fi
    else
        echo "║ ✓ No se detectaron procesos problemáticos                             ║"
    fi

    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║ Estado Final de Memoria:                                              ║"
    printf "║   • Memoria Libre:        %d GB (%d%%)                                  ║\n" ${MEM_FREE_GB:-0} ${MEM_FREE_PERCENT:-0}
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# Enviar notificación de macOS
# ============================================================================
send_notification() {
    local title=$1
    local message=$2

    # Solo enviar si está habilitado
    if [ "${NOTIFY_ON_COMPLETE:-true}" = "true" ]; then
        osascript -e "display notification \"$message\" with title \"Mac Cleanup\" subtitle \"$title\"" 2>/dev/null
    fi
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    local start_time=$(date +%s)

    # Cargar configuración
    load_configuration

    # Configurar nivel de log
    set_log_level "${LOG_LEVEL:-info}"

    # Parsear argumentos
    parse_arguments "$@"

    # Determinar modo de ejecución
    local mode="interactive"
    if [ "$FORCE_MODE" = "true" ]; then
        mode="force"
    elif [ "$DRY_RUN" = "true" ]; then
        mode="dry-run"
    fi

    # Iniciar sesión de log
    log_session_start "$mode"

    # Mostrar banner (solo en modo interactivo)
    if [ "$FORCE_MODE" != "true" ]; then
        echo ""
        echo "╔═══════════════════════════════════════════════════════════════════════╗"
        echo "║                Mac Cleanup - Sistema de Mantenimiento                 ║"
        echo "╚═══════════════════════════════════════════════════════════════════════╝"
        echo ""
    fi

    # VERIFICAR PERMISOS DE ADMINISTRADOR (CRÍTICO)
    check_admin_permissions

    # Ejecutar safety checks
    if ! run_safety_checks; then
        log_error "Verificaciones de seguridad fallaron - abortando"
        send_notification "Limpieza Abortada" "Las verificaciones de seguridad no pasaron"
        exit 1
    fi

    # Modo force: ejecutar sin preguntar
    if [ "$FORCE_MODE" = "true" ]; then
        log_info "Modo FORCE - ejecutando sin confirmación"
        execute_cleanup
        show_results_report

    # Modo interactivo: mostrar tabla y preguntar
    else
        if show_summary_and_confirm; then
            execute_cleanup
            show_results_report
        else
            log_info "Operación cancelada por el usuario o dry-run"
            exit 0
        fi
    fi

    # Calcular duración
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Finalizar sesión de log
    log_session_end $duration

    # Rotar logs si es necesario
    rotate_logs

    # Enviar notificación de éxito
    local freed_gb=${TOTAL_FREED_GB:-0}
    if [ $freed_gb -gt 0 ]; then
        send_notification "Limpieza Completada" "Liberados ${freed_gb}GB de memoria en ${duration}s"
    else
        send_notification "Mantenimiento Completado" "Sistema optimizado en ${duration}s"
    fi

    exit 0
}

# Ejecutar main con todos los argumentos
main "$@"
