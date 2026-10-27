#!/usr/bin/env bash
# bundle.sh — pacote portátil: binário stripped + libs ao lado.
#
# CONTEXTO:
#   Link estático total não fecha: falta libXft.a (e harfbuzz/graphite2.a)
#   nesta máquina, e sem Xft o app perde antialiasing/UTF-8 (cai no 9x15).
#   Então o bundle leva as libs compartilhadas em ./lib e o binário é linkado
#   com RPATH `$ORIGIN/lib` (--disable-new-dtags: DT_RPATH, que também vale
#   p/ o dlopen("libXft.so.2") e é herdado pelas deps da Xft).
#
#   O que NÃO vai no pacote (e por quê):
#     - glibc (libc/libm/libpthread/libdl/librt) e ld-linux: trocar o libc
#       ao lado do binário não é suportado; fica o do sistema (>= 2.34).
#     - fontes e /etc/fonts: fontconfig usa o que existe na máquina; sem
#       fonte configurada, o app cai na core 9x15.
#     - servidor X: continua sendo necessário (ou XWayland).
#
# USO:
#   ./native/bundle.sh    # gera native/dist/cmdkeepa-linux-x86_64{,.tar.gz}
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"

name="cmdkeepa-linux-x86_64"
out="native/dist/$name"

echo "[bundle] build"
./native/build.sh

echo "[bundle] binário + libs em $out"
rm -rf "$out"
mkdir -p "$out/lib"
strip --strip-all -o "$out/cmdkeepa" native/cmdkeepa
chmod +x "$out/cmdkeepa"

# libXft não aparece no ldd do app (é dlopen); entra com a cadeia própria.
xft="$(ldconfig -p 2>/dev/null | awk '$1 == "libXft.so.2" { print $NF; exit }')"
libs="$(
    {
        ldd native/cmdkeepa
        [ -n "$xft" ] && ldd "$xft"
    } | awk '$2 == "=>" && $3 ~ /^\// { print $3 }' | sort -u
)"
# ldd numa .so lista só as deps; a própria Xft (dlopen) entra na mão.
[ -n "$xft" ] && libs="$(printf '%s\n%s\n' "$libs" "$xft" | sort -u)"

for lib in $libs; do
    base="$(basename "$lib")"
    case "$base" in
        libc.so*|libm.so*|libpthread.so*|libdl.so*|librt.so*|ld-linux*) continue ;;
    esac
    cp -L "$lib" "$out/lib/$base"
done

if [ ! -e "$out/lib/libXft.so.2" ]; then
    echo "[bundle] aviso: libXft ausente — o app cai na fonte core 9x15" >&2
fi

tar -C native/dist -czf "native/dist/$name.tar.gz" "$name"

echo "[bundle] binário: $(stat -c %s "$out/cmdkeepa") bytes, libs: $(find "$out/lib" -type f | wc -l)"
du -sh "$out" "native/dist/$name.tar.gz" | awk '{ print "[bundle] " $1 "\t" $2 }'
echo "ok: rode $out/cmdkeepa (requer glibc >= 2.34 e servidor X)."
