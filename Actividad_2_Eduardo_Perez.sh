#!/bin/bash

# ==============================================================================
# Script: Actividad_2_Eduardo_Perez.sh
# Descripción:
#   Actividad 2: Programación de scripts en Linux
#   Menú interactivo con información del sistema y operaciones básicas.
#   Utiliza 'tput' para experiencia mejorada (reloj en vivo, control cursor,
#   colores, monitor CPU en vivo, pausa en countdown) si el terminal lo soporta.
#   Muestra el porcentaje de espacio LIBRE en disco.
#   Realiza verificaciones de compatibilidad y degrada funcionalidad si es necesario.
#   Limpia la pantalla al inicio y al salir.
# Alumno: Eduardo Pérez Jover
# Fecha: 2025-05-05
# Uso: ./Actividad_2_Eduardo_Perez.sh
# Dependencias: bash, tput (opcional), coreutils (ls, df, free, etc.), awk, sed, grep, bc (para cálculo de %), lscpu, top, timeout
# ==============================================================================

# --- Variables Globales ---
refresh_time=10          # Tiempo (en segundos) por defecto para volver al menú después de una acción.
previous_users=$(who | wc -l) # Número inicial de usuarios conectados (para opción 5).

# --- Variables para coordenadas TPUT ---
# Estas variables almacenarán las coordenadas (fila/columna) donde se actualizarán
# dinámicamente elementos como la hora o donde se situará el cursor para la entrada.
# Se calculan en display_initial_menu si tput está disponible.
time_row=
time_col=
prompt_row=
prompt_col=

# --- Variables para capacidades TPUT ---
# Almacenan los códigos de escape ANSI generados por tput para diversas acciones
# (limpiar pantalla, mover cursor, guardar/restaurar posición, ocultar/mostrar cursor, etc.)
# y para colores. Se inicializan vacías y se rellenan en check_tput_capabilities.
T_CLEAR="" T_CUP="" T_SC="" T_RC="" T_CIVIS="" T_CNORM="" T_EL="" T_COLS=""
C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN="" C_WHITE=""

# --- Banderas de estado ---
# Indican si ciertas funcionalidades avanzadas están disponibles.
HAS_TPUT=false           # ¿Se encontró el comando 'tput'?
CAN_CONTROL_CURSOR=false # ¿El terminal soporta control avanzado del cursor (mover, guardar, etc.)?
CAN_USE_COLORS=false     # ¿El terminal soporta al menos 8 colores?

# --- Función: check_tput_capabilities ---
# Propósito: Verifica la existencia del comando 'tput' y determina si el terminal
#            soporta las capacidades necesarias para control avanzado del cursor
#            y para el uso de colores. Actualiza las variables T_*, C_* y las banderas.
#            También verifica la existencia del comando 'bc', necesario para la opción 1.
check_tput_capabilities() {
    # Verifica si el comando 'tput' existe en el PATH.
    if command -v tput >/dev/null 2>&1; then
        HAS_TPUT=true
        echo "Info: Comando 'tput' encontrado. Verificando capacidades..." >&2 # Mensaje a stderr

        # Intenta obtener los códigos de tput. Redirige errores a /dev/null.
        T_CLEAR=$(tput clear 2>/dev/null)
        T_CUP_CHECK=$(tput cup 0 0 2>/dev/null) # Usado solo para verificar si 'cup' funciona.
        T_SC=$(tput sc 2>/dev/null)      # Guardar posición del cursor (Save Cursor)
        T_RC=$(tput rc 2>/dev/null)      # Restaurar posición del cursor (Restore Cursor)
        T_CIVIS=$(tput civis 2>/dev/null) # Ocultar cursor (Cursor Invisible)
        T_CNORM=$(tput cnorm 2>/dev/null) # Mostrar cursor (Cursor Normal)
        T_EL=$(tput el 2>/dev/null)      # Borrar hasta el final de la línea (Erase Line)
        T_COLS=$(tput cols 2>/dev/null)  # Obtener número de columnas del terminal

        # Comprueba si se obtuvieron códigos válidos para las capacidades esenciales de cursor.
        if [[ -n "$T_CUP_CHECK" && -n "$T_SC" && -n "$T_RC" && -n "$T_EL" && -n "$T_CIVIS" && -n "$T_CNORM" ]]; then
            CAN_CONTROL_CURSOR=true
            echo "Info: El terminal soporta control avanzado del cursor." >&2
        else
            CAN_CONTROL_CURSOR=false
            # Resetea las variables si no se soportan todas las capacidades.
            T_SC="" T_RC="" T_CIVIS="" T_CNORM="" T_EL=""
            echo "Advertencia: Terminal no soporta control avanzado del cursor." >&2
        fi

        # Verifica el soporte de colores.
        local colors_available=$(tput colors 2>/dev/null) # Número de colores soportados.
        T_RESET_ATTR=$(tput sgr0 2>/dev/null)      # Resetear todos los atributos (color, bold, etc.)
        T_SET_BOLD=$(tput bold 2>/dev/null)        # Activar negrita
        T_SET_RED=$(tput setaf 1 2>/dev/null)      # Color de frente (foreground) rojo
        T_SET_GREEN=$(tput setaf 2 2>/dev/null)    # Color verde
        T_SET_YELLOW=$(tput setaf 3 2>/dev/null)   # Color amarillo
        T_SET_BLUE=$(tput setaf 4 2>/dev/null)     # Color azul
        T_SET_MAGENTA=$(tput setaf 5 2>/dev/null) # Color magenta
        T_SET_CYAN=$(tput setaf 6 2>/dev/null)     # Color cyan
        T_SET_WHITE=$(tput setaf 7 2>/dev/null)    # Color blanco

        # Comprueba si se obtuvo el código de reset, el de un color y si hay al menos 8 colores.
        if [[ -n "$T_RESET_ATTR" && -n "$T_SET_RED" && "$colors_available" -ge 8 ]]; then
            CAN_USE_COLORS=true
            # Asigna los códigos obtenidos a las variables C_* para facilitar su uso.
            C_RESET="$T_RESET_ATTR"; C_BOLD="$T_SET_BOLD"; C_RED="$T_SET_RED"; C_GREEN="$T_SET_GREEN"; C_YELLOW="$T_SET_YELLOW"; C_BLUE="$T_SET_BLUE"; C_MAGENTA="$T_SET_MAGENTA"; C_CYAN="$T_SET_CYAN"; C_WHITE="$T_SET_WHITE"
            echo "Info: El terminal soporta colores." >&2
        else
            CAN_USE_COLORS=false
            # Resetea las variables de color si no se soportan.
            C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN="" C_WHITE=""
            echo "Advertencia: Terminal no soporta colores." >&2
        fi

        # Informa al usuario si alguna capacidad avanzada no está disponible.
        if ! $CAN_CONTROL_CURSOR || ! $CAN_USE_COLORS; then
             echo "El menú funcionará de forma básica sin algunas características visuales." >&2
             sleep 3 # Pausa para que el usuario pueda leer el mensaje.
        fi
    else
        # Si 'tput' no existe, deshabilita todas las funcionalidades avanzadas.
        HAS_TPUT=false; CAN_CONTROL_CURSOR=false; CAN_USE_COLORS=false
        echo "Advertencia: Comando 'tput' no encontrado. Menú funcionará en modo básico." >&2
        sleep 3
    fi

    # Verificar si 'bc' está disponible para el cálculo del porcentaje en la opción 1.
    if ! command -v bc > /dev/null 2>&1; then
        echo "Advertencia: Comando 'bc' no encontrado. No se podrá calcular el % de espacio libre." >&2
        sleep 3
    fi
}

# --- Función: do_tput ---
# Propósito: Ejecuta un comando 'tput' de forma segura, solo si 'tput' está disponible
#            y la capacidad específica es soportada (para cursor y colores).
# Argumentos: $1: Nombre de la capacidad de tput (ej: clear, cup, sc, rc, civis, cnorm, el, cols).
#             $@: Parámetros adicionales para la capacidad (ej: fila y columna para 'cup'). 
do_tput() {
    local capability=$1; shift; local params=("$@") # Extrae la capacidad y los parámetros.

    if $HAS_TPUT; then # Solo intentar si tput existe.
        case $capability in
            clear) # Limpiar pantalla
                   [[ -n "$T_CLEAR" ]] && printf "%s" "$T_CLEAR"
                   ;;
            cup)   # Mover cursor a fila/columna (Cursor Position)
                   # Requiere control de cursor y 2 parámetros (fila, columna).
                   [[ "$CAN_CONTROL_CURSOR" == "true" && ${#params[@]} -eq 2 ]] && tput cup "${params[0]}" "${params[1]}" 2>/dev/null
                   ;;
            sc)    # Guardar posición del cursor
                   [[ "$CAN_CONTROL_CURSOR" == "true" ]] && tput sc 2>/dev/null
                   ;;
            rc)    # Restaurar posición del cursor
                   [[ "$CAN_CONTROL_CURSOR" == "true" ]] && tput rc 2>/dev/null
                   ;;
            civis) # Ocultar cursor
                   [[ "$CAN_CONTROL_CURSOR" == "true" ]] && tput civis 2>/dev/null
                   ;;
            cnorm) # Mostrar cursor
                   [[ "$CAN_CONTROL_CURSOR" == "true" ]] && tput cnorm 2>/dev/null
                   ;;
            el)    # Borrar hasta el final de la línea
                   [[ "$CAN_CONTROL_CURSOR" == "true" ]] && tput el 2>/dev/null
                   ;;
            cols)  # Obtener el número de columnas
                   # Devuelve el valor obtenido por tput o 80 como fallback.
                   [[ -n "$T_COLS" ]] && echo "$T_COLS" || echo 80
                   ;;
            *)     # Capacidad desconocida o no manejada
                   ;;
        esac
    # Fallbacks para capacidades básicas si tput no está disponible.
    elif [[ "$capability" == "clear" ]]; then
        # Intenta usar el comando 'clear' si existe.
        command -v clear >/dev/null 2>&1 && clear
    elif [[ "$capability" == "cols" ]]; then
        # Intenta obtener columnas con 'stty', fallback a 80.
        local cols=$(stty size 2>/dev/null | awk '{print $2}'); echo "${cols:-80}"
    fi
}

# --- Función auxiliar para imprimir con color ---
# Propósito: Imprime texto aplicando un código de color si los colores están soportados,
#            y opcionalmente evita añadir una nueva línea al final.
# Argumentos: $1: Código de color (una variable C_*) o cadena vacía para no usar color.
#             $2: Texto a imprimir.
#             $3: Si es "n", no añade una nueva línea al final.
print_color() {
    local color_code=$1
    local text=$2
    local no_newline=$3

    # Aplica color solo si está soportado y se proporcionó un código de color.
    if $CAN_USE_COLORS && [[ -n "$color_code" ]]; then
        # Imprime: código de color + texto + código de reset
        printf "%s%s%s" "$color_code" "$text" "$C_RESET"
    else
        # Imprime solo el texto si no hay soporte de color o no se especificó.
        printf "%s" "$text"
    fi

    # Añade nueva línea a menos que se indique lo contrario.
    if [[ "$no_newline" != "n" ]]; then
        printf "\n"
    fi
}

# --- Detección Sistema Operativo y Tamaño Disco Principal ---
# Intenta obtener una descripción amigable del SO y el tamaño total del disco principal.
# Diferencia entre WSL (Windows Subsystem for Linux) y Linux nativo para buscar el disco C: o /.

# Comprueba si estamos en WSL buscando "microsoft" en /proc/version (método común).
if grep -qi microsoft /proc/version; then
    # WSL: Intenta obtener la descripción de lsb_release, fallback a uname -r.
    os_type="WSL ($(lsb_release -ds 2>/dev/null || uname -r))"
    # WSL: Busca el tamaño del disco montado en /mnt/c (disco C: de Windows).
    disk_size=$(df -h | awk '$6=="/mnt/c" {print $2}' 2>/dev/null) || disk_size="N/A" # N/A si no se encuentra
else
    # Linux Nativo: Intenta obtener la descripción de lsb_release, fallback a uname -s.
    os_type=$(lsb_release -ds 2>/dev/null || uname -s)
    # Linux Nativo: Busca el tamaño del disco raíz (/), fallback al disco /home.
    disk_size=$(df -h / | awk 'NR==2{print $2}' 2>/dev/null) || disk_size=$(df -h /home | awk 'NR==2{print $2}' 2>/dev/null) || disk_size="N/A"
fi
# Asegura que disk_size tenga un valor ("N/A" si falló la detección).
disk_size=${disk_size:-"N/A"}

# --- Funciones de formato de secciones ---
# Simplifican la impresión de cabeceras y pies de sección con un estilo consistente.
print_section_header() {
    print_color "$C_BLUE" "==========================================================="
    printf "%s%s --- %s --- %s\n" "$C_BOLD" "$C_BLUE" "$1" "$C_RESET" # Título en negrita azul
    print_color "$C_BLUE" "==========================================================="
}
print_section_footer() {
    print_color "$C_BLUE" "==========================================================="
}

# --- Función countdown (con pausa - CORREGIDA v2) ---
# Propósito: Muestra una cuenta regresiva en pantalla. Permite al usuario pausar
#            la cuenta atrás presionando ESPACIO y salir de la cuenta (volver al menú)
#            presionando ESC. Se adapta a terminales con y sin control de cursor.
# Argumentos: $1: Número de segundos para la cuenta atrás.
countdown() {
    local secs=$1      # Segundos restantes.
    local paused=false # Bandera: ¿está la cuenta pausada?
    local can_inline=false # Bandera: ¿puede actualizar el mensaje en la misma línea?
    local el_code=""   # Código tput para borrar la línea (si can_inline es true).

    # Determina si podemos usar actualización en la misma línea (requiere tput y 'el').
    if $CAN_CONTROL_CURSOR && el_code=$(tput el 2>/dev/null) && [[ -n "$el_code" ]]; then
        can_inline=true
    fi

    # Bucle principal: continúa mientras queden segundos O la cuenta esté pausada.
    while [[ $secs -gt 0 ]] || $paused; do
        local key="" # Variable para almacenar la tecla presionada por el usuario.

        # --- Mostrar Mensaje Actual ---
        if $can_inline; then
            # Si podemos actualizar en línea:
            do_tput sc    # Guardar posición actual del cursor.
            printf "\r"   # Mover cursor al inicio de la línea actual.
        fi

        # Construir y mostrar el mensaje adecuado (pausado o contando).
        if $paused; then
            local message="Pausado ($secs s restantes). Presione ESPACIO para continuar, ESC para salir."
            print_color "$C_MAGENTA" "$message" "n" # Imprimir mensaje pausado (sin nueva línea).
        else
            local message="Volviendo en: $secs segundos... Presione ESPACIO para pausar, ESC para salir."
            print_color "$C_CYAN" "$message" "n"    # Imprimir mensaje contando (sin nueva línea).
        fi

        if $can_inline; then
            # Si actualizamos en línea:
            printf "%s" "$el_code" # Borrar cualquier carácter sobrante de la línea anterior.
            do_tput rc    # Restaurar cursor a la posición guardada (después del mensaje).
        else
            # Si no podemos actualizar en línea, simplemente añade una nueva línea después del mensaje.
            printf "\n"
        fi

        # --- Esperar Tecla ---
        # Usa 'read' para capturar una tecla.
        if $paused; then
            # Si está pausado, espera indefinidamente (-s: silencioso, -n 1: lee 1 carácter).
            IFS= read -s -n 1 key
        else
            # Si está contando, espera MÁXIMO 1 segundo (-t 1).
            IFS= read -s -n 1 -t 1 key
            # Si 'read' termina por timeout (no se presionó tecla), $key estará vacía.
            if [[ -z "$key" ]]; then
                # Timeout: no se presionó tecla, descontar un segundo de la cuenta.
                secs=$((secs-1))
            fi
            # Si se presionó una tecla antes del timeout, $key tendrá valor,
            # y el segundo se descontará en la sección "Procesar Tecla Presionada".
        fi

        # --- Procesar Tecla Presionada ---
        case "$key" in
            $'\e') # Tecla ESC (Escape)
                   if $can_inline; then printf "\r%s" "$el_code"; fi # Limpiar la línea actual si es inline.
                   break # Salir del bucle 'while'.
                   ;;
            ' ') # Tecla ESPACIO
                 # Cambia el estado de la bandera 'paused'.
                 if $paused; then
                     paused=false
                     # Importante: NO descontar segundo al reanudar.
                 else
                     paused=true
                     # Importante: NO descontar segundo al pausar.
                 fi
                 # 'continue' salta directamente a la siguiente iteración del 'while'.
                 # Esto evita que el caso '*' de abajo descuente incorrectamente un segundo
                 # justo después de pausar/reanudar.
                 continue
                 ;;
            *) # Cualquier otra tecla O ninguna tecla (si hubo timeout y ya se descontó)
               # Si NO estamos pausados Y se presionó una tecla (key no está vacío) ANTES del timeout,
               # significa que 'read' devolvió una tecla, pero aún no hemos descontado el segundo
               # correspondiente a esa espera. Lo descontamos aquí.
               # Si estamos pausados, o si no se presionó tecla (timeout), no hacemos nada aquí.
               if ! $paused && [[ -n "$key" ]]; then
                   secs=$((secs-1))
               fi
               ;;
        esac

        # Asegura que los segundos no bajen de 0 si el usuario presiona teclas muy rápido.
        [[ $secs -lt 0 ]] && secs=0

    done # Fin del bucle while

    # --- Limpieza Final ---
    if $can_inline; then
        # Si estábamos actualizando en línea, borra la última línea mostrada y añade una nueva línea final.
        printf "\r%s\n" "$el_code"
    else
        # Si no usábamos inline, ya hemos ido añadiendo nuevas líneas.
        # Solo nos aseguramos de que haya una línea vacía al final si la cuenta terminó (no se pausó).
        if ! $paused; then echo ""; fi
    fi
}


# --- Función para mostrar el menú estático (con colores) ---
# Propósito: Limpia la pantalla y dibuja el menú principal con la información del sistema
#            y las opciones disponibles. Calcula y guarda las coordenadas para la hora
#            y el prompt de entrada si se soporta el control de cursor.
display_initial_menu() {
    do_tput clear        # Limpia la pantalla
    local current_row=0  # Contador de filas

    # --- Encabezado personalizado ---
    print_color "$C_BLUE" "==========================================================="; current_row=$((current_row + 1))
    # Títulos centrados de forma aproximada (ajustar espacios si es necesario)
    printf "%20s%s%s%s\n" "" "$C_BOLD$C_BLUE" "Sistemas Operativos Avanzados" "$C_RESET"; current_row=$((current_row + 1))
    printf "%20s%s%s%s\n" "" "$C_BOLD$C_BLUE" "Actividad 2" "$C_RESET"; current_row=$((current_row + 1))
    printf "%20s%s%s%s\n" "" "$C_BOLD$C_BLUE" "Eduardo Pérez Jover" "$C_RESET"; current_row=$((current_row + 1))
    print_color "$C_BLUE" "==========================================================="; current_row=$((current_row + 1))

    # --- Información del sistema ---
    printf "Sistema Operativo: %s%s%s\n" "$C_GREEN" "$os_type" "$C_RESET"; current_row=$((current_row + 1))
    if $CAN_CONTROL_CURSOR; then
        local time_label="Hora actual:       "; printf "%s" "$time_label"
        time_row=$current_row; time_col=${#time_label}
        printf "\n"; current_row=$((current_row + 1))
    else
        printf "Hora actual:       %s%s%s\n" "$C_GREEN" "$(date '+%Y-%m-%d %H:%M:%S')" "$C_RESET"; current_row=$((current_row + 1))
    fi
    printf "Memoria RAM Total: %s%s%s\n" "$C_GREEN" "$(free -h | awk '/Mem:/ {print $2}')" "$C_RESET"; current_row=$((current_row + 1))
    printf "Tamaño Disco Ppal: %s%s%s\n" "$C_GREEN" "$disk_size" "$C_RESET"; current_row=$((current_row + 1))
    # Extraer modelo de CPU sin la etiqueta "Model name:"
    local cpu_model=$(lscpu | grep 'Model name:' | awk -F ':' '{print $2}' | sed 's/^[[:space:]]*//')
    printf "CPU:               %s%s%s\n" "$C_GREEN" "$cpu_model" "$C_RESET"; current_row=$((current_row + 1))

    # --- Separador y título del menú principal ---
    print_color "$C_BLUE" "==========================================================="; current_row=$((current_row + 1))
    printf "%20s%sMenu Principal%s\n" "" "$C_BOLD$C_BLUE" "$C_RESET"; current_row=$((current_row + 1))
    print_color "$C_BLUE" "==========================================================="; current_row=$((current_row + 1))

    # --- Opciones del Menú ---
    printf "%s%s)%s Espacio libre del disco\n" "$C_YELLOW" "1" "$C_RESET"; current_row=$((current_row + 1))
    printf "%s%s)%s Tamaño ocupado por un directorio\n" "$C_YELLOW" "2" "$C_RESET"; current_row=$((current_row + 1))
    printf "%s%s)%s Uso del procesador (en vivo)\n" "$C_YELLOW" "3" "$C_RESET"; current_row=$((current_row + 1))
    printf "%s%s)%s Número de usuarios conectados actualmente\n" "$C_YELLOW" "4" "$C_RESET"; current_row=$((current_row + 1))
    printf "%s%s)%s Nuevos usuarios conectados desde última vez\n" "$C_YELLOW" "5" "$C_RESET"; current_row=$((current_row + 1))
    printf "%s%s)%s Mostrar últimas 5 líneas de un fichero\n" "$C_YELLOW" "6" "$C_RESET"; current_row=$((current_row + 1))
    printf "%s%s)%s Copiar archivos .sh y .c a otro directorio\n" "$C_YELLOW" "7" "$C_RESET"; current_row=$((current_row + 1))
    echo "--"; current_row=$((current_row + 1))
    printf "%s%s)%s Configuración (Tiempo refresco: %ss)\n" "$C_YELLOW" "8" "$C_RESET" "$refresh_time"; current_row=$((current_row + 1))
    echo "--"; current_row=$((current_row + 1))
    printf "%s%s)%s Salir\n" "$C_YELLOW" "q" "$C_RESET"; current_row=$((current_row + 1))
    print_color "$C_BLUE" "==========================================================="; current_row=$((current_row + 1))

    # --- Prompt para el Usuario ---
    local prompt_label="Seleccione una opción: "; print_color "$C_CYAN" "$prompt_label" "n"
    if $CAN_CONTROL_CURSOR; then prompt_row=$current_row; prompt_col=${#prompt_label}; fi
}

# --- Función para actualizar SOLO la hora en pantalla (con color) ---
# Propósito: Si el control de cursor está activo, mueve el cursor a la posición
#            guardada para la hora, la actualiza y vuelve a la posición original.
#            Se llama repetidamente desde el bucle principal.
update_time_display() {
    # Solo funciona si tenemos control de cursor y las coordenadas se calcularon.
    if ! $CAN_CONTROL_CURSOR || [[ -z "$time_row" ]] || [[ -z "$time_col" ]]; then return; fi

    do_tput sc # Guarda la posición actual del cursor (probablemente en el prompt)
    do_tput cup "$time_row" "$time_col" # Mueve el cursor a la fila/columna de la hora

    # Imprime la hora actual formateada, con color y sin nueva línea.
    print_color "$C_GREEN" "$(date '+%Y-%m-%d %H:%M:%S')" "n"

    do_tput el # Borra cualquier carácter sobrante en la línea (si la hora anterior era más larga).
    do_tput rc # Restaura el cursor a su posición original (el prompt).
}

# --- Bucle Principal del Menú (con colores y nuevas funcionalidades) ---
# Propósito: Gestiona la interacción principal con el usuario. Muestra el menú,
#            actualiza la hora (si es posible), espera la entrada del usuario,
#            ejecuta la acción seleccionada y vuelve a mostrar el menú.
do_main_loop() {
    # Oculta el cursor si es posible para una apariencia más limpia mientras se espera input.
    $CAN_CONTROL_CURSOR && do_tput civis

    # Bucle infinito hasta que el usuario elija salir (opción q/Q).
    while true; do
        # Actualiza la hora en cada iteración (si el terminal lo soporta).
        update_time_display

        # Mueve el cursor a la posición del prompt si es posible.
        $CAN_CONTROL_CURSOR && do_tput cup $prompt_row $prompt_col

        # Espera la entrada del usuario (una sola tecla).
        local read_cmd_base="read"; local read_options=""
        if $CAN_CONTROL_CURSOR; then
            # Modo avanzado (con tput): usa timeout de 1s (-t 1) para permitir que la hora
            # se actualice si no se presiona nada. -s: silencioso, -n 1: una tecla.
            read_options="-s -n 1 -t 1"
        else
            # Modo básico (sin tput): espera indefinidamente (-n 1: una tecla).
            # No usamos -s aquí para que el usuario vea lo que teclea (eco).
            read_options="-n 1"
        fi

        # Ejecuta read con las opciones adecuadas. 'opcion' almacenará la tecla.
        # El 'if' comprueba si 'read' terminó porque se leyó una tecla (éxito, devuelve 0)
        # o si terminó por timeout (fracaso, devuelve > 0).
        if $read_cmd_base $read_options opcion; then
            # --- Se presionó una tecla ---
            if ! $CAN_CONTROL_CURSOR; then
                # Si estamos en modo básico, añade una nueva línea después de la tecla presionada.
                echo ""
            fi

            # Muestra el cursor temporalmente mientras se ejecuta la acción (si estaba oculto).
            $CAN_CONTROL_CURSOR && do_tput cnorm

            # No limpiar la pantalla aquí todavía, algunas opciones (como la 3 en modo avanzado)
            # gestionan la pantalla de forma diferente. La limpieza se hará dentro de cada case
            # o al redibujar el menú después.

            # Evalúa la opción seleccionada.
            case $opcion in
                1) # Opción 1: Espacio libre del disco (con % libre)
                   do_tput clear # Limpiar pantalla para esta opción
                   print_section_header "Espacio Libre del Disco"
                   df -h # Muestra la salida completa de df -h

                   # Intentar obtener la línea específica del disco principal (WSL o Linux)
                   local disk_line=""
                   if grep -qi microsoft /proc/version; then # WSL
                       # Busca la línea correspondiente a /mnt/c
                       disk_line=$(df -h | awk '$6=="/mnt/c"{found=1; print} END{exit !found}')
                   else # Linux Nativo
                       # Busca la línea de / (raíz), si no, la de /home
                       disk_line=$(df -h / | awk 'NR==2{print}') || disk_line=$(df -h /home | awk 'NR==2{print}')
                   fi

                   # Si se encontró la línea del disco principal...
                   if [[ -n "$disk_line" ]]; then
                       # Parsear la línea para obtener los datos con awk
                       local disk_used_h=$(echo "$disk_line" | awk '{print $3}')  # Usado Human-readable (ej: 5.2G)
                       local disk_avail_h=$(echo "$disk_line" | awk '{print $4}') # Disponible Human-readable (ej: 18G)
                       local disk_perc_used=$(echo "$disk_line" | awk '{print $5}' | sed 's/%//') # Porcentaje usado (quitando '%')
                       local mount_point=$(echo "$disk_line" | awk '{print $6}') # Punto de montaje (ej: / o /mnt/c)
                       local disk_perc_avail="N/A" # Porcentaje disponible (inicializado a N/A)

                       # Calcular porcentaje disponible si 'bc' está instalado y el porcentaje usado es un número.
                       if command -v bc > /dev/null 2>&1 && [[ "$disk_perc_used" =~ ^[0-9]+$ ]]; then
                           # Calcula 100 - porcentaje usado
                           disk_perc_avail=$(echo "100 - $disk_perc_used" | bc)
                       fi

                       # Imprimir el resumen formateado
                       printf "\nResumen disco principal (%s%s%s):\n" "$C_MAGENTA" "$mount_point" "$C_RESET"
                       printf "  Usado: %s%s%s, Disponible: %s%s%s (%s%s%%%s Libre)\n" \
                              "$C_YELLOW" "$disk_used_h" "$C_RESET" \
                              "$C_GREEN" "$disk_avail_h" "$C_RESET" \
                              "$C_GREEN" "$disk_perc_avail" "$C_RESET" # Muestra el % libre calculado
                   else
                       # Mensaje si no se pudo parsear la línea del disco
                       print_color "$C_RED" "\nNo se pudo obtener resumen del disco principal."
                   fi
                   print_section_footer
                   countdown $refresh_time # Espera antes de volver al menú
                   ;;

                2) # Opción 2: Tamaño directorio
                   do_tput clear
                   print_section_header "Tamaño de Directorio"
                   printf "%sIntroduzca la ruta del directorio: %s" "$C_CYAN" "$C_RESET"; read dir # Pide ruta
                   # Verifica si la ruta es un directorio existente (-d)
                   if [ -d "$dir" ]; then
                       print_color "$C_YELLOW" "Calculando tamaño..."
                       local size
                       # Ejecuta 'du -sh' (summary, human-readable) para obtener el tamaño total.
                       # Usa 'timeout 30' para evitar que se quede colgado en directorios enormes o problemáticos.
                       # Redirige errores de 'du' a /dev/null. Extrae solo el tamaño con awk.
                       size=$(timeout 30 du -sh "$dir" 2>/dev/null | awk '{print $1}')
                       # Verifica el código de salida de timeout. 124 significa que se alcanzó el tiempo límite.
                       if [[ $? -eq 124 ]]; then
                           print_color "$C_RED" "Error: Cálculo excedió tiempo límite (30s)."
                       elif [[ -n "$size" ]]; then # Si se obtuvo un tamaño...
                           printf "El directorio '%s%s%s' ocupa: %s%s%s\n" "$C_MAGENTA" "$dir" "$C_RESET" "$C_GREEN" "$size" "$C_RESET"
                       else # Si 'size' está vacío (posiblemente por error de permisos dentro de 'du')...
                           print_color "$C_RED" "No se pudo calcular tamaño (verifique permisos)."
                       fi
                   else # Si la ruta no es un directorio válido...
                       print_color "$C_RED" "Error: Directorio '$dir' no existe."
                   fi
                   print_section_footer
                   countdown $refresh_time
                   ;;

                3) # Opción 3: Uso CPU (en vivo si es posible)
                   # Comportamiento diferente si hay control de cursor o no.
                   if ! $CAN_CONTROL_CURSOR; then
                       # --- Modo Básico (sin control de cursor) ---
                       # Muestra una única instantánea del uso de CPU.
                       do_tput clear
                       print_section_header "Uso del Procesador (Instantáneo)"
                       echo "Mostrando carga de CPU (obtenida con 'top -bn1'):"
                       # Ejecuta 'top' en modo batch (-b), 1 iteración (-n1), y filtra la línea de CPU.
                       # TERM=dumb evita que top use códigos de terminal complejos.
                       TERM=dumb top -bn1 | grep "%Cpu" || print_color "$C_RED" "Error: No se pudo ejecutar 'top'."
                       echo "Nota: Esto es solo una instantánea del momento."
                       print_section_footer
                       countdown $refresh_time # Usa el countdown normal para volver.
                   else
                       # --- Modo Avanzado (con control de cursor) ---
                       # Muestra la línea de CPU actualizada cada segundo.
                       do_tput clear
                       print_section_header "Uso del Procesador (en vivo)"
                       local cpu_info_row=5 # Fila donde se mostrará la info de CPU (ajustable).
                       local instr_row=7    # Fila para las instrucciones (ajustable).

                       # Ocultar cursor específicamente para esta vista en vivo.
                       do_tput civis

                       # Bucle para actualizar la información de CPU.
                       while true; do
                           # Obtener la línea de CPU con top (batch, 1 iteración).
                           local cpu_line=$(TERM=dumb top -bn1 | grep "%Cpu")
                           # Mensaje de error si top falla.
                           [[ -z "$cpu_line" ]] && cpu_line="Error al obtener datos de CPU"

                           do_tput sc # Guardar posición del cursor actual (antes de moverlo).

                           # Mover a la fila de info CPU, mostrarla y borrar resto de línea.
                           do_tput cup $cpu_info_row 0
                           print_color "$C_YELLOW" "$cpu_line" "n" # Sin nueva línea.
                           do_tput el

                           # Mover a la fila de instrucciones, mostrarlas y borrar resto de línea.
                           do_tput cup $instr_row 0
                           print_color "$C_CYAN" "Actualizando cada segundo... Presione ESC para volver al menú." "n"
                           do_tput el

                           do_tput rc # Restaurar cursor a la posición guardada.

                           # Esperar 1 segundo o hasta que se presione una tecla.
                           read -s -n 1 -t 1 key
                           # Si la tecla presionada fue ESC, salir del bucle de actualización.
                           if [[ "$key" == $'\e' ]]; then
                               break
                           fi
                       done # Fin del bucle de actualización de CPU.

                       # Al salir del bucle (con ESC):
                       do_tput cnorm # Mostrar el cursor de nuevo.
                       # No llamamos a countdown aquí. El script volverá directamente
                       # al bucle principal y redibujará el menú inmediatamente.
                   fi
                   ;; # Fin Opción 3

                4) # Opción 4: Usuarios conectados
                   do_tput clear
                   print_section_header "Usuarios Conectados Actualmente"
                   local num_users=$(who | wc -l) # Cuenta las líneas de 'who' para obtener sesiones.
                   printf "Total sesiones: %s%s%s\n" "$C_GREEN" "$num_users" "$C_RESET"
                   echo "Usuarios/Sesiones:"
                   who # Muestra la lista de usuarios/sesiones.
                   print_section_footer
                   countdown $refresh_time
                   ;;

                5) # Opción 5: Nuevos usuarios desde la última vez
                   do_tput clear
                   print_section_header "Nuevos Usuarios (desde última consulta)"
                   current_users=$(who | wc -l) # Obtiene el número actual de usuarios.
                   # Calcula la diferencia con el número guardado previamente.
                   new_users=$((current_users - previous_users))
                   printf "Usuarios/Sesiones actuales: %s%s%s\n" "$C_GREEN" "$current_users" "$C_RESET"
                   printf "Usuarios/Sesiones previas:  %s%s%s\n" "$C_YELLOW" "$previous_users" "$C_RESET"
                   printf "Diferencia:                 %s%s%s\n" "$C_CYAN" "$new_users" "$C_RESET"
                   # Actualiza el número previo para la próxima consulta.
                   previous_users=$current_users
                   print_section_footer
                   countdown $refresh_time
                   ;;

                6) # Opción 6: Últimas 5 líneas de un fichero
                   do_tput clear
                   print_section_header "Últimas 5 Líneas de Fichero"
                   printf "%sIntroduzca la ruta del fichero: %s" "$C_CYAN" "$C_RESET"; read fichero # Pide ruta
                   # Verifica si es un fichero regular (-f) y si se puede leer (-r).
                   if [[ -f "$fichero" && -r "$fichero" ]]; then
                       printf "Últimas 5 líneas de '%s%s%s':\n" "$C_MAGENTA" "$fichero" "$C_RESET"
                       tail -n 5 "$fichero" # Muestra las últimas 5 líneas.
                   elif [[ ! -f "$fichero" ]]; then # Si no es un fichero...
                       print_color "$C_RED" "Error: Fichero '$fichero' no existe o no es un fichero regular."
                   else # Si no se puede leer...
                       print_color "$C_RED" "Error: Fichero '$fichero' no tiene permisos de lectura."
                   fi
                   print_section_footer
                   countdown $refresh_time
                   ;;

                7) # Opción 7: Copiar archivos .sh y .c
                   do_tput clear
                   print_section_header "Copiar Archivos (.sh, .c)"
                   printf "%sDirectorio Origen: %s" "$C_CYAN" "$C_RESET"; read origen   # Pide directorio origen
                   printf "%sDirectorio Destino: %s" "$C_CYAN" "$C_RESET"; read destino # Pide directorio destino

                   # Validar que el origen sea un directorio.
                   if [[ ! -d "$origen" ]]; then
                       print_color "$C_RED" "Error: Directorio Origen '$origen' no existe."
                   else
                       # Intentar crear el directorio destino (y padres si no existen) con 'mkdir -p'.
                       mkdir -p "$destino"
                       if [[ $? -ne 0 ]]; then # Si falla la creación del destino...
                           print_color "$C_RED" "Error: No se pudo crear el directorio Destino '$destino'."
                       else
                           # Proceder con la copia.
                           print_color "$C_YELLOW" "Copiando archivos..."
                           local copied_sh=-1 copied_c=-1 # Banderas para saber si se copió algo

                           # Buscar y copiar archivos .sh en el origen (sin entrar en subdirectorios: -maxdepth 1).
                           # -exec cp -v -t "$destino" {} + : Ejecuta 'cp', '-v' para verbose, '-t' especifica el destino,
                           # '{} +' pasa múltiples archivos encontrados a un solo comando 'cp'.
                           # Redirige errores de 'find' o 'cp' a /dev/null.
                           find "$origen" -maxdepth 1 -type f -name '*.sh' -exec cp -v -t "$destino" {} + 2>/dev/null
                           copied_sh=$? # Guarda el estado de salida (0 si tuvo éxito al menos una vez)

                           # Buscar y copiar archivos .c.
                           find "$origen" -maxdepth 1 -type f -name '*.c' -exec cp -v -t "$destino" {} + 2>/dev/null
                           copied_c=$?

                           # Informar al usuario.
                           # Si alguno de los 'find/cp' tuvo éxito (código 0), informa que finalizó.
                           if [[ $copied_sh -eq 0 || $copied_c -eq 0 ]]; then
                               print_color "$C_GREEN" "Intento de copia finalizado. Verifique los mensajes anteriores."
                           else
                               # Si ambos fallaron (o no encontraron archivos), informa.
                               print_color "$C_YELLOW" "No se encontraron archivos .sh o .c en '$origen' o hubo errores durante la copia."
                           fi
                       fi
                   fi
                   print_section_footer
                   countdown $refresh_time
                   ;;

                8) # Opción 8: Configuración del tiempo de refresco
                   do_tput clear
                   print_section_header "Configuración Tiempo Refresco"
                   printf "Tiempo actual de espera/refresco: %s%s%s segundos.\n" "$C_CYAN" "$refresh_time" "$C_RESET"
                   printf "%sIntroduzca el nuevo tiempo (número entero > 0): %s" "$C_CYAN" "$C_RESET"; read nuevo_tiempo

                   # Validar que la entrada sea un número entero positivo usando una expresión regular.
                   # ^: inicio de línea, [1-9]: primer dígito no puede ser 0, [0-9]*: cero o más dígitos siguientes, $: fin de línea.
                   if [[ "$nuevo_tiempo" =~ ^[1-9][0-9]*$ ]]; then
                       refresh_time=$nuevo_tiempo # Actualiza la variable global.
                       print_color "$C_GREEN" "Tiempo de refresco actualizado a $refresh_time segundos."
                   else
                       print_color "$C_RED" "Entrada inválida. El tiempo debe ser un número entero mayor que cero."
                       print_color "$C_RED" "Tiempo no cambiado (sigue siendo $refresh_time s)."
                   fi
                   print_section_footer
                   # Usa el countdown con el tiempo actual (que podría o no haberse actualizado).
                   countdown $refresh_time
                   ;;

                q | Q) # Salir del script
                      # La limpieza (mostrar cursor, limpiar pantalla) se hace en el trap o al final.
                      print_color "$C_MAGENTA" "\nSaliendo del menú. ¡Hasta luego!"
                      # Asegurarse de mostrar el cursor antes de salir limpiamente.
                      $HAS_TPUT && $CAN_CONTROL_CURSOR && do_tput cnorm
                      exit 0 # Salida exitosa.
                      ;;

                *) # Opción inválida
                   do_tput clear
                   print_section_header "Error: Opción No Válida"
                   print_color "$C_RED" "La tecla '$opcion' no corresponde a una opción válida."
                   print_color "$C_YELLOW" "Por favor, use una de las opciones [1-8] o [q/Q] para salir."
                   print_section_footer
                   countdown 2 # Pequeña pausa para que el usuario vea el error.
                   ;;
            esac # Fin del case $opcion

            # --- Después de procesar una opción (excepto salir) ---
            # Volver a dibujar el menú principal para la siguiente iteración.
            # Necesario porque las opciones anteriores limpiaron la pantalla o
            # la opción 3 (CPU en vivo) la modificó.

            # Si la opción NO fue la 3 en modo avanzado (que ya limpió al salir)...
            # O si estamos en modo básico (donde opción 3 no fue 'en vivo')...
            if [[ "$opcion" != "3" || "$CAN_CONTROL_CURSOR" == "false" ]]; then
                 display_initial_menu # Redibuja el menú completo.
                 # Vuelve a ocultar el cursor si es posible.
                 $CAN_CONTROL_CURSOR && do_tput civis
            # Si la opción FUE la 3 en modo avanzado...
            elif [[ "$opcion" == "3" && "$CAN_CONTROL_CURSOR" == "true" ]]; then
                 # Al salir de CPU en vivo (modo avanzado), la pantalla ya se limpió
                 # al salir de su bucle interno (con break). Solo necesitamos redibujar.
                 display_initial_menu
                 # Vuelve a ocultar el cursor si es posible.
                 $CAN_CONTROL_CURSOR && do_tput civis
            fi
            # Si la opción fue 'q' o 'Q', el script ya habrá salido.

        else
            # --- Timeout de read (solo ocurre si CAN_CONTROL_CURSOR es true) ---
            # 'read' terminó porque pasó 1 segundo sin que se presionara tecla.
            # No hacemos nada aquí (' : ' es un comando nulo). El bucle 'while true'
            # simplemente continuará, llamará a update_time_display (actualizando la hora)
            # y volverá a esperar en el 'read -t 1'.
            :
        fi # Fin del if 'read'

    done # Fin del bucle principal 'while true'
}

# --- Manejo de Interrupciones (Ctrl+C) y Señales de Terminación ---
# Propósito: Asegurar una salida limpia si el script es interrumpido (ej: Ctrl+C)
#            o recibe una señal para terminar (SIGTERM).
# 'trap' ejecuta el comando entre comillas cuando recibe una de las señales listadas.
trap "
    echo -e '\n' # Nueva línea para separar del posible estado actual
    print_color '$C_RED' 'Interrupción detectada (Ctrl+C o señal). Saliendo limpiamente...'
    # Intenta restaurar el cursor a normal (visible) si tput estaba activo.
    $HAS_TPUT && $CAN_CONTROL_CURSOR && tput cnorm 2>/dev/null
    # Intenta limpiar la pantalla si tput estaba activo.
    # $HAS_TPUT && tput clear 2>/dev/null # Comentado: A veces es útil ver dónde se interrumpió.
    exit 1 # Sale con código de error 1 para indicar salida anormal.
" INT SIGINT SIGTERM
# INT, SIGINT: Señales típicas enviadas por Ctrl+C.
# SIGTERM: Señal común para solicitar la terminación de un proceso.

# --- Punto de Entrada Principal del Script ---

# 1. Verificar capacidades del terminal (tput, cursor, colores, bc).
check_tput_capabilities

# 2. Limpiar la pantalla inicial (usando do_tput para seguridad).
do_tput clear

# 3. Mostrar el menú por primera vez.
display_initial_menu

# 4. Iniciar el bucle principal que maneja la interacción.
do_main_loop

# --- Código de seguridad final ---
# Aunque el trap y la opción 'q' deberían manejarlo, como medida extra,
# nos aseguramos de que el cursor sea visible al final de la ejecución normal
# (si el script llegase aquí por alguna razón inesperada).
do_tput cnorm
exit 0 # Salida normal y exitosa.