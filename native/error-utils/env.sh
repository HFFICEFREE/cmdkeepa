#!/bin/bash
# env.sh — prepara e valida o ambiente p/ compilar e testar o CmdKeepa nativo.
#
# CONTEXTO (leia antes de compilar qualquer .asm):
#   Nesta máquina o `nasm` NÃO está instalado via apt (sem sudo). Existe uma
#   cópia local extraída do .deb em /tmp/opencode/nasm-local (frágil: /tmp
#   pode ser limpo; o .deb original está em /tmp/opencode/*.deb — se sumir,
#   baixe de novo com `apt download nasm` e extraia com `dpkg -x`).
#   Todo build/teste precisa desse nasm no PATH. O sintoma clássico de pular
#   este passo é `command not found: nasm` ou `erro: nasm não encontrado`.
#   Classe de problema que elimina: toolchain ausente / caminhos adivinhados.
#
# USO:
#   source native/error-utils/env.sh     # PRECISA ser sourced (exporta PATH)
#   ./native/error-utils/build.sh        # em seguida, compila
# PRÉ-REQUISITOS: bash ou zsh (sourced; o corpo é POSIX + teste portátil).
# SAÍDA: 0 se tudo ok; 1 + mensagem acionável do que falta, caso contrário.
#   Se executado em vez de sourced, valida mas avisa que o PATH não persiste.

# Candidatos conhecidos do nasm local. NOTA p/ quem edita: a lista abaixo é
# literal (um item por linha lógica) DE PROPÓSITO — este arquivo é *sourced*
# e pode rodar sob zsh, onde `$var` NÃO sofre word-splitting (diferente do
# bash); iterar string com espaço quebraria silenciosamente. Ajuste caminhos
# aqui se mudar de máquina.
_env_try_nasm() {
    # $1 = dir candidato; seta _env_nasm e exporta PATH se achar
    if [ -x "$1/nasm" ]; then
        _env_nasm="$1/nasm"
        export PATH="$1:$PATH"
        return 0
    fi
    return 1
}

_env_fail() { echo "env.sh: $1" >&2; return 1; }

_env_check() {
    local found=""
    if command -v nasm >/dev/null 2>&1; then
        found="$(command -v nasm)"
    else
        _env_try_nasm "/tmp/opencode/nasm-local/usr/bin" && found="$_env_nasm"
        [ -n "$found" ] || { _env_try_nasm "$HOME/.local/nasm/bin" && found="$_env_nasm"; }
    fi
    [ -n "$found" ] || { _env_fail "nasm não encontrado. Extraia o .deb (dpkg -x nasm_*.deb <dest>) e ajuste os candidatos em _env_try_nasm."; return 1; }
    echo "env.sh: nasm = $found ($("$found" -v 2>&1 | head -n 1))"
    command -v gcc >/dev/null 2>&1 || { _env_fail "gcc não encontrado."; return 1; }
    if command -v ldconfig >/dev/null 2>&1; then
        ldconfig -p 2>/dev/null | grep -q libX11 || echo "env.sh: AVISO: libX11 não vista no ldconfig (link pode falhar; precisa libx11-dev)." >&2
    fi
    command -v import >/dev/null 2>&1 || { _env_fail "'import' (ImageMagick) não encontrado — screenshots impossíveis."; return 1; }
    python3 -c "import Xlib" 2>/dev/null || { _env_fail "python3-xlib ausente (pip install python-xlib) — injeção de eventos impossível."; return 1; }
    [ -n "${DISPLAY:-}" ] || { _env_fail "DISPLAY vazio — sem servidor X."; return 1; }
    echo "env.sh: gcc/import/python-xlib/DISPLAY=$DISPLAY ok"
    return 0
}

# Detecção portátil de "fui sourced?": bash usa BASH_SOURCE, zsh usa
# ZSH_EVAL_CONTEXT (contém "file" quando sourced). Sem isso, sob zsh o aviso
# abaixo dispara mesmo com `source` (incidente real durante a validação).
__eu_sourced=0
if [ -n "${BASH_SOURCE:-}" ] && [ "${BASH_SOURCE[0]}" != "$0" ]; then __eu_sourced=1; fi
case "${ZSH_EVAL_CONTEXT:-}" in *file*) __eu_sourced=1;; esac
if [ "$__eu_sourced" = "0" ]; then
    echo "env.sh: AVISO: executado em vez de sourced — o PATH exportado NÃO persiste no seu shell." >&2
    echo "env.sh: use:  source native/error-utils/env.sh" >&2
fi
_env_check
