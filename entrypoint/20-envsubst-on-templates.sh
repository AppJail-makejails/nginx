#!/bin/sh

. /lib.subr

set -e

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        info "$@"
    fi
}

ME=$(basename "${0}")
TEMPLATE_DIR="${NGINX_ENVSUBST_TEMPLATE_DIR:-/usr/local/etc/nginx/templates}"
SUFFIX="${NGINX_ENVSUBST_TEMPLATE_SUFFIX:-.template}"
OUTPUT_DIR="${NGINX_ENVSUBST_OUTPUT_DIR:-/usr/local/etc/nginx/conf.d}"
STREAM_SUFFIX="${NGINX_ENVSUBST_STREAM_TEMPLATE_SUFFIX:-.stream-template}"
STREAM_OUTPUT_DIR="${NGINX_ENVSUBST_STREAM_OUTPUT_DIR:-/usr/local/etc/nginx/stream-conf.d}"

[ -d "${TEMPLATE_DIR}" ] || exit 0
if [ ! -w "${OUTPUT_DIR}" ]; then
    entrypoint_log "$ME: ERROR: ${TEMPLATE_DIR} exists, but ${OUTPUT_DIR} is not writable"
    exit 0
fi

find "$TEMPLATE_DIR" -follow -type f -name "*$SUFFIX" -print | while read -r template; do
    relative_path="${template#"${TEMPLATE_DIR}/"}"
    output_path="${OUTPUT_DIR}/${relative_path%"${SUFFIX}"}"
    subdir=$(dirname "${relative_path}")
    # create a subdirectory where the template file exists
    mkdir -p "${OUTPUT_DIR}/${subdir}"
    entrypoint_log "${ME}: Running envsubst on ${template} to ${output_path}"
    envsubst < "${template}" > "${output_path}"
done

# Print the first file with the stream suffix, this will be false if there are none
if test -n "$(find "${TEMPLATE_DIR}" -name "*${STREAM_SUFFIX}" -print -quit)"; then
    mkdir -p "${STREAM_OUTPUT_DIR}"
    if [ ! -w "${STREAM_OUTPUT_DIR}" ]; then
        entrypoint_log "${ME}: ERROR: ${TEMPLATE_DIR} exists, but ${STREAM_OUTPUT_DIR} is not writable"
        exit 0
    fi
    find "${TEMPLATE_DIR}" -follow -type f -name "*${STREAM_SUFFIX}" -print | while read -r template; do
        relative_path="${template#"${TEMPLATE_DIR}/"}"
        output_path="${STREAM_OUTPUT_DIR}/${relative_path%"${STREAM_SUFFIX}"}"
        subdir=$(dirname "${relative_path}")
        # create a subdirectory where the template file exists
        mkdir -p "${STREAM_OUTPUT_DIR}/$subdir"
        entrypoint_log "${ME}: Running envsubst on ${template} to ${output_path}"
        envsubst < "${template}" > "${output_path}"
    done
fi
