#!/usr/bin/env bash
# release.sh — publica o binário junto de uma tag, sem sujá-lo no dia a dia.
#
# CONTEXTO:
#   `native/cmdkeepa` é artefato (fica no .gitignore) e NÃO deve entrar no
#   main a cada build: binário velho no repo já causou confusão "não fez
#   efeito". Mas numa tag de release é útil ter o executável no snapshot.
#   Fluxo: build -> strip -> commit do binário -> tag -> commit removendo o
#   binário do índice. A tag aponta p/ o commit COM o binário; o main segue
#   sem ele. Quem baixa a tag recebe ./native/cmdkeepa pronto.
#
# USO:
#   ./native/release.sh v1.2.3            # build + commit + tag + push
#   ./native/release.sh v1.2.3 --no-push  # ensaio local (não envia nada)
#   ./native/release.sh v1.2.3 --dry-run  # só imprime o plano
# PRÉ-REQUISITOS: árvore limpa, tag inexistente, nasm+gcc no PATH (aqui:
#   source native/error-utils/env.sh), git com origin configurado.
set -euo pipefail

usage() { echo "uso: $0 vX.Y.Z [--dry-run] [--no-push]" >&2; exit 1; }

version="${1:-}"
[ -n "$version" ] || usage
shift
case "$version" in v*) tag="$version" ;; *) tag="v$version" ;; esac

dry=0
do_push=1
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry=1 ;;
        --no-push) do_push=0 ;;
        *) usage ;;
    esac
done

root="$(git rev-parse --show-toplevel)"
cd "$root"

if [ -n "$(git status --porcelain)" ]; then
    echo "erro: árvore suja — commite/stash antes do release." >&2
    git status --short >&2
    exit 1
fi

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "erro: tag $tag já existe." >&2
    exit 1
fi

echo "[release] build ($tag)"
if [ "$dry" = 0 ]; then
    ./native/portable.sh
    cp native/dist/cmdkeepa-linux-x86_64 native/cmdkeepa
fi

echo "[release] strip native/cmdkeepa"
if [ "$dry" = 0 ]; then
    strip --strip-all native/cmdkeepa
    echo "[release] $(file -b native/cmdkeepa | cut -d, -f1-2), $(stat -c %s native/cmdkeepa) bytes"
fi

if [ "$dry" = 0 ]; then
    echo "[release] commit do binário + tag $tag"
    git add -f native/cmdkeepa
    git commit -q -m "release: binário $tag (linux x86-64)"
    git tag -a "$tag" -m "CmdKeepa $tag (linux x86-64)"
    git rm -q --cached native/cmdkeepa
    git commit -q -m "chore: binário de release volta a ser artefato"
else
    echo "[dry-run] git add -f native/cmdkeepa"
    echo "[dry-run] git commit -m 'release: binário $tag (linux x86-64)'"
    echo "[dry-run] git tag -a $tag"
    echo "[dry-run] git rm --cached native/cmdkeepa && git commit (artefato)"
fi

if [ "$do_push" = 1 ] && [ "$dry" = 0 ]; then
    echo "[release] push main + $tag"
    git push origin HEAD "refs/tags/$tag"
else
    echo "[release] push ignorado ($([ "$dry" = 1 ] && echo dry-run || echo --no-push))"
fi

echo "ok: tag $tag com binário; main segue sem ele."
