#!/bin/bash
# memory-manager.sh - Análisis y limpieza de memoria RAM

# Obtener directorio del script (resolver symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$SCRIPT_DIR/lib/logger.sh"

# ============================================================================
# Obtener estadísticas de memoria
# ============================================================================
get_memory_stats() {
    local vm_stat_output=$(vm_stat)
    local page_size=$(sysctl -n hw.pagesize)
    local total_mem=$(sysctl -n hw.memsize)

    # Parsear vm_stat
    local pages_free=$(echo "$vm_stat_output" | awk '/Pages free/ {gsub(/\./, "", $3); print $3}')
    local pages_active=$(echo "$vm_stat_output" | awk '/Pages active/ {gsub(/\./, "", $3); print $3}')
    local pages_inactive=$(echo "$vm_stat_output" | awk '/Pages inactive/ {gsub(/\./, "", $3); print $3}')
    local pages_speculative=$(echo "$vm_stat_output" | awk '/Pages speculative/ {gsub(/\./, "", $3); print $3}')
    local pages_wired=$(echo "$vm_stat_output" | awk '/Pages wired down/ {gsub(/\./, "", $4); print $4}')

    # Convertir a bytes
    local free_bytes=$((pages_free * page_size))
    local active_bytes=$((pages_active * page_size))
    local inactive_bytes=$((pages_inactive * page_size))
    local wired_bytes=$((pages_wired * page_size))

    # Convertir a GB
    local total_gb=$((total_mem / 1024 / 1024 / 1024))
    local free_gb=$((free_bytes / 1024 / 1024 / 1024))
    local inactive_gb=$((inactive_bytes / 1024 / 1024 / 1024))
    local used_gb=$((total_gb - free_gb))

    # Calcular porcentajes
    local free_percent=$((free_gb * 100 / total_gb))

    # Exportar variables para uso externo
    export MEM_TOTAL_GB=$total_gb
    export MEM_FREE_GB=$free_gb
    export MEM_USED_GB=$used_gb
    export MEM_INACTIVE_GB=$inactive_gb
    export MEM_FREE_PERCENT=$free_percent

    log_debug "Memoria - Total: ${total_gb}GB, Libre: ${free_gb}GB (${free_percent}%), Inactiva: ${inactive_gb}GB"
}

# ============================================================================
# Verificar presión de memoria
# ============================================================================
check_memory_pressure() {
    get_memory_stats

    local min_free_gb=${MIN_FREE_MEMORY_GB:-2}

    if [ $MEM_FREE_GB -lt $min_free_gb ]; then
        log_info "Memoria libre baja: ${MEM_FREE_GB}GB (mínimo: ${min_free_gb}GB)"
        return 0  # Necesita limpieza
    fi

    log_debug "Memoria libre suficiente: ${MEM_FREE_GB}GB"
    return 1  # NO necesita limpieza
}

# ============================================================================
# Ejecutar purge
# ============================================================================
run_purge() {
    if [ "${ENABLE_PURGE:-true}" != "true" ]; then
        log_info "Comando purge deshabilitado en configuración"
        return 1
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Se ejecutaría: sudo purge"
        export PURGE_FREED_GB=$MEM_INACTIVE_GB
        return 0
    fi

    log_info "Ejecutando purge para liberar memoria inactiva..."

    # Capturar memoria antes
    get_memory_stats
    local mem_before=$MEM_FREE_GB

    # Ejecutar purge
    if sudo -n purge 2>/dev/null; then
        log_info "✓ Purge ejecutado con sudo existente"
    else
        # Pedir sudo si no está cacheado
        log_info "Se requiere contraseña de administrador para ejecutar 'purge'"
        if sudo purge; then
            log_info "✓ Purge ejecutado exitosamente"
        else
            log_error "Falló la ejecución de purge"
            return 1
        fi
    fi

    # Esperar un momento para que se estabilice
    sleep 2

    # Capturar memoria después
    get_memory_stats
    local mem_after=$MEM_FREE_GB

    local freed_gb=$((mem_after - mem_before))
    export PURGE_FREED_GB=$freed_gb

    if [ $freed_gb -gt 0 ]; then
        log_info "✓ Purge liberó aproximadamente ${freed_gb}GB de memoria"
        log_metric "purge_freed_gb,$freed_gb"
    else
        log_info "Purge ejecutado (sin cambio significativo en memoria libre)"
    fi

    return 0
}

# ============================================================================
# Limpiar caches de usuario
# ============================================================================
clean_user_caches() {
    local cache_dir="$HOME/Library/Caches"
    local age_days=${CACHE_AGE_DAYS:-30}

    if [ ! -d "$cache_dir" ]; then
        log_warn "Directorio de caches no encontrado: $cache_dir"
        return 1
    fi

    log_info "Limpiando caches de usuario (más antiguos que $age_days días)..."

    if [ "${DRY_RUN:-false}" = "true" ]; then
        local files_count=$(find "$cache_dir" -type f -atime +$age_days 2>/dev/null | wc -l | tr -d ' ')
        log_info "[DRY-RUN] Se eliminarían aproximadamente $files_count archivos de cache"
        export CACHE_FREED_MB=500  # Estimación
        return 0
    fi

    # Calcular tamaño antes
    local size_before=$(du -sk "$cache_dir" 2>/dev/null | cut -f1)

    # Eliminar archivos antiguos usando find con -delete (más eficiente)
    # Excluir directorios protegidos
    local deleted_count=0

    # Contar archivos primero (con límite para no tardar mucho)
    local total_files=$(find "$cache_dir" -type f -atime +$age_days \
        ! -path "*/com.apple.appstore/*" \
        ! -path "*/com.apple.Safari/*" \
        2>/dev/null | head -10000 | wc -l | tr -d ' ')

    if [ $total_files -eq 0 ]; then
        log_info "No se encontraron caches antiguos para eliminar"
        export CACHE_FREED_MB=0
        return 0
    fi

    log_debug "Eliminando aproximadamente $total_files archivos de cache..."

    # Eliminar archivos (método eficiente)
    deleted_count=$(find "$cache_dir" -type f -atime +$age_days \
        ! -path "*/com.apple.appstore/*" \
        ! -path "*/com.apple.Safari/*" \
        -delete -print 2>/dev/null | wc -l | tr -d ' ')

    # Calcular tamaño después
    local size_after=$(du -sk "$cache_dir" 2>/dev/null | cut -f1)
    local freed_kb=$((size_before - size_after))
    local freed_mb=$((freed_kb / 1024))

    export CACHE_FREED_MB=$freed_mb

    if [ $freed_mb -gt 0 ]; then
        log_info "✓ Liberados ${freed_mb}MB de caches ($deleted_count archivos)"
        log_metric "cache_freed_mb,$freed_mb"
    else
        log_info "Caches procesados (sin liberación significativa de espacio)"
    fi

    return 0
}

# ============================================================================
# Limpiar cache DNS
# ============================================================================
flush_dns_cache() {
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Se limpiaría el cache DNS"
        return 0
    fi

    log_info "Limpiando cache DNS..."

    # Limpiar cache DNS
    if sudo -n dscacheutil -flushcache 2>/dev/null; then
        sudo -n killall -HUP mDNSResponder 2>/dev/null
        log_info "✓ Cache DNS limpiado"
        log_metric "dns_cache_flushed,1"
    else
        # Intentar sin sudo
        dscacheutil -flushcache 2>/dev/null
        killall -HUP mDNSResponder 2>/dev/null
        log_info "✓ Cache DNS limpiado (sin sudo)"
    fi

    return 0
}

# ============================================================================
# Ejecutar limpieza completa de memoria
# ============================================================================
execute_memory_cleanup() {
    log_info "=== Iniciando limpieza de memoria ==="

    # Capturar estado inicial
    get_memory_stats
    local initial_free=$MEM_FREE_GB

    log_metric "memory_before_free_gb,$initial_free"
    log_metric "memory_before_used_gb,$MEM_USED_GB"

    local total_freed_mb=0

    # 1. Purge
    if run_purge; then
        local purge_freed=${PURGE_FREED_GB:-0}
        total_freed_mb=$((total_freed_mb + purge_freed * 1024))
    fi

    # 2. Limpiar caches de usuario
    if clean_user_caches; then
        local cache_freed=${CACHE_FREED_MB:-0}
        total_freed_mb=$((total_freed_mb + cache_freed))
    fi

    # 3. Flush DNS
    flush_dns_cache

    # Capturar estado final
    get_memory_stats
    local final_free=$MEM_FREE_GB

    log_metric "memory_after_free_gb,$final_free"
    log_metric "memory_after_used_gb,$MEM_USED_GB"

    # Calcular total liberado
    local actual_freed_gb=$((final_free - initial_free))

    export TOTAL_FREED_GB=$actual_freed_gb

    log_info "=== Limpieza de memoria completada ==="
    log_info "Memoria inicial: ${initial_free}GB → Memoria final: ${final_free}GB"

    if [ $actual_freed_gb -gt 0 ]; then
        log_info "✓ Total liberado: ${actual_freed_gb}GB"
    else
        log_info "Memoria optimizada (sin cambio significativo en GB libres)"
    fi

    return 0
}

# ============================================================================
# Análisis de memoria (para tabla de resumen)
# ============================================================================
analyze_memory() {
    get_memory_stats

    # Calcular estimación de lo que se puede liberar
    local estimated_freed_gb=$MEM_INACTIVE_GB

    # Estimar limpieza de caches (aproximado y rápido)
    if [ -d "$HOME/Library/Caches" ]; then
        # Contar solo archivos (limitar a 5000 para velocidad) y estimar tamaño promedio
        local file_count=$(find "$HOME/Library/Caches" -type f -atime +${CACHE_AGE_DAYS:-30} 2>/dev/null | head -5000 | wc -l | tr -d ' ')

        if [ $file_count -gt 0 ]; then
            # Estimar 100KB promedio por archivo de cache antiguo
            local estimated_kb=$((file_count * 100))
            local cache_size_mb=$((estimated_kb / 1024))
            export ESTIMATED_CACHE_MB=$cache_size_mb
        else
            export ESTIMATED_CACHE_MB=0
        fi
    else
        export ESTIMATED_CACHE_MB=0
    fi

    export ESTIMATED_FREED_GB=$estimated_freed_gb

    # Determinar si se necesita limpieza
    if check_memory_pressure; then
        export MEMORY_CLEANUP_NEEDED=true
    else
        export MEMORY_CLEANUP_NEEDED=false
    fi
}
