#!/bin/bash
# safety-checks.sh - Validaciones de seguridad antes de ejecutar mantenimiento

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
# Verificar nivel de batería
# ============================================================================
check_battery() {
    local min_battery=${MIN_BATTERY_PERCENT:-20}

    # Obtener estado de batería
    local battery_info=$(pmset -g batt)

    # Verificar si está conectado a corriente
    if echo "$battery_info" | grep -q "AC Power"; then
        log_debug "Sistema conectado a corriente eléctrica"
        return 0  # OK - conectado a corriente
    fi

    # Obtener porcentaje de batería
    local battery_percent=$(echo "$battery_info" | grep -oE '[0-9]+%' | head -1 | tr -d '%')

    if [ -z "$battery_percent" ]; then
        log_warn "No se pudo determinar el nivel de batería"
        return 0  # Continuar de todos modos
    fi

    log_debug "Nivel de batería: ${battery_percent}%"

    if [ "$battery_percent" -lt "$min_battery" ]; then
        log_error "Batería muy baja: ${battery_percent}% (mínimo: ${min_battery}%)"
        log_error "Conecta el Mac a corriente eléctrica antes de ejecutar"
        return 1  # FAIL
    fi

    return 0  # OK
}

# ============================================================================
# Verificar carga del sistema
# ============================================================================
check_system_load() {
    if [ "${SKIP_ON_HIGH_LOAD:-true}" != "true" ]; then
        log_debug "Verificación de carga del sistema deshabilitada"
        return 0
    fi

    # Obtener número de CPUs
    local num_cpus=$(sysctl -n hw.ncpu)

    # Obtener load average de 5 minutos
    local load_avg=$(sysctl -n vm.loadavg | awk '{print $2}')

    # Convertir a entero para comparación
    local load_int=$(echo "$load_avg" | awk '{print int($1)}')

    log_debug "Carga del sistema: $load_avg (CPUs: $num_cpus)"

    # Si la carga es mayor que el número de CPUs, el sistema está muy ocupado
    if [ "$load_int" -gt "$num_cpus" ]; then
        log_warn "Carga del sistema muy alta: $load_avg (CPUs: $num_cpus)"
        log_warn "Se recomienda esperar a que el sistema esté menos ocupado"
        return 1  # FAIL
    fi

    return 0  # OK
}

# ============================================================================
# Verificar Time Machine
# ============================================================================
check_time_machine() {
    if [ "${CHECK_TIME_MACHINE:-true}" != "true" ]; then
        log_debug "Verificación de Time Machine deshabilitada"
        return 0
    fi

    # Verificar si tmutil está disponible
    if ! command -v tmutil &> /dev/null; then
        log_debug "Time Machine no disponible en este sistema"
        return 0
    fi

    # Verificar estado de Time Machine
    local tm_status=$(tmutil status 2>/dev/null)

    if echo "$tm_status" | grep -q "Running = 1"; then
        log_warn "Time Machine está ejecutando un backup"
        log_warn "Se recomienda esperar a que termine el backup"
        return 1  # FAIL
    fi

    log_debug "Time Machine no está ejecutando backup"
    return 0  # OK
}

# ============================================================================
# Verificar espacio en disco
# ============================================================================
check_disk_space() {
    local min_space_gb=${MIN_DISK_SPACE_GB:-5}

    # Obtener espacio disponible en el volumen raíz (en bloques de 512 bytes)
    local available_blocks=$(df / | tail -1 | awk '{print $4}')

    # Convertir a GB (bloques de 512 bytes a GB)
    local available_gb=$((available_blocks / 2 / 1024 / 1024))

    log_debug "Espacio disponible en disco: ${available_gb}GB"

    if [ "$available_gb" -lt "$min_space_gb" ]; then
        log_error "Espacio en disco insuficiente: ${available_gb}GB (mínimo: ${min_space_gb}GB)"
        log_error "Se necesita más espacio libre para ejecutar el mantenimiento de forma segura"
        return 1  # FAIL
    fi

    return 0  # OK
}

# ============================================================================
# Verificar quiet hours
# ============================================================================
check_quiet_hours() {
    local quiet_start=${QUIET_HOURS_START:-22}
    local quiet_end=${QUIET_HOURS_END:-7}
    local current_hour=$(date +%H | sed 's/^0//')  # Eliminar cero inicial

    log_debug "Hora actual: ${current_hour}h (quiet hours: ${quiet_start}h - ${quiet_end}h)"

    # Si no estamos en modo force, no importan las quiet hours
    if [ "${FORCE_MODE:-false}" != "true" ]; then
        return 0
    fi

    # Verificar si estamos en quiet hours
    if [ "$quiet_start" -gt "$quiet_end" ]; then
        # Caso: 22:00 - 07:00 (cruza medianoche)
        if [ "$current_hour" -ge "$quiet_start" ] || [ "$current_hour" -lt "$quiet_end" ]; then
            log_info "Dentro de quiet hours ($quiet_start:00 - $quiet_end:00)"
            log_info "Omitiendo ejecución automática"
            return 1  # FAIL
        fi
    else
        # Caso: 01:00 - 06:00 (no cruza medianoche)
        if [ "$current_hour" -ge "$quiet_start" ] && [ "$current_hour" -lt "$quiet_end" ]; then
            log_info "Dentro de quiet hours ($quiet_start:00 - $quiet_end:00)"
            log_info "Omitiendo ejecución automática"
            return 1  # FAIL
        fi
    fi

    return 0  # OK
}

# ============================================================================
# Verificar permisos
# ============================================================================
check_permissions() {
    # Verificar si /usr/local/bin es escribible (necesario para symlink)
    if [ ! -w "/usr/local/bin" ]; then
        log_warn "/usr/local/bin no es escribible"
        log_warn "Puede que necesites permisos de administrador para algunas operaciones"
    fi

    # Verificar si sudo está disponible para purge
    if [ "${ENABLE_PURGE:-true}" = "true" ]; then
        if ! command -v sudo &> /dev/null; then
            log_warn "sudo no disponible - el comando 'purge' no podrá ejecutarse"
        fi
    fi

    return 0  # Siempre continuar
}

# ============================================================================
# Ejecutar todas las verificaciones de seguridad
# ============================================================================
run_safety_checks() {
    log_info "Ejecutando verificaciones de seguridad..."

    local checks_failed=0

    # Ejecutar cada verificación
    check_permissions || ((checks_failed++))
    check_battery || ((checks_failed++))
    check_disk_space || ((checks_failed++))
    check_time_machine || ((checks_failed++))
    check_system_load || ((checks_failed++))
    check_quiet_hours || ((checks_failed++))

    if [ $checks_failed -gt 0 ]; then
        log_error "Algunas verificaciones de seguridad fallaron ($checks_failed)"
        log_error "No es seguro continuar con el mantenimiento"
        return 1  # FAIL
    fi

    log_info "✓ Todas las verificaciones de seguridad pasaron"
    return 0  # OK
}
