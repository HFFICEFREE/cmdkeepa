#!/bin/bash
# crash.sh — triagem automática de crash do CmdKeepa nativo (SIGSEGV/SIGFPE/...).
#
# CONTEXTO (como um segfault real foi caçado aqui):
#   Um clique na sidebar matava o app ~2s depois, sem deixar rastro. O caminho
#   que funcionou foi: (1) `strace -f` mostrou que NENHUM ButtonPress chegava
#   e o crash vinha logo após um evento de extensão 0x84 (últimas syscalls +
#   `--- SIGSEGV {si_addr=...}`); (2) loop de `gdb -batch -ex run` COM tráfego
#   X (sem tráfego não crashava — flaky ~50%) até pegar o sinal; (3) `info
#   registers` revelou `r12=71` e `rbx` lixo em `cid_match`, i.e., o limite do
#   loop em filter_rebuild morrera num `call`. Moral: crash em ASM quase nunca
#   está onde parece — colete registradores + endereço de falha + símbolo.
#   Apport engole core dumps nesta máquina; NÃO conte com core files.
#
# USO:
#   crash.sh [-f fixture.json] [-d db.json] [-t seg] [--strace] -- [ACOES...]
#   Modo gdb (default): backtrace + registradores + si_addr + símbolo via nm.
#   Modo --strace: últimas syscalls + legenda de eventos X (só localiza a fase).
#   -f: copia a fixture p/ um DB descartável antes de rodar (o app SALVA no
#       próprio DB; sem a cópia o fixture seria mutado). Default: /tmp/crashNN.db.json
# PRÉ-REQUISITOS: gdb (modo default) ou strace (--strace); resto como run.sh.
# SAÍDA: 0 + relatório ("SEM CRASH" ou bloco com sinal+bt+regs+símbolo); 1 em erro de harness.
set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${CMDKEEPA_BIN:-$SCRIPT_DIR/../cmdkeepa}"
FIXTURE=""; DB=""; TIMEOUT=25; STRACE=0
while getopts "f:d:t:" o; do
    case "$o" in f) FIXTURE="$OPTARG";; d) DB="$OPTARG";; t) TIMEOUT="$OPTARG";; esac
done
shift $((OPTIND - 1))
[ "${1:-}" = "--strace" ] && { STRACE=1; shift; }
[ -x "$BIN" ] || { echo "crash.sh: FALHA: binário: $BIN" >&2; exit 1; }
if [ -n "$FIXTURE" ]; then
    [ -f "$FIXTURE" ] || { echo "crash.sh: FALHA: fixture: $FIXTURE" >&2; exit 1; }
    [ -n "$DB" ] || DB="$(mktemp /tmp/crashdb.XXXXXX)"
    cp "$FIXTURE" "$DB"
    echo "crash.sh: db=$DB (cópia descartável)"
fi
BN="$(basename "$BIN")"
LOG="$(mktemp /tmp/crashlog.XXXXXX)"
PID=""; GPID=""
cleanup() {
    [ -z "${GPID:-}" ] || kill -9 "$GPID" 2>/dev/null || true
    [ -z "${PID:-}" ] || kill -9 "$PID" 2>/dev/null || true
    wait 2>/dev/null || true
}
trap cleanup EXIT
pkill -9 -x "$BN" 2>/dev/null || true
sleep 1

if [ "$STRACE" = "1" ]; then
    echo "crash.sh: modo strace"
    if [ -n "$DB" ]; then strace -f -o "$LOG" "$BIN" "$DB" & else strace -f -o "$LOG" "$BIN" & fi
    PID=$!
    sleep 2
    WID="$(python3 "$SCRIPT_DIR/getwid.py")" || exit 1
    python3 "$SCRIPT_DIR/keys.py" --wid "$WID" "$@" || true
    sleep 3
    if kill -0 "$PID" 2>/dev/null; then echo "crash.sh: SEM CRASH (app vivo)"; else echo "crash.sh: APP MORTO — últimas syscalls:"; tail -n 15 "$LOG"; fi
    echo "--- legenda de eventos X (1o byte): 04=ButtonPress 0c=Expose(12) 21=ClientMessage(33) 1e=SelectionRequest(30) 15/16=Reparent(21)/Configure(22) 13=MapNotify(19); 8x = extensão"
    rm -f "$LOG"
    exit 0
fi

echo "crash.sh: modo gdb"
( timeout "$TIMEOUT" gdb -batch \
    -ex run \
    -ex bt \
    -ex 'info registers rbx rax rdx rcx rsi rdi r12 rip rsp' \
    -ex 'p $_siginfo._sifields._sigfault.si_addr' \
    --args "$BIN" ${DB:+"$DB"} >"$LOG" 2>&1 & echo $! >"$LOG.gpid" )
sleep 3
WID="$(python3 "$SCRIPT_DIR/getwid.py")" || { echo "crash.sh: app nem subiu (ver log)"; tail -n 5 "$LOG"; exit 1; }
python3 "$SCRIPT_DIR/keys.py" --wid "$WID" "$@" || true
sleep 5
if grep -q "Program received signal" "$LOG"; then
    SIG="$(grep -oE "SIG[A-Z]+" "$LOG" | head -n 1)"
    echo "crash.sh: CRASH $SIG"
    grep -E "^#[0-7] " "$LOG" | head -n 8
    grep -E "^(rbx|rax|rdx|rcx|rsi|rdi|r12|rip|rsp) " "$LOG" | head -n 10
    # gdb imprime si_addr como `$1 = (void *) 0x0`: extrai o último 0x.. da linha $1
    FAULT="$(grep -E '^\$1 = ' "$LOG" | grep -oE '0x[0-9a-f]+' | tail -n 1)"
    if [ -n "$FAULT" ]; then
        # nm lista endereços zero-padded (16 dígitos): normaliza p/ comparar como string
        FAULT_NORM="$(printf '%016x' "$((16#${FAULT#0x}))")"
        echo "crash.sh: si_addr=$FAULT símbolo mais próximo:"
        NEAR="$(nm -n "$BIN" 2>/dev/null | awk -v a="$FAULT_NORM" '$1 <= a {best=$0} END{print best}')"
        if [ -n "$NEAR" ]; then echo "  $NEAR"; else echo "  (nenhum — endereço abaixo do binário, ex. NULL)"; fi
    fi
else
    echo "crash.sh: SEM CRASH (sem sinal no log)"
fi
rm -f "$LOG" "$LOG.gpid"
