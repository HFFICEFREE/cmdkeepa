#!/bin/bash
# run.sh — harness robusto de teste X11 do CmdKeepa nativo (1 app, shot por ID).
#
# CONTEXTO (cada passo existe por um incidente real):
#   * `pkill -x` (nome exato), NUNCA `pkill -f <padrão>`: o padrão casa com a
#     cmdline do próprio shell e ele se mata (sessão travou por isso).
#   * asserts de "1 processo + getwid ok" antes de injetar: sem eles, clicks
#     iam para um app e o screenshot mostrava outro ("inputs fantasmas").
#   * screenshot POR ID (0x...), nunca por nome: com 2 apps o `import` por nome
#     captura qualquer um.
#   * tudo num único processo bash: apps de fundo morrem entre chamadas da
#     ferramenta; cada teste precisa nascer e morrer dentro deste script.
#   * trap de limpeza: aborts/timeouts deixavam apps zumbis (foi assim que
#     nasceu o "seed fantasma" de 3 snippets).
#
# USO: run.sh -s shot.png [-f fixture.json] [-d db.json] [-t seg] -- [ACOES...]
#   -s shot (obrigatório), -t timeout p/ keys.py (default 120).
#   -f fixture: copia p/ o DB de teste e roda contra ele (NÃO altera o fixture).
#      DB de teste default: <shot-sem-extensão>.db.json (impresso como "db: ...").
#   -d db: caminho explícito do DB (implica copiar fixture se -f dado).
#   Sem -f: roda "bare" (argv vazio => ~/.cmdkeepa/db.json, o DB do usuário!).
#   IMPORTANTE (F7): o app agora SALVA NO PRÓPRIO DB (persistência real), então
#   testes precisam de um DB descartável — nunca rode sem -f se for salvar.
# PRÉ-REQUISITOS: env.sh sourced (nada aqui compila, mas keys.py precisa de python-xlib).
# SAÍDA: 0 + "shot: ..." + "limpo"; 1 + motivo (FALHA/AVISO) em qualquer etapa.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${CMDKEEPA_BIN:-$SCRIPT_DIR/../cmdkeepa}"
SHOT=""; FIXTURE=""; DB=""; TIMEOUT=120
while getopts "s:f:d:t:" o; do
    case "$o" in
        s) SHOT="$OPTARG";; f) FIXTURE="$OPTARG";; d) DB="$OPTARG";; t) TIMEOUT="$OPTARG";;
    esac
done
shift $((OPTIND - 1))
[ -n "$SHOT" ] || { echo "run.sh: FALHA: -s shot obrigatório" >&2; exit 1; }
[ -x "$BIN" ] || { echo "run.sh: FALHA: binário ausente/inexecutável: $BIN" >&2; exit 1; }
[ -z "$FIXTURE" ] || [ -f "$FIXTURE" ] || { echo "run.sh: FALHA: fixture inexistente: $FIXTURE" >&2; exit 1; }
if [ -n "$FIXTURE" ]; then
    [ -n "$DB" ] || DB="${SHOT%.*}.db.json"
    rm -f "$DB"
    cp "$FIXTURE" "$DB"
    echo "run.sh: db=$DB (cópia descartável da fixture)"
fi
BN="$(basename "$BIN")"
PID=""
cleanup() { if [ -n "$PID" ]; then kill -9 "$PID" 2>/dev/null || true; wait 2>/dev/null || true; fi; }
trap cleanup EXIT

pkill -9 -x "$BN" 2>/dev/null || true
sleep 1
if pgrep -x "$BN" >/dev/null; then echo "run.sh: FALHA: processo velho sobreviveu ao pkill" >&2; exit 1; fi
if [ -n "$DB" ]; then "$BIN" "$DB" & else "$BIN" & fi
PID=$!
sleep 2
if ! kill -0 "$PID" 2>/dev/null; then echo "run.sh: FALHA: app morreu no boot" >&2; exit 1; fi
WID="$(python3 "$SCRIPT_DIR/getwid.py")" || exit 1
if [ "$(pgrep -x -c "$BN")" != "1" ]; then echo "run.sh: FALHA: != 1 app rodando" >&2; exit 1; fi
echo "run.sh: app pid=$PID wid=$WID"
timeout "$TIMEOUT" python3 "$SCRIPT_DIR/keys.py" -s "$SHOT" --wid "$WID" "$@" || exit 1
kill -9 "$PID" 2>/dev/null || true; wait 2>/dev/null || true; PID=""
sleep 0.5
pgrep -x "$BN" >/dev/null && echo "run.sh: AVISO: sobrou processo" >&2 || echo "run.sh: limpo"
echo "run.sh: fim"
