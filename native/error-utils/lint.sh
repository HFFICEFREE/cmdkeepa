#!/bin/bash
# lint.sh — auditoria estática HEURÍSTICA do ASM (grep disciplinado, não prova).
#
# CONTEXTO:
#   Duas classes de bug reais nasceram de padrões visíveis no fonte:
#   (a) load 64-bit de campo dword (`mov rax,[...CLEN_OFF]` lê fav/id junto e
#       segfaulta/entope — o correto é `mov eax,...`; ver contract.md);
#       campos dword: TLEN/LLEN/GLEN/CLEN/FAV/VNUM/VIEWS (+*_OFF).
#   (b) `extern FOO` sem `global FOO` em nenhum arquivo (link quebra).
#   Este script só APONTA candidatos com arquivo:linha — humano/LLM decide.
#   LIMITAÇÕES (honestas): não entende controle de fluxo, macros, nem intenção;
#   `mov rbx,[...]` com campo qword (CREATED/UPDATED) é legítimo e NÃO é
#   acusado (a regex mira só os campos sabidamente dword). Falso-positivo ->
#   documente com comentário `; lint-ok: <motivo>` e ajuste a regex aqui.
#
# USO: lint.sh [arquivo.asm ...]   (default: ../*.asm, exceto ui_f1 legado? não — inclui tudo)
# SAÍDA: 0 se limpo (+ lista INFO de marcadores); 1 se há WARNING/erro.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$#" -gt 0 ]; then FILES="$*"; else FILES="$SCRIPT_DIR"/../*.asm; fi
FAIL=0

echo "[lint] regra dword: loads 64-bit de campos sabidamente dword"
# casa `mov rXX,[...REC_<CAMPO>_OFF]` onde rXX é reg 64-bit (r..) e o campo é dword
if grep -nE 'mov[[:space:]]+r(ax|bx|cx|dx|si|di|bp|8|9|1[0-5]),[[:space:]]*\[[^]]*REC_(TLEN|LLEN|GLEN|CLEN|FAV|VNUM|VIEWS)_OFF' $FILES; then
    echo "[lint] WARNING acima: use mov e.. (32-bit) p/ campos dword — ver contract.md" >&2
    FAIL=1
else
    echo "[lint] dword ok"
fi

echo "[lint] regra dword 2: acesso qword a global/campo dword"
# `qword [ev_kind]` / `qword [ev_btn]` / qword em campo dword do rec lê os
# bytes vizinhos (ev_char!) — foi o que quebrou o Ctrl+H após digitar (F9).
if grep -nE 'qword[[:space:]]*\[[^]]*(ev_kind|ev_btn|REC_(TLEN|LLEN|GLEN|CLEN|FAV|VNUM|VIEWS)_OFF)[[:space:]]*\]' $FILES; then
    echo "[lint] WARNING acima: campo é dword; use dword/e.. — ver contract.md" >&2
    FAIL=1
else
    echo "[lint] dword2 ok"
fi

echo "[lint] pareamento extern/global"
# Símbolos de sistema (libc/X11) valem como "resolvido no link": consulta nm -D
# das libs reais em vez de allowlist chutada (allowlist apodrece; nm não mente).
SYSLIBS="$(ldconfig -p 2>/dev/null | awk '/libX11\.so|libc\.so/{print $NF}' | sort -u)"
SYMDUMP="$(mktemp /tmp/lintsys.XXXXXX)"
if [ -n "$SYSLIBS" ] && command -v nm >/dev/null 2>&1; then
    # nm -D sufixa versão (ex. getenv@@GLIBC_2.2.5): corta no @@
    nm -D $SYSLIBS 2>/dev/null | awk '{s=$NF; sub(/@@.*/, "", s); print s}' | sort -u >"$SYMDUMP"
else
    echo "[lint] AVISO: sem ldconfig/nm — só prefixo X* é aceito como sistema" >&2
fi
EXTERNS="$(grep -h -oE 'extern [A-Za-z_][A-Za-z0-9_]*' $FILES | awk '{print $2}' | sort -u)"
for sym in $EXTERNS; do
    grep -q -E "^[[:space:]]*global $sym([[:space:]]|$)" $FILES && continue
    [ -s "$SYMDUMP" ] && grep -qx "$sym" "$SYMDUMP" && continue
    case "$sym" in X*) continue;; esac
    echo "[lint] FALHA: extern $sym sem global correspondente nem símbolo de sistema" >&2
    FAIL=1
done
rm -f "$SYMDUMP"
[ "$FAIL" = "0" ] && echo "[lint] pareamento ok"

echo "[lint] marcadores (info):"
grep -nwE 'TODO|FIXME|XXX|HACK|DEBUG|TEMP' $FILES || echo "[lint] nenhum marcador"
exit "$FAIL"
