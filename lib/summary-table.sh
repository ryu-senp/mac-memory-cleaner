#!/bin/bash
# summary-table.sh - Generador de tabla de resumen pre-limpieza

# Obtener directorio del script (resolver symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$SCRIPT_DIR/lib/logger.sh"
source "$SCRIPT_DIR/lib/memory-manager.sh"
source "$SCRIPT_DIR/lib/process-monitor.sh"

# ============================================================================
# Generar tabla de resumen
# ============================================================================
generate_summary_table() {
    # Analizar estado actual
    analyze_memory
    analyze_processes

    # Dibujar tabla
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║              RESUMEN DE LIMPIEZA - Mac Maintenance                    ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║ MEMORIA                                                               ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║ Estado Actual:                                                        ║"
    printf "║   • Total RAM:           %4d GB                                      ║\n" $MEM_TOTAL_GB
    printf "║   • Memoria Libre:       %4d GB (%3d%%)                              ║\n" $MEM_FREE_GB $MEM_FREE_PERCENT
    printf "║   • Memoria Inactiva:    %4d GB                                      ║\n" $MEM_INACTIVE_GB

    # Obtener swap si está disponible
    local swap_used=$(sysctl -n vm.swapusage 2>/dev/null | awk '{print $7}' | tr -d 'M')
    if [ -n "$swap_used" ]; then
        local swap_gb=$(echo "scale=1; $swap_used / 1024" | bc 2>/dev/null || echo "0")
        printf "║   • Swap Usado:          %4s GB                                      ║\n" "$swap_gb"
    fi

    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║ Acciones a Realizar:                                                  ║"

    # Listar acciones
    if [ "${MEMORY_CLEANUP_NEEDED:-false}" = "true" ] || [ "${FORCE_MODE:-false}" = "true" ]; then
        if [ "${ENABLE_PURGE:-true}" = "true" ]; then
            printf "║   ✓ Ejecutar purge (liberar ~%d GB de memoria inactiva)            ║\n" $ESTIMATED_FREED_GB
        fi
        if [ ${ESTIMATED_CACHE_MB:-0} -gt 0 ]; then
            printf "║   ✓ Limpiar user caches (estimado %d MB)                            ║\n" $ESTIMATED_CACHE_MB
        else
            echo "║   ✓ Limpiar user caches                                               ║"
        fi
        echo "║   ✓ Flush DNS cache                                                   ║"
    else
        echo "║   ⊘ Memoria suficiente - limpieza opcional                            ║"
        if [ "${ENABLE_PURGE:-true}" = "true" ]; then
            echo "║   • Purge disponible si deseas ejecutar de todos modos               ║"
        fi
    fi

    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║ PROCESOS PROBLEMÁTICOS                                                ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"

    if [ $PROBLEM_PROCESSES_COUNT -eq 0 ]; then
        echo "║ No se detectaron procesos problemáticos                               ║"
    else
        printf "║ %-6s %-20s %-7s %-10s %-10s ║\n" "PID" "Nombre" "CPU%" "Memoria" "Acción"

        # Mostrar cada proceso
        while IFS='|' read -r pid name cpu mem action; do
            # Truncar nombre si es muy largo
            if [ ${#name} -gt 20 ]; then
                name="${name:0:17}..."
            fi

            # Formatear acción
            local action_text="Notificar"
            if [ "$action" = "kill" ]; then
                action_text="Terminar"
            fi

            printf "║ %-6s %-20s %-7s %-10s %-10s ║\n" "$pid" "$name" "$cpu" "$mem" "$action_text"
        done < <(get_problem_processes_data)
    fi

    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║ ESTIMADO                                                              ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"

    # Calcular estimado total
    local total_estimated_gb=$ESTIMATED_FREED_GB
    local cache_gb=$(echo "scale=1; ${ESTIMATED_CACHE_MB:-0} / 1024" | bc 2>/dev/null || echo "0")
    total_estimated_gb=$(echo "$total_estimated_gb + $cache_gb" | bc 2>/dev/null || echo "$total_estimated_gb")

    if [ "${MEMORY_CLEANUP_NEEDED:-false}" = "true" ] || [ "${FORCE_MODE:-false}" = "true" ]; then
        printf "║ Memoria a liberar:        ~%.1f GB                                     ║\n" $total_estimated_gb
    else
        echo "║ Memoria a liberar:        No necesario actualmente                    ║"
    fi

    printf "║ Procesos a notificar:     %d                                          ║\n" $PROBLEM_PROCESSES_COUNT
    echo "║ Duración estimada:        15-30 segundos                              ║"
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================================================
# Mostrar tabla y preguntar confirmación
# ============================================================================
show_summary_and_confirm() {
    # Generar tabla
    generate_summary_table

    # Si es dry-run, no preguntar
    if [ "${DRY_RUN:-false}" = "true" ]; then
        echo "Modo DRY-RUN: No se ejecutará ninguna acción"
        return 1  # No continuar
    fi

    # Preguntar confirmación
    echo -n "¿Proceder con la limpieza? (yes/no): "
    read -r response

    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            echo ""
            log_info "Usuario confirmó - procediendo con limpieza"
            return 0  # Continuar
            ;;
        *)
            echo ""
            log_info "Usuario canceló la operación"
            return 1  # No continuar
            ;;
    esac
}
