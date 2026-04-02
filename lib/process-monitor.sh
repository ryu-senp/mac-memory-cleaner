#!/bin/bash
# process-monitor.sh - Detección y gestión de procesos problemáticos

# Obtener directorio del script (resolver symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
source "$SCRIPT_DIR/lib/logger.sh"

# Archivo de blacklist
BLACKLIST_FILE="$SCRIPT_DIR/config/process-blacklist.conf"

# Array global para procesos detectados
declare -a PROBLEM_PROCESSES_PIDS=()
declare -a PROBLEM_PROCESSES_NAMES=()
declare -a PROBLEM_PROCESSES_CPU=()
declare -a PROBLEM_PROCESSES_MEM=()
declare -a PROBLEM_PROCESSES_ACTIONS=()

# ============================================================================
# Cargar blacklist de procesos
# ============================================================================
load_process_blacklist() {
    if [ ! -f "$BLACKLIST_FILE" ]; then
        log_warn "Archivo de blacklist no encontrado: $BLACKLIST_FILE"
        return 1
    fi

    # Cargar procesos protegidos (ignorar líneas vacías y comentarios)
    export BLACKLISTED_PROCESSES=$(grep -v '^#' "$BLACKLIST_FILE" | grep -v '^[[:space:]]*$' | tr '\n' '|' | sed 's/|$//')

    log_debug "Procesos en blacklist cargados"
}

# ============================================================================
# Verificar si un proceso está en la blacklist
# ============================================================================
is_blacklisted() {
    local process_name=$1

    # Verificar si está en la lista
    if echo "$process_name" | grep -qE "$BLACKLISTED_PROCESSES"; then
        return 0  # Sí está en blacklist
    fi

    return 1  # No está en blacklist
}

# ============================================================================
# Verificar si un proceso pertenece a root
# ============================================================================
is_root_process() {
    local pid=$1
    local owner=$(ps -p $pid -o user= 2>/dev/null | tr -d ' ')

    if [ "$owner" = "root" ] || [ "$owner" = "_windowserver" ]; then
        return 0  # Sí es proceso de root/sistema
    fi

    return 1  # No es proceso de root
}

# ============================================================================
# Verificar si un proceso es seguro para terminar
# ============================================================================
is_safe_to_kill() {
    local pid=$1
    local process_name=$2

    # 1. Verificar blacklist
    if is_blacklisted "$process_name"; then
        log_debug "Proceso protegido por blacklist: $process_name"
        return 1  # NO es seguro
    fi

    # 2. Verificar si es proceso de root
    if is_root_process $pid; then
        log_debug "Proceso pertenece a root: $process_name (PID: $pid)"
        return 1  # NO es seguro
    fi

    # 3. Verificar si es el proceso actual
    if [ $pid -eq $$ ]; then
        log_debug "Es el proceso actual"
        return 1  # NO es seguro
    fi

    return 0  # SÍ es seguro
}

# ============================================================================
# Detectar procesos con alto uso de CPU
# ============================================================================
detect_high_cpu_processes() {
    local cpu_threshold=${CPU_THRESHOLD_PERCENT:-80}

    log_debug "Buscando procesos con CPU > ${cpu_threshold}%..."

    # Usar ps para obtener procesos ordenados por CPU
    while read -r pid cpu command; do
        # Convertir CPU a entero (eliminar punto decimal)
        local cpu_int=$(echo "$cpu" | awk '{print int($1)}')

        if [ $cpu_int -gt $cpu_threshold ]; then
            # Extraer nombre del proceso
            local process_name=$(echo "$command" | awk '{print $1}' | xargs basename)

            # Verificar si es seguro
            if is_safe_to_kill $pid "$process_name"; then
                log_debug "Proceso con alto CPU detectado: $process_name (PID: $pid, CPU: ${cpu}%)"

                # Agregar a lista de procesos problemáticos
                PROBLEM_PROCESSES_PIDS+=($pid)
                PROBLEM_PROCESSES_NAMES+=("$process_name")
                PROBLEM_PROCESSES_CPU+=("${cpu}%")
                PROBLEM_PROCESSES_MEM+=("N/A")
                PROBLEM_PROCESSES_ACTIONS+=("notify")
            fi
        fi
    done < <(ps aux | sort -nrk 3 | head -20 | awk 'NR>1 {print $2, $3, $11}')
}

# ============================================================================
# Detectar procesos con alto uso de memoria
# ============================================================================
detect_high_memory_processes() {
    local mem_threshold_gb=${MEMORY_THRESHOLD_GB:-2}
    local mem_threshold_bytes=$((mem_threshold_gb * 1024 * 1024 * 1024))

    # Obtener memoria total
    local total_mem=$(sysctl -n hw.memsize)
    local mem_threshold_percent=${MEMORY_THRESHOLD_PERCENT:-25}
    local mem_threshold_by_percent=$((total_mem * mem_threshold_percent / 100))

    log_debug "Buscando procesos con memoria > ${mem_threshold_gb}GB o >${mem_threshold_percent}%..."

    # Usar ps para obtener procesos ordenados por memoria
    while read -r pid rss command; do
        # RSS está en KB, convertir a bytes
        local rss_bytes=$((rss * 1024))
        local rss_gb=$(echo "scale=1; $rss / 1024 / 1024" | bc)

        # Verificar umbrales
        if [ $rss_bytes -gt $mem_threshold_bytes ] || [ $rss_bytes -gt $mem_threshold_by_percent ]; then
            # Extraer nombre del proceso
            local process_name=$(echo "$command" | awk '{print $1}' | xargs basename)

            # Verificar si es seguro
            if is_safe_to_kill $pid "$process_name"; then
                # Verificar si ya no está en la lista (evitar duplicados)
                local already_added=false
                for existing_pid in "${PROBLEM_PROCESSES_PIDS[@]}"; do
                    if [ "$existing_pid" = "$pid" ]; then
                        already_added=true
                        break
                    fi
                done

                if [ "$already_added" = false ]; then
                    log_debug "Proceso con alta memoria detectado: $process_name (PID: $pid, MEM: ${rss_gb}GB)"

                    PROBLEM_PROCESSES_PIDS+=($pid)
                    PROBLEM_PROCESSES_NAMES+=("$process_name")
                    PROBLEM_PROCESSES_CPU+=("N/A")
                    PROBLEM_PROCESSES_MEM+=("${rss_gb}GB")
                    PROBLEM_PROCESSES_ACTIONS+=("notify")
                else
                    # Actualizar memoria para proceso ya detectado
                    for i in "${!PROBLEM_PROCESSES_PIDS[@]}"; do
                        if [ "${PROBLEM_PROCESSES_PIDS[$i]}" = "$pid" ]; then
                            PROBLEM_PROCESSES_MEM[$i]="${rss_gb}GB"
                            break
                        fi
                    done
                fi
            fi
        fi
    done < <(ps aux | sort -nrk 6 | head -20 | awk 'NR>1 {print $2, $6, $11}')
}

# ============================================================================
# Analizar procesos (para tabla de resumen)
# ============================================================================
analyze_processes() {
    log_debug "Analizando procesos..."

    # Cargar blacklist
    load_process_blacklist

    # Limpiar arrays
    PROBLEM_PROCESSES_PIDS=()
    PROBLEM_PROCESSES_NAMES=()
    PROBLEM_PROCESSES_CPU=()
    PROBLEM_PROCESSES_MEM=()
    PROBLEM_PROCESSES_ACTIONS=()

    # Detectar procesos problemáticos
    detect_high_cpu_processes
    detect_high_memory_processes

    export PROBLEM_PROCESSES_COUNT=${#PROBLEM_PROCESSES_PIDS[@]}

    if [ $PROBLEM_PROCESSES_COUNT -gt 0 ]; then
        log_info "Detectados $PROBLEM_PROCESSES_COUNT procesos problemáticos"
    else
        log_debug "No se detectaron procesos problemáticos"
    fi
}

# ============================================================================
# Obtener datos de procesos para tabla
# ============================================================================
get_problem_processes_data() {
    # Retornar datos en formato que pueda ser parseado
    for i in "${!PROBLEM_PROCESSES_PIDS[@]}"; do
        echo "${PROBLEM_PROCESSES_PIDS[$i]}|${PROBLEM_PROCESSES_NAMES[$i]}|${PROBLEM_PROCESSES_CPU[$i]}|${PROBLEM_PROCESSES_MEM[$i]}|${PROBLEM_PROCESSES_ACTIONS[$i]}"
    done
}

# ============================================================================
# Terminar un proceso de forma gradual
# ============================================================================
graceful_terminate_process() {
    local pid=$1
    local process_name=$2

    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Se terminaría el proceso: $process_name (PID: $pid)"
        return 0
    fi

    log_info "Terminando proceso: $process_name (PID: $pid)"

    # Verificar que el proceso aún existe
    if ! ps -p $pid > /dev/null 2>&1; then
        log_warn "El proceso ya no existe: $pid"
        return 1
    fi

    # Intentar SIGTERM (terminación gradual)
    kill -TERM $pid 2>/dev/null

    # Esperar hasta 10 segundos
    for i in {1..10}; do
        if ! ps -p $pid > /dev/null 2>&1; then
            log_info "✓ Proceso terminado exitosamente: $process_name"
            log_metric "process_killed,$process_name"
            return 0
        fi
        sleep 1
    done

    # Si aún está corriendo, usar SIGKILL
    log_warn "Proceso no respondió a SIGTERM, usando SIGKILL"
    kill -KILL $pid 2>/dev/null

    sleep 1

    if ! ps -p $pid > /dev/null 2>&1; then
        log_info "✓ Proceso forzado a terminar: $process_name"
        log_metric "process_force_killed,$process_name"
        return 0
    fi

    log_error "No se pudo terminar el proceso: $pid"
    return 1
}

# ============================================================================
# Gestionar procesos detectados
# ============================================================================
manage_problem_processes() {
    if [ $PROBLEM_PROCESSES_COUNT -eq 0 ]; then
        log_info "No hay procesos problemáticos para gestionar"
        return 0
    fi

    local auto_kill=${AUTO_KILL_ENABLED:-false}

    if [ "$auto_kill" = "true" ]; then
        log_warn "AUTO_KILL habilitado - terminando procesos automáticamente"

        for i in "${!PROBLEM_PROCESSES_PIDS[@]}"; do
            local pid="${PROBLEM_PROCESSES_PIDS[$i]}"
            local name="${PROBLEM_PROCESSES_NAMES[$i]}"

            graceful_terminate_process $pid "$name"
        done
    else
        log_info "AUTO_KILL deshabilitado - solo notificando procesos problemáticos"

        for i in "${!PROBLEM_PROCESSES_PIDS[@]}"; do
            local pid="${PROBLEM_PROCESSES_PIDS[$i]}"
            local name="${PROBLEM_PROCESSES_NAMES[$i]}"
            local cpu="${PROBLEM_PROCESSES_CPU[$i]}"
            local mem="${PROBLEM_PROCESSES_MEM[$i]}"

            log_info "Proceso problemático: $name (PID: $pid, CPU: $cpu, MEM: $mem)"
        done

        log_info "Para terminar procesos automáticamente, habilita AUTO_KILL_ENABLED en la configuración"
    fi

    return 0
}
