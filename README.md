# Mac Cleanup - Sistema de Mantenimiento de macOS

Sistema automatizado y seguro para mantener tu MacBook funcionando de manera óptima mediante limpieza de RAM y gestión de procesos.

## 🎯 ¿Qué hace este script?

**Mac Cleanup** es un sistema modular de mantenimiento que:

1. **Analiza** el estado actual de tu Mac (RAM, caches, procesos)
2. **Muestra** una tabla resumen con acciones propuestas
3. **Ejecuta** limpieza segura con barra de progreso visual
4. **Reporta** resultados detallados y métricas

Puede ejecutarse **manualmente** cuando lo desees, o **automáticamente** cada X horas en segundo plano.

### Qué limpia:
- ✓ Memoria RAM inactiva (comando `purge`)
- ✓ Caches de usuario antiguos (>30 días)
- ✓ Cache DNS
- ✓ Detecta procesos problemáticos (alta CPU/RAM)

### Qué NO toca:
- ✗ Procesos críticos del sistema (kernel, WindowServer, etc.)
- ✗ Archivos del sistema
- ✗ Aplicaciones o datos del usuario

## 🌟 Características

- **Limpieza de Memoria RAM**: Libera memoria inactiva usando `purge` y limpieza de caches
- **Gestión de Procesos**: Detecta y notifica procesos que consumen muchos recursos
- **Barra de Progreso**: Visualización en tiempo real del proceso de limpieza
- **Modo Interactivo**: Muestra tabla resumen antes de ejecutar
- **Ejecución Automática**: LaunchAgent configurable (1-24 horas)
- **Múltiples Capas de Seguridad**: Validaciones antes de ejecutar
- **Procesos Protegidos**: Blacklist de procesos críticos del sistema
- **Solo Administradores**: Verifica permisos de admin antes de ejecutar

## 📦 Instalación

### Opción 1: Instalación Rápida (Recomendado)

Un solo comando instala todo el sistema:

```bash
curl -fsSL https://raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/execute-remote.sh | bash
```

**¿Qué hace este comando?**
- Descarga y ejecuta el instalador remoto
- Verifica Git y permisos de administrador
- Clona el repositorio en `~/.mac-cleanup`
- Ejecuta el instalador interactivo

**Desinstalación Remota**: También puedes desinstalar remotamente:

```bash
curl -fsSL https://raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/execute-remote.sh | bash -s -- --uninstall
```

**Seguridad**: Si prefieres revisar el script antes de ejecutarlo:

```bash
# Descarga primero
curl -fsSL https://raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/execute-remote.sh > mac-cleanup-remote.sh

# Revisa el contenido
cat mac-cleanup-remote.sh

# Ejecuta si estás conforme
bash mac-cleanup-remote.sh              # Para instalar
bash mac-cleanup-remote.sh --uninstall  # Para desinstalar
```

### Opción 2: Instalación Manual (Para Desarrolladores)

Si prefieres tener control total y ver el código:

```bash
# 1. Clonar el repositorio
git clone https://github.com/ryu-senp/mac-memory-cleaner.git

# 2. Navegar al directorio
cd mac-memory-cleaner

# 3. Ejecutar instalador
./install.sh
```

### Durante la Instalación

El instalador SIEMPRE preguntará:
- ¿Configurar ejecución automática periódica? (yes/no)
- Si yes: ¿Cada cuántas horas? 
  - Opciones: 1h, 3h, 6h (recomendado), 12h, 24h

### Ruta de Instalación Personalizada

Por defecto, se instala en `~/.mac-cleanup`. Si prefieres otra ubicación:

**Durante la instalación remota:**
```bash
curl -fsSL https://raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/execute-remote.sh | bash
```

Te preguntará:
```
📁 Directorio base de instalación:
   (El repositorio .mac-cleanup se creará dentro)
   [default: /Users/tu-usuario]:
```

**Ejemplos:**

1. **Default** (presionar Enter):
   - Directorio base: `$HOME`
   - Se instala en: `~/.mac-cleanup`
   - Variable de entorno: **NO** se crea

2. **Ruta personalizada** (ejemplo: `/opt/otros`):
   - Directorio base: `/opt/otros`
   - Se instala en: `/opt/otros/.mac-cleanup`
   - Variable de entorno: **SÍ** se crea

**Variable de entorno:**

Si eliges un directorio base diferente a `$HOME`, se creará automáticamente:
```bash
export MAC_CLEANUP_INSTALL_DIR="/opt/otros/.mac-cleanup"
```

Esta variable:
- Se agrega a tu `.zshrc` o `.bashrc`
- Se exporta en la sesión actual (disponible inmediatamente)
- Se elimina automáticamente al desinstalar

**¿Por qué?** Permite que el sistema encuentre tu instalación sin importar desde dónde ejecutes `mac-cleanup`.

**Nota importante:** Si el directorio `.mac-cleanup` ya existe en la ruta elegida, la instalación se detendrá y te pedirá desinstalar primero.

## ⚠️ Requisitos

- **Permisos de Administrador**: Tu usuario DEBE estar en el grupo `admin`
- **macOS 11+**: Compatible con Big Sur y posteriores (probado en Sequoia 15.x)
- **sudo**: Necesario para comando `purge` (opcional, se puede deshabilitar)

## 🚀 Uso

### Modo Interactivo (Recomendado para primera vez)

```bash
mac-cleanup
```

Muestra tabla de resumen con:
- Estado actual de memoria
- Acciones a realizar
- Procesos problemáticos
- Estimación de memoria a liberar
- Pregunta confirmación yes/no

### Modo Force (Sin confirmación)

```bash
mac-cleanup --force
```

Usado por el LaunchAgent para ejecución automática.

### Modo Dry-Run (Simular)

```bash
mac-cleanup --dry-run
```

Muestra qué se haría sin ejecutar nada. Útil para testing.

### Modo Agresivo

```bash
mac-cleanup --aggressive
```

Limpieza más profunda (usar con precaución).

### Ver Ayuda

```bash
mac-cleanup --help
```

## 📋 Ejemplos de Output

### Tabla de Resumen Interactiva

```
╔═══════════════════════════════════════════════════════════════════════╗
║              RESUMEN DE LIMPIEZA - Mac Maintenance                    ║
╠═══════════════════════════════════════════════════════════════════════╣
║ MEMORIA                                                               ║
╠═══════════════════════════════════════════════════════════════════════╣
║ Estado Actual:                                                        ║
║   • Total RAM:           16 GB                                        ║
║   • Memoria Libre:        2 GB (13%)                                  ║
║   • Memoria Inactiva:     3 GB                                        ║
║   • Swap Usado:          1.5 GB                                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║ Acciones a Realizar:                                                  ║
║   ✓ Ejecutar purge (liberar ~3 GB de memoria inactiva)               ║
║   ✓ Limpiar user caches (estimado 500 MB)                            ║
║   ✓ Flush DNS cache                                                   ║
╠═══════════════════════════════════════════════════════════════════════╣
║ PROCESOS PROBLEMÁTICOS                                                ║
╠═══════════════════════════════════════════════════════════════════════╣
║ PID    Nombre              CPU%    Memoria    Acción                  ║
║ 1234   Chrome Helper       95%     1.8 GB     Notificar               ║
╠═══════════════════════════════════════════════════════════════════════╣
║ ESTIMADO                                                              ║
╠═══════════════════════════════════════════════════════════════════════╣
║ Memoria a liberar:        ~3.5 GB                                     ║
║ Procesos a notificar:     1                                           ║
║ Duración estimada:        15-30 segundos                              ║
╚═══════════════════════════════════════════════════════════════════════╝

¿Proceder con la limpieza? (yes/no):
```

### Barra de Progreso Durante Ejecución

```
╔═══════════════════════════════════════════════════════════════════════╗
║                    EJECUTANDO LIMPIEZA DEL SISTEMA                    ║
╚═══════════════════════════════════════════════════════════════════════╝

Progreso:
  ✓ Análisis del sistema completado
  ✓ Memoria inactiva liberada (3GB)
  ✓ Caches limpiados (500MB)

[████████████████████████████████████████░░░░░░░░░░]  80% Limpiando cache DNS...
```

## ⚙️ Configuración

Archivo: `config/maintenance.conf`

### Configuración de Memoria

```bash
MIN_FREE_MEMORY_GB=2         # Ejecutar limpieza si memoria libre < 2GB
CACHE_AGE_DAYS=30            # Eliminar caches > 30 días
ENABLE_PURGE=true            # Usar comando purge (requiere sudo)
```

### Configuración de Procesos

```bash
CPU_THRESHOLD_PERCENT=80     # Marcar procesos con CPU > 80%
MEMORY_THRESHOLD_GB=2        # Marcar procesos con memoria > 2GB
AUTO_KILL_ENABLED=false      # ⚠️ NO terminar procesos automáticamente
```

### Configuración de Seguridad

```bash
MIN_BATTERY_PERCENT=20       # No ejecutar si batería < 20%
CHECK_TIME_MACHINE=true      # No ejecutar si hay backup en progreso
MIN_DISK_SPACE_GB=5          # Requerir al menos 5GB libres
```

### Quiet Hours

```bash
QUIET_HOURS_START=22         # No ejecutar automáticamente desde las 10 PM
QUIET_HOURS_END=7            # hasta las 7 AM
```

## 🔒 Seguridad

### Procesos Protegidos

El archivo `config/process-blacklist.conf` lista procesos que **NUNCA** se terminarán:

- `kernel_task`, `launchd`, `WindowServer`
- Todos los procesos del sistema (root)
- Servicios críticos
- Tu lista personalizada

### Validaciones de Seguridad

Antes de ejecutar, verifica:
- ✓ Nivel de batería (>20%)
- ✓ Espacio en disco (>5GB)
- ✓ Carga del sistema
- ✓ Time Machine no ejecutando backup
- ✓ Quiet hours (solo para modo automático)

### Seguridad del Remote Installer

**¿Es seguro ejecutar `curl ... | bash`?**

El script `execute-remote.sh`:
- Es de código abierto y auditable en GitHub
- Solo descarga código del repositorio oficial
- Requiere permisos de admin para instalación (validación explícita)
- No ejecuta comandos destructivos
- Solo clona el repo y ejecuta el instalador/desinstalador interactivo

**Recomendaciones de seguridad**:
1. Revisa el código en GitHub antes de ejecutar
2. Usa la opción de descarga + revisión + ejecución manual
3. Solo ejecuta desde la URL oficial: `raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/execute-remote.sh`

**¿Qué NO hace el instalador remoto?**
- ✗ No modifica archivos del sistema sin tu permiso
- ✗ No ejecuta limpieza automáticamente (solo instala)
- ✗ No requiere sudo hasta que lo uses (purge)
- ✗ No envía datos a servidores externos

## 📂 Estructura de Archivos

```
mac-cleanup/
├── .gitignore                      # Archivos ignorados por Git
├── README.md                       # Esta documentación
├── VERSION                         # Versión actual del sistema
├── install.sh                      # Instalador maestro
├── uninstall.sh                    # Desinstalador interactivo
├── execute-remote.sh               # Instalador/desinstalador remoto (curl | bash)
├── mac-maintenance.sh              # Script principal
├── lib/                            # Bibliotecas modulares
│   ├── logger.sh                  # Sistema de logging
│   ├── progress-bar.sh            # Barra de progreso visual
│   ├── safety-checks.sh           # Validaciones de seguridad
│   ├── memory-manager.sh          # Gestión de memoria
│   ├── process-monitor.sh         # Monitor de procesos
│   └── summary-table.sh           # Generador de tablas
├── config/                         # Configuración
│   ├── maintenance.conf           # Configuración principal
│   └── process-blacklist.conf     # Procesos protegidos
├── logs/                           # Logs automáticos
│   ├── maintenance.log            # Log de ejecución
│   └── metrics.log                # Métricas (CSV)
├── templates/                      # Templates
│   └── com.user.macmaintenance.plist.template
└── README.md                       # Esta documentación
```

## 🔄 Ejecución Automática

El sistema usa **LaunchAgent de macOS** (equivalente moderno a cron) para ejecutar automáticamente el comando `mac-cleanup --force` en el intervalo configurado.

### Opciones de Intervalo

Durante la instalación puedes elegir:
- **1 hora** - Para sistemas muy activos
- **3 horas** - Limpieza frecuente
- **6 horas** - Recomendado (balance perfecto)
- **12 horas** - Dos veces al día
- **24 horas** - Una vez al día

### Ver Estado del LaunchAgent

```bash
# Verificar que está cargado
launchctl list | grep macmaintenance

# Ver configuración completa
cat ~/Library/LaunchAgents/com.user.macmaintenance.plist

# Ver intervalo configurado
grep StartInterval ~/Library/LaunchAgents/com.user.macmaintenance.plist
```

### Forzar Ejecución Manual (testing)

```bash
# Ejecutar el LaunchAgent ahora (sin esperar el intervalo)
launchctl start com.user.macmaintenance
```

### Cambiar Intervalo

```bash
# Opción 1: Desinstalar y reinstalar
./uninstall.sh
./install.sh
# Elegir nuevo intervalo cuando pregunte

# Opción 2: Editar manualmente el plist
# Cambiar el valor de StartInterval (en segundos)
nano ~/Library/LaunchAgents/com.user.macmaintenance.plist
# Luego recargar:
launchctl unload ~/Library/LaunchAgents/com.user.macmaintenance.plist
launchctl load ~/Library/LaunchAgents/com.user.macmaintenance.plist
```

## 🔄 Actualización

### Sistema Automático de Actualizaciones ✨

**Mac Cleanup verifica automáticamente** si hay nuevas versiones disponibles cada vez que lo ejecutas en modo interactivo.

**¿Qué sucede?**
1. Al ejecutar `mac-cleanup`, el sistema verifica la versión en GitHub
2. Si hay una nueva versión, muestra una notificación:
   ```
   ╔═══════════════════════════════════════════════════════════════════════╗
   ║                    📦 NUEVA VERSIÓN DISPONIBLE                        ║
   ╠═══════════════════════════════════════════════════════════════════════╣
   ║  Versión actual:     0.0.1-BETA
   ║  Versión disponible: 0.0.2-BETA
   ╚═══════════════════════════════════════════════════════════════════════╝
   
   ¿Deseas actualizar ahora? (yes/no):
   ```
3. Si dices `yes`, descarga e instala automáticamente la nueva versión
4. Si dices `no`, continúa con la versión actual

**Ventajas:**
- ✅ No se actualiza automáticamente sin tu permiso
- ✅ Verificación rápida (timeout 3 segundos)
- ✅ Solo se verifica en modo interactivo (no en modo `--force`)
- ✅ Instalación automática con un solo `yes`

### Actualización Manual

Si prefieres actualizar manualmente:

**Opción 1: Si instalaste desde `~/.mac-cleanup`:**

```bash
cd ~/.mac-cleanup
git pull origin main

# No necesitas reinstalar, los cambios se aplicarán automáticamente
# Si hubo cambios en el LaunchAgent, recárgalo:
launchctl unload ~/Library/LaunchAgents/com.user.macmaintenance.plist
launchctl load ~/Library/LaunchAgents/com.user.macmaintenance.plist
```

**Opción 2: Si instalaste con git clone manual:

```bash
cd <tu-directorio-de-clonacion>
git pull origin main

# No necesitas reinstalar, los cambios se aplicarán automáticamente
```

## 📊 Logs y Métricas

### Ver Logs en Tiempo Real

```bash
tail -f logs/maintenance.log
```

### Ver Métricas (CSV)

```bash
cat logs/metrics.log
```

Formato: `timestamp,metric,value`

Ejemplos de métricas:
- `memory_before_free_gb,2`
- `memory_after_free_gb,5`
- `purge_freed_gb,3`
- `cache_freed_mb,500`

## 🗑️ Desinstalación

### Opción 1: Desinstalación Remota (Rápida y Completa)

```bash
curl -fsSL https://raw.githubusercontent.com/ryu-senp/mac-memory-cleaner/main/execute-remote.sh | bash -s -- --uninstall
```

**Este método removerá:**
- ✓ Comando `mac-cleanup` (symlink)
- ✓ LaunchAgent (ejecución automática)
- ✓ Logs y configuración (si confirmas)
- ✓ **Código fuente descargado** (`~/.mac-cleanup`) (si confirmas)

Desinstalación completa - perfecto para remover todo rastro del sistema.

### Opción 2: Desinstalación Local

```bash
./uninstall.sh
```

El desinstalador interactivo:
- Muestra qué está instalado actualmente
- Pide confirmación antes de proceder
- Remueve comando y LaunchAgent
- Pregunta si deseas eliminar logs/config (opcional)
- Verifica que todo se removió correctamente

**Se removerá:**
- ✓ Symlink `/usr/local/bin/mac-cleanup`
- ✓ LaunchAgent `~/Library/LaunchAgents/com.user.macmaintenance.plist`

**Se preserva** (por defecto):
- Logs (`logs/`)
- Configuración (`config/`)
- Código fuente (el directorio del repositorio)

El desinstalador te da la opción de eliminar también los datos si lo deseas.

## 🛠️ Troubleshooting

### "Permisos insuficientes" al ejecutar

**Problema**: El usuario no está en el grupo `admin`.

**Solución**:
```bash
# Verificar si estás en el grupo admin
groups | grep admin

# Si no estás, contacta al administrador del sistema
# O si eres el dueño del Mac:
sudo dseditgroup -o edit -a $(whoami) -t user admin
```

### "Permission denied" al ejecutar purge

**Problema**: El comando `purge` requiere sudo.

**Solución**:
1. Ejecuta manualmente para cachear sudo: `sudo purge`
2. O deshabilita purge en config: `ENABLE_PURGE=false`

### El comando mac-cleanup no se encuentra

**Problema**: Symlink no creado.

**Solución**:
```bash
# Ejecutar directamente
./mac-maintenance.sh

# O reinstalar
./install.sh
```

### LaunchAgent no se ejecuta

**Problema**: No está cargado o hay error en el plist.

**Solución**:
```bash
# Verificar estado
launchctl list | grep macmaintenance

# Recargar
launchctl unload ~/Library/LaunchAgents/com.user.macmaintenance.plist
launchctl load ~/Library/LaunchAgents/com.user.macmaintenance.plist

# Ver logs de errores
cat /tmp/mac-cleanup.error.log
```

### "No memory freed" después de ejecutar

**Problema**: Puede que no ser necesario limpiar.

**Explicación**: Si tienes suficiente memoria libre (>2GB por defecto), el sistema está funcionando bien. El purge solo reorganiza memoria inactiva.

### Error al clonar el repositorio

**Problema**: `git clone` falla o no tienes git instalado.

**Solución**:
```bash
# Verificar si git está instalado
git --version

# Si no está instalado, instalar con Homebrew:
brew install git

# O descargar manualmente desde GitHub:
# https://github.com/ryu-senp/mac-memory-cleaner/archive/refs/heads/main.zip
# Descomprimir y ejecutar ./install.sh
```

### "Mac Cleanup Ya Está Instalado"

**Problema**: Al ejecutar `./install.sh` aparece mensaje de que ya está instalado.

**Solución**:
```bash
# Si quieres reinstalar, primero desinstala:
./uninstall.sh

# Luego instala de nuevo:
./install.sh

# Si solo quieres actualizar:
git pull origin main
```

## 📝 FAQ

### ¿Es seguro ejecutar este script?

Sí. Tiene múltiples capas de seguridad:
- Blacklist de procesos críticos
- Validaciones pre-ejecución
- Modo dry-run para testing
- Logs completos de auditoría
- Solo ejecuta con permisos de administrador

### ¿Necesito permisos de administrador?

**SÍ, es OBLIGATORIO**. El script verifica que tu usuario esté en el grupo `admin` antes de ejecutar.

- **Para ejecutar el script**: SÍ (grupo admin requerido)
- **Para purge**: SÍ (comando sudo)
- **Para LaunchAgent**: No (se instala en tu usuario)
- **Para symlink**: Generalmente no

Si no eres administrador, el script se detendrá con un mensaje claro explicando cómo obtener permisos.

### ¿Qué hace el comando purge?

Libera memoria inactiva forzando al sistema a escribir datos al disco. Es un comando oficial de macOS, completamente seguro.

### ¿Puedo personalizar qué se limpia?

Sí. Edita `config/maintenance.conf` para:
- Deshabilitar purge
- Cambiar umbrales de memoria/CPU
- Ajustar edad de caches
- etc.

### ¿Cómo funciona la barra de progreso?

La barra de progreso muestra en tiempo real:
- Porcentaje de completitud (0-100%)
- Acción actual en curso
- Pasos completados listados arriba de la barra

Durante la ejecución, los logs de consola se suprimen temporalmente para mantener la visualización limpia.

### ¿Funciona en todos los macOS?

Sí, compatible con macOS 11 (Big Sur) y posteriores.
Probado en macOS Sequoia (15.x).

### ¿Por qué LaunchAgent y no cron?

**LaunchAgent es la forma nativa y moderna de macOS** para ejecutar tareas programadas:
- ✓ Sobrevive reinicios automáticamente
- ✓ Mejor integración con el sistema
- ✓ Se ejecuta en contexto de usuario (no requiere root)
- ✓ Respeta el estado del sistema (suspensión, etc.)
- ✓ Apple recomienda LaunchAgent sobre cron

Cron todavía funciona en macOS pero está deprecado y puede tener problemas de permisos en versiones recientes.

## ⚡ Optimizaciones de Rendimiento

El script incluye varias optimizaciones para ejecución rápida:

### Limpieza de Caches Optimizada
- Usa `find -delete` en lugar de loops, 100x más rápido
- Limita análisis a 5000 archivos para estimaciones rápidas
- Excluye directorios protegidos (App Store, Safari)

### Análisis Eficiente
- Estimaciones en lugar de cálculos exactos cuando es apropiado
- Procesamiento paralelo donde sea posible
- Symlink resolution cacheado

### Supresión de Output
- Durante la barra de progreso, los logs se escriben solo a archivo
- Flag `SUPPRESS_CONSOLE_OUTPUT` mantiene la UI limpia
- Restaura output normal al finalizar

## 🤝 Contribuir

Este es un proyecto personal, pero sugerencias son bienvenidas.

## 📄 Licencia

Uso personal.

## ✨ Autor

Claudio Pardo
