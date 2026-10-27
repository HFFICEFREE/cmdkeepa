#!/bin/bash
# build.sh — compila o CmdKeepa nativo com erros precisos por arquivo.
#
# CONTEXTO:
#   Monta os 4 .asm do ../ (platform_x11, db, ui_f2, main; o preview F1 vive
#   em ../archive/ui_f1.example.asm e NÃO entra no link) + linka com
#   `gcc -no-pie -lX11`.
#   Dois detalhes que já morderam gente aqui:
#     1. nasm precisa de `-I <dir-do-rec.inc>`; sem isso o erro é
#        "unable to open include file `rec.inc'".
#     2. Rode `source ../error-utils/env.sh` (ou este caminho) antes, senão
#        `nasm: command not found`.
#   Classe de problema que elimina: builds com erro vago / include errado.
#
# USO: native/error-utils/build.sh        (funciona de qualquer cwd)
# PRÉ-REQUISITOS: nasm no PATH (ver env.sh), gcc, libX11.
# SAÍDA: 0 + "ok:" no sucesso; erro do nasm/gcc com arquivo:linha no fracasso.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/.."

command -v nasm >/dev/null 2>&1 || { echo "build.sh: nasm não encontrado — rode: source native/error-utils/env.sh" >&2; exit 1; }

for f in platform_x11 db ui_f2 main; do
    echo "[build] nasm $f.asm"
    nasm -f elf64 -I"$SRC/" "$SRC/$f.asm" -o "$SRC/$f.o"
done
echo "[build] link gcc -no-pie -lX11"
gcc "$SRC/main.o" "$SRC/platform_x11.o" "$SRC/db.o" "$SRC/ui_f2.o" -no-pie -lX11 -ldl -o "$SRC/cmdkeepa"
echo "ok: $SRC/cmdkeepa ($(file -b "$SRC/cmdkeepa" | cut -d, -f1-2))"
