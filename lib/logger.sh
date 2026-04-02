#!/bin/bash
# logger.sh - Sistema de logging y métricas para Mac Cleanup

# Obtener directorio del script (resolver symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ $SCRIPT_PATH != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/maintenance.log"
METRICS_FILE="$SCRIPT_DIR/logs/metrics.log"

# Niveles de log
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Nivel de log actual (por defecto INFO)
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

# Control de salida (para modo progress bar)
SUPPRESS_CONSOLE_OUTPUT=false

# ============================================================================
# Configurar nivel de log
# ============================================================================
set_log_level() {
    local level=$1
    case "$level" in
        debug) CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info)  CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        warn)  CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN ;;
        error) CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        *) CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
    esac
}

# ============================================================================
# Función interna para escribir logs
# ============================================================================
_write_log() {
    local level=$1
    local level_name=$2
    local message=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Verificar si este nivel debe ser logueado
    if [ $level -ge $CURRENT_LOG_LEVEL ]; then
        # Escribir a archivo
        echo "[$timestamp] $level_name: $message" >> "$LOG_FILE"

        # Escribir a consola solo si no está suprimido
        if [ "${SUPPRESS_CONSOLE_OUTPUT:-false}" != "true" ] && [ "${FORCE_MODE:-false}" != "true" ]; then
            case "$level_name" in
                ERROR) echo "❌ $message" ;;
                WARN)  echo "⚠️  $message" ;;
                INFO)  echo "ℹ️  $message" ;;
                DEBUG) echo "🔍 $message" ;;
            esac
        fi
    fi
}

# ============================================================================
# Funciones públicas de logging
# ============================================================================
log_debug() {
    _write_log $LOG_LEVEL_DEBUG "DEBUG" "$1"
}

log_info() {
    _write_log $LOG_LEVEL_INFO "INFO" "$1"
}

log_warn() {
    _write_log $LOG_LEVEL_WARN "WARN" "$1"
}

log_error() {
    _write_log $LOG_LEVEL_ERROR "ERROR" "$1"
}

# ============================================================================
# Logging de métricas
# ============================================================================
log_metric() {
    local metric=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Formato CSV: timestamp,metric_name,value
    echo "$timestamp,$metric" >> "$METRICS_FILE"
}

# ============================================================================
# Inicializar archivos de log
# ============================================================================
init_logs() {
    # Crear directorio de logs si no existe
    mkdir -p "$(dirname "$LOG_FILE")"

    # Crear archivos si no existen
    touch "$LOG_FILE"
    touch "$METRICS_FILE"

    # Agregar cabecera al log de métricas si está vacío
    if [ ! -s "$METRICS_FILE" ]; then
        echo "timestamp,metric,value" > "$METRICS_FILE"
    fi
}

# ============================================================================
# Rotar logs antiguos
# ============================================================================
rotate_logs() {
    local keep_days=${KEEP_LOGS_DAYS:-30}
    local log_dir="$(dirname "$LOG_FILE")"

    log_info "Rotando logs más antiguos que $keep_days días"

    # Buscar y eliminar logs antiguos
    find "$log_dir" -name "*.log" -type f -mtime +$keep_days -delete 2>/dev/null

    # Si el log actual es muy grande (> 10MB), rotarlo
    local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
    if [ $log_size -gt 10485760 ]; then  # 10MB en bytes
        local backup_name="${LOG_FILE}.$(date +%Y%m%d_%H%M%S)"
        mv "$LOG_FILE" "$backup_name"
        touch "$LOG_FILE"
        log_info "Log rotado a: $backup_name"
    fi
}

# ============================================================================
# Logging de inicio de sesión
# ============================================================================
log_session_start() {
    local mode=${1:-"interactive"}
    echo "" >> "$LOG_FILE"
    echo "========================================================================" >> "$LOG_FILE"
    log_info "=== INICIO DE SESIÓN DE MANTENIMIENTO ==="
    log_info "Modo: $mode"
    log_info "Usuario: $(whoami)"
    log_info "Fecha: $(date)"
    log_info "Sistema: $(sw_vers -productName) $(sw_vers -productVersion)"
}

# ============================================================================
# Logging de fin de sesión
# ============================================================================
log_session_end() {
    local duration_seconds=${1:-0}
    log_info "=== FIN DE SESIÓN DE MANTENIMIENTO ==="
    log_info "Duración: ${duration_seconds}s"
    echo "========================================================================" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

# ============================================================================
# Inicialización automática
# ============================================================================
init_logs
