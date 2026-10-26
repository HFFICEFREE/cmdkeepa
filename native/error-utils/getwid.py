#!/usr/bin/env python3
"""getwid.py — imprime o id (hex) da janela CLIENTE do CmdKeepa.

CONTEXTO:
  Toda janela X11 do app tem 2 janelas: o frame do WM + a cliente (é na
  cliente que os eventos devem ser injetados e é ela que o screenshot por ID
  deve capturar). Ambas podem se chamar "CmdKeepa", e IDs SÃO REUTILIZADOS
  pelo servidor (ver o mesmo 0x1600001 em runs diferentes é normal).
  Este script exige EXATAMENTE 1 app (frame+cliente) e devolve a cliente
  (a mais profunda). Se falhar com "queria frame+cliente", há app fantasma:
  mate tudo com `pkill -x cmdkeepa` (NUNCA `pkill -f <padrao>` — o padrão
  casa com a cmdline do próprio shell e ele se mata; classe de problema real
  que já travou sessão aqui).

USO: getwid.py  ->  imprime ex. "1600001"
SAÍDA: 0 + id em hex; 1 + erro no stderr caso contrário.
"""
import sys
from Xlib import display

NAME = "CmdKeepa"

d = display.Display()
root = d.screen().root
found = []
stack = list(root.query_tree().children)
while stack:
    w = stack.pop()
    try:
        if w.get_wm_name() == NAME:
            # profundidade: cliente é mais funda que o frame
            depth = 0
            p = w
            while True:
                p = p.query_tree().parent
                depth += 1
                if p.id == root.id:
                    break
            found.append((depth, w.id))
        stack.extend(w.query_tree().children)
    except Exception:
        pass
if len(found) != 2:
    print("ERRO: matches=%s (queria frame+cliente; há app fantasma? `pkill -x cmdkeepa`)" % found,
          file=sys.stderr)
    sys.exit(1)
found.sort()
print("%x" % found[-1][1])
