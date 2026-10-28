#!/usr/bin/env bash
# portable.sh — binário pequeno que roda sem "baixar libs".
#
# CONTEXTO:
#   O binário local exige glibc >= 2.34 só por causa de 3 símbolos do
#   toolchain (__libc_start_main, dlopen, dlsym). Compilando num glibc
#   antigo (container Ubuntu 20.04, glibc 2.31) o MESMO código de ~51 KB
#   passa a rodar em qualquer distro de 2020 pra cá, sem embutir libc nem
#   as libs de UI. X11/Xft/fontconfig/freetype continuam vindo do sistema
#   (presentes em qualquer desktop); sem Xft, o app cai na fonte core.
#
# USO:
#   ./native/portable.sh                 # docker (recomendado p/ release)
#   BASE_IMAGE=ubuntu:18.04 ./native/portable.sh
#   ./native/portable.sh --local         # sem docker: glibc do host
# SAÍDA: native/dist/cmdkeepa-linux-x86_64 (single file, ~51 KB).
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

out="native/dist/cmdkeepa-linux-x86_64"
base="${BASE_IMAGE:-ubuntu:20.04}"
local_build=0
[ "${1:-}" = "--local" ] && local_build=1

mkdir -p native/dist

if [ "$local_build" = 1 ] || ! command -v docker >/dev/null 2>&1; then
    [ "$local_build" = 0 ] && echo "[portable] docker ausente: build local (exige glibc do host)" >&2
    ./native/build.sh
    strip --strip-all -o "$out" native/cmdkeepa
else
    echo "[portable] build em $base"
    docker run --rm \
        -e UID="$(id -u)" -e GID="$(id -g)" \
        -v "$root/native:/src:ro" -v "$root/native/dist:/out" \
        "$base" bash -c '
            set -e
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq --no-install-recommends \
                nasm gcc libc6-dev libx11-dev binutils file >/dev/null
            rm -rf /tmp/b && cp -r /src /tmp/b && cd /tmp/b
            ./build.sh >/dev/null
            strip --strip-all cmdkeepa -o /out/cmdkeepa-linux-x86_64
            chown "$UID:$GID" /out/cmdkeepa-linux-x86_64
        '
fi

chmod +x "$out"
max_glibc="$(objdump -T "$out" | grep -oE 'GLIBC_[0-9.]+' | sort -Vu | tail -1)"
echo "[portable] $out: $(stat -c %s "$out") bytes, requer $max_glibc"
echo "ok: single file para Linux x86-64 (X11 ou XWayland)."
