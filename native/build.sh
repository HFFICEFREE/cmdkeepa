#!/usr/bin/env sh
# build.sh — F0: monta o CmdKeepa nativo (NASM x86-64 + Xlib).
# Uso: ./native/build.sh  (gera ./native/cmdkeepa)
set -eu

cd "$(dirname "$0")"

if ! command -v nasm >/dev/null 2>&1; then
  echo "erro: nasm não encontrado. Instale com:" >&2
  echo "  sudo apt install -y nasm libx11-dev" >&2
  exit 1
fi

echo "[1/5] nasm platform_x11.asm"
nasm -f elf64 -w+number-overflow -w+orphan-labels platform_x11.asm -o platform_x11.o
echo "[2/5] nasm db.asm"
nasm -f elf64 -w+number-overflow -w+orphan-labels db.asm -o db.o
echo "[3/5] nasm ui_f2.asm"
nasm -f elf64 -w+number-overflow -w+orphan-labels ui_f2.asm -o ui_f2.o
echo "[4/5] nasm main.asm"
nasm -f elf64 -w+number-overflow -w+orphan-labels main.asm -o main.o
echo "[5/5] link gcc -no-pie -lX11"
gcc main.o platform_x11.o db.o ui_f2.o -no-pie -lX11 -ldl \
    -Wl,--disable-new-dtags,-rpath,'$ORIGIN/lib' -o cmdkeepa

echo "ok: ./native/cmdkeepa ($(file -b cmdkeepa | cut -d, -f1-2))"
echo "rode: ./native/cmdkeepa   (Esc ou X fecha)"
