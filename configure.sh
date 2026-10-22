#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

log() {
    local nivel="$1"
    shift

    if [[ "$nivel" == "WARN" || "$nivel" == "ERROR" ]]; then
        printf '[%s] %s\n' "$nivel" "$*" >&2
    else
        printf '[%s] %s\n' "$nivel" "$*"
    fi
}

fallar() {
    local mensaje="$1"

    log "ERROR" "$mensaje"
    exit 1
}

trap 'log "ERROR" "Falló el comando en la línea $LINENO: $BASH_COMMAND"' ERR
trap 'codigo_salida=$?; if [[ "$codigo_salida" -ne 0 ]]; then log "ERROR" "Proceso finalizado con errores (código $codigo_salida)."; fi' EXIT

crear_enlace() {
    local destino="$1"
    local objetivo="$2"
    local ruta_relativa="${destino#"$DIRECTORIO_AIRFLOW"/}"
    local ruta_respaldo

    mkdir -p "${destino%/*}"

    if [[ -L "$destino" ]]; then
        if [[ "$(readlink "$destino")" == "$objetivo" ]]; then
            log "OK" "Enlace ya configurado: $ruta_relativa"
            return
        fi

        ln -sfn "$objetivo" "$destino"
        log "INFO" "Enlace actualizado: $ruta_relativa -> $objetivo"
        return
    fi

    if [[ -e "$destino" ]]; then
        if [[ -z "$DIRECTORIO_RESPALDO" ]]; then
            DIRECTORIO_RESPALDO="$DIRECTORIO_AIRFLOW/.configure_backups/$(date +%Y%m%d%H%M%S)-$$"
        fi

        ruta_respaldo="$DIRECTORIO_RESPALDO/$ruta_relativa"
        mkdir -p "${ruta_respaldo%/*}"
        mv "$destino" "$ruta_respaldo"
        log "WARN" "Se respaldó la ruta existente en ${ruta_respaldo#"$DIRECTORIO_AIRFLOW"/}."
    fi

    ln -s "$objetivo" "$destino"
    log "INFO" "Enlace creado: $ruta_relativa -> $objetivo"
}

enlazar_contenido() {
    local origen_relativo="$1"
    local destino="$2"
    local base_objetivo="$3"
    local origen="$DIRECTORIO_SCRIPT/$origen_relativo"
    local elemento
    local nombre
    local -a elementos=()

    mkdir -p "$destino"

    shopt -s nullglob
    elementos=("$origen"/*)
    shopt -u nullglob

    if [[ "${#elementos[@]}" -eq 0 ]]; then
        log "WARN" "No hay elementos para enlazar en '$origen_relativo'."
        return
    fi

    for elemento in "${elementos[@]}"; do
        nombre="${elemento##*/}"
        crear_enlace "$destino/$nombre" "$base_objetivo/$nombre"
    done
}

log "INFO" "Iniciando configuración de enlaces del ETL..."

[[ "$#" -eq 0 ]] || fallar "Este script no acepta argumentos."

for comando in date dirname ln mkdir mv readlink; do
    command -v "$comando" >/dev/null 2>&1 || fallar "El comando '$comando' no está disponible."
done

DIRECTORIO_SCRIPT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
NOMBRE_SUBMODULO="${DIRECTORIO_SCRIPT##*/}"
DIRECTORIO_RESPALDO=""

if [[ -n "${AIRFLOW_ROOT:-}" ]]; then
    [[ -d "$AIRFLOW_ROOT" ]] || fallar "No existe el directorio AIRFLOW_ROOT: '$AIRFLOW_ROOT'."
    DIRECTORIO_AIRFLOW="$(cd -- "$AIRFLOW_ROOT" && pwd -P)"
else
    [[ -d "$DIRECTORIO_SCRIPT/../.." ]] || fallar "No fue posible localizar el directorio de Airflow."
    DIRECTORIO_AIRFLOW="$(cd -- "$DIRECTORIO_SCRIPT/../.." && pwd -P)"
fi

for origen_requerido in dags logic config/etl_config; do
    [[ -d "$DIRECTORIO_SCRIPT/$origen_requerido" ]] || \
        fallar "No existe el directorio requerido '$origen_requerido' en el submódulo."
done

log "INFO" "Validaciones completadas correctamente."
log "INFO" "Submódulo: $NOMBRE_SUBMODULO"
log "INFO" "Directorio de Airflow: $DIRECTORIO_AIRFLOW"

enlazar_contenido \
    "dags" \
    "$DIRECTORIO_AIRFLOW/dags" \
    "../submodules/$NOMBRE_SUBMODULO/dags"

enlazar_contenido \
    "logic" \
    "$DIRECTORIO_AIRFLOW/logic" \
    "../submodules/$NOMBRE_SUBMODULO/logic"

enlazar_contenido \
    "config/etl_config" \
    "$DIRECTORIO_AIRFLOW/config/etl_config" \
    "../../submodules/$NOMBRE_SUBMODULO/config/etl_config"

DIRECTORIO_OUTPUT_ORIGEN="$DIRECTORIO_SCRIPT/output"
DIRECTORIO_OUTPUT_DESTINO="$DIRECTORIO_AIRFLOW/output"
mkdir -p "$DIRECTORIO_OUTPUT_DESTINO"

if [[ -d "$DIRECTORIO_OUTPUT_ORIGEN" ]]; then
    shopt -s nullglob
    directorios_output=("$DIRECTORIO_OUTPUT_ORIGEN"/*)
    shopt -u nullglob

    for directorio_output in "${directorios_output[@]}"; do
        [[ -d "$directorio_output" ]] || continue

        nombre_output="${directorio_output##*/}"
        mkdir -p "$DIRECTORIO_OUTPUT_DESTINO/$nombre_output"
        log "INFO" "Directorio de salida preparado: output/$nombre_output"
    done
else
    log "WARN" "No existe el directorio opcional 'output' en el submódulo."
fi

log "OK" "Configuración de enlaces finalizada correctamente."
