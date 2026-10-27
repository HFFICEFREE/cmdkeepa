#!/bin/bash
# gate.sh — portão de regressão do CmdKeepa nativo (fix #35).
#
# CONTEXTO (p/ LLMs e humanos):
#   Roda TUDO que valida os fixes #11-36 em ordem: build (com warnings),
#   lint estático, checks Python (round-trip 11-20 e 21-30, inclui auditoria
#   ABI), harnesses C headless (dbtest: parser/persistência; uitest: fluxos
#   de edição/commit/cancel/busca) e jsoncheck de paridade. Falha no primeiro
#   erro (set -e). X11 interativo (run.sh) fica FORA: precisa de servidor e
#   foco; o smoke de boot está documentado no README.
# USO: source native/error-utils/env.sh && native/error-utils/gate.sh
# SAÍDA: 0 + "GATE OK"; !=0 + etapa que falhou.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$ROOT"

command -v nasm >/dev/null || { echo "GATE FALHA: sem nasm (source env.sh)" >&2; exit 1; }

echo "== gate[1/6] build =="
native/error-utils/build.sh >/tmp/gate-build.log 2>&1 || { tail -20 /tmp/gate-build.log; exit 1; }
tail -1 /tmp/gate-build.log

echo "== gate[2/6] lint =="
bash native/error-utils/lint.sh || exit 1

echo "== gate[3/6] roundtrip11_20 =="
python3 native/error-utils/roundtrip11_20.py || exit 1

echo "== gate[4/6] roundtrip21_30 =="
python3 native/error-utils/roundtrip21_30.py || exit 1

echo "== gate[5/6] dbtest =="
gcc -no-pie native/error-utils/dbtest.c native/db.o -o /tmp/gate-dbtest || exit 1
/tmp/gate-dbtest || exit 1

echo "== gate[6/6] uitest =="
gcc -no-pie native/error-utils/uitest.c native/ui_f2.o native/db.o native/platform_x11.o -lX11 -o /tmp/gate-uitest || exit 1
/tmp/gate-uitest || exit 1

echo "GATE OK"
