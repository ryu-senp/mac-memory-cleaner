#!/bin/bash
# progress-bar.sh - Sistema de barra de progreso y estado

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Variables globales para progreso
TOTAL_STEPS=0
CURRENT_STEP=0
FIRST_STEP_COMPLETED=false
BAR_SHOWN=false
declare -a COMPLETED_STEPS=()

# ============================================================================
# Inicializar barra de progreso
# ============================================================================
init_progress() {
    local total=$1
    TOTAL_STEPS=$total
    CURRENT_STEP=0
    FIRST_STEP_COMPLETED=false
    BAR_SHOWN=false
    COMPLETED_STEPS=()
    echo ""
}

# ============================================================================
# Limpiar barra de progreso (antes de pedir input al usuario)
# ============================================================================
clear_progress_bar() {
    printf "\r\033[K"
}

# ============================================================================
# Actualizar barra de progreso (SIEMPRE en la última línea)
# ============================================================================
update_progress_bar() {
    local current_action=$1

    # Calcular progreso del SIGUIENTE paso
    local next_step=$((CURRENT_STEP + 1))
    local percent=$((next_step * 100 / TOTAL_STEPS))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    # Crear barra
    local bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done

    # Mostrar barra SIN newline - usar \r para mantener en la misma línea
    printf "\r${BLUE}[${bar}]${NC} %3d%% ${current_action}...    " "$percent"

    BAR_SHOWN=true
}

# ============================================================================
# Completar un paso y agregarlo a la lista
# ============================================================================
complete_step() {
    local step_name=$1
    local status=${2:-"done"}  # done, error, skip

    # Incrementar paso actual
    ((CURRENT_STEP++))

    # Asegurar que no pase del 100%
    if [ $CURRENT_STEP -gt $TOTAL_STEPS ]; then
        CURRENT_STEP=$TOTAL_STEPS
    fi

    # Símbolo según estado
    local symbol=""
    local color=""
    case "$status" in
        done)
            symbol="✓"
            color="$GREEN"
            ;;
        error)
            symbol="✗"
            color="$RED"
            ;;
        skip)
            symbol="⊘"
            color="$YELLOW"
            ;;
        *)
            symbol="✓"
            color="$GREEN"
            ;;
    esac

    # Mover a nueva línea (salir de la línea de la barra)
    printf "\n"

    # Mostrar encabezado solo la primera vez
    if [ "$FIRST_STEP_COMPLETED" = false ]; then
        echo ""
        echo -e "${GRAY}Progreso:${NC}"
        FIRST_STEP_COMPLETED=true
    fi

    # Agregar paso completado
    echo -e "  ${color}${symbol}${NC} ${step_name}"

    # Guardar en array
    COMPLETED_STEPS+=("${symbol} ${step_name}")

    # Resetear flag para que la siguiente barra se escriba normalmente
    BAR_SHOWN=false
}

# ============================================================================
# Finalizar barra de progreso
# ============================================================================
finish_progress() {
    # Mover a nueva línea después de la barra final
    printf "\n"
    echo ""
}

