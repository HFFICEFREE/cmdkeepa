#!/usr/bin/env python3
"""keys.py — injeta eventos X11 sintéticos no cliente CmdKeepa e tira screenshot POR ID.

CONTEXTO (armadilhas reais que este script já contorna):
  1. SEMPRE aponte para o ID explícito (--wid). Screenshot/injeção "por nome"
     capturam a janela errada quando há app fantasma (classe de problema que
     gerou os "inputs fantasmas": clique ia p/ um app, shot mostrava outro).
  2. XSendEvent NÃO precisa de foco; mas o app precisa existir e estar mapeado.
  3. Teclas sintéticas chegam com state=0 (sem Shift): 'S' vira 's' no app.
     Maiúsculas em teste são artefato do harness, não bug do app.
  4. "SPACE" envia espaço; espaços entre palavras NÃO são preservados — use
     o token SPACE (ex.: "docker , SPACE postgres"). Sem ele, "docker postgres"
     vira a palavra dockerpostgres.
  5. Cada ação tem pequeno sleep; repaints completos do app custam ~100ms.
     Não reduza os sleeps para "acelerar" — gera flakes.
  6. `import -window 0xID` falha se a janela morreu. Se falhar, o app crashou:
     use ../error-utils/crash.sh em vez de repetir o teste.
  7. CLICKS USAM XTEST, não XSendEvent: sob XWayland, ButtonPress sintético
     via SendEvent é descartado de forma intermitente (provado por strace:
     zero chegadas, sem crash). XTEST (fake_input) entra pela via confiável
     de input, como mouse real. Efeito colateral: warp_pointer MOVE o cursor
     real até a janela — não rode durante uso manual. `--send` força o modo
     antigo (útil se XTEST indisponível).
USO:
  keys.py [-s SHOT] [--wid HEXID] [--send] AÇÃO [AÇÃO ...]
  AÇÕES:
    CLICK x y [BTN n]   clique (default BTN 1=esq; 4/5=wheel cima/baixo)
    WHEELUP / WHEELDN   atalhos p/ CLICK 400 400 BTN 4/5
    CTRL+x              Control+letra (x minúsculo; ex. CTRL+S)
    DELETE TAB ENTER ESC UP DOWN LEFT RIGHT BACKSPACE HOME END
    palavra             cada char vira um KeyPress (só ASCII imprimível)
  Sem -s: só injeta, sem screenshot. Sem --wid: descobre (exige 1 app).
EXEMPLOS:
  keys.py -s a.png --wid 1600001 CLICK 100 214
  keys.py --wid 1600001 CTRL+N t e s t ENTER CTRL+S
SAÍDA: 0 + "shot: ..." (se -s) ou "done: N ações"; 1 + erro.
"""
import subprocess
import sys
import time
from Xlib import X, display
from Xlib.protocol import event

try:
    from Xlib.ext import xtest
    HAS_XTEST = True
except Exception:
    HAS_XTEST = False

SYM = {"DOWN": 0xFF54, "UP": 0xFF52, "BACKSPACE": 0xFF08, "ENTER": 0xFF0D,
       "LEFT": 0xFF51, "RIGHT": 0xFF53, "ESC": 0xFF1B, "HOME": 0xFF50,
       "END": 0xFF57, "DELETE": 0xFFFF, "TAB": 0xFF09, "SPACE": 0x0020}
CTRLMASK = X.ControlMask
KEY_SLEEP = 0.06
CLICK_SLEEP = 0.15
AFTER_SLEEP = 0.5


def parse_argv(argv):
    shot, wid, actions, send = None, None, [], False
    i = 0
    while i < len(argv):
        if argv[i] == "-s":
            i += 1
            shot = argv[i]
        elif argv[i] == "--wid":
            i += 1
            wid = int(argv[i], 16)
        elif argv[i] == "--send":
            send = True
        else:
            actions.append(argv[i])
        i += 1
    return shot, wid, actions, send


def find_client():
    d = display.Display()
    root = d.screen().root
    found = []
    stack = [(c, 0) for c in root.query_tree().children]
    while stack:
        w, depth = stack.pop()
        try:
            if w.get_wm_name() == "CmdKeepa":
                found.append((depth, w))
            for c in w.query_tree().children:
                stack.append((c, depth + 1))
        except Exception:
            pass
    assert found, "janela CmdKeepa nao encontrada"
    assert len(found) == 2, "esperava 1 frame+1 cliente (há app fantasma? `pkill -x cmdkeepa`)"
    found.sort()
    return d, root, found[-1][1]


def main():
    shot, wid, actions, force_send = parse_argv(sys.argv[1:])
    d = display.Display()
    root = d.screen().root
    if wid is None:
        d, root, w = find_client()
    else:
        w = d.create_resource_object('window', wid)
    print("usando janela id=%x" % w.id, flush=True)
    use_xtest = HAS_XTEST and not force_send
    if not use_xtest:
        print("keys.py: AVISO: clicks via XSendEvent (flaky sob XWayland)" if HAS_XTEST else
              "keys.py: AVISO: sem XTEST, clicks via XSendEvent", flush=True)

    def keypress(keycode, state=0):
        ev = event.KeyPress(detail=keycode, time=X.CurrentTime, root=root,
                            window=w, child=X.NONE, root_x=10, root_y=10,
                            event_x=10, event_y=10, state=state, same_screen=1)
        w.send_event(ev, event_mask=X.KeyPressMask)
        d.sync()
        time.sleep(KEY_SLEEP)

    def click(x, y, btn=1):
        if use_xtest:
            w.warp_pointer(x, y)
            d.sync()
            time.sleep(0.3)
            xtest.fake_input(d, X.ButtonPress, btn)
            d.sync()
            time.sleep(0.1)
            xtest.fake_input(d, X.ButtonRelease, btn)
            d.sync()
            time.sleep(CLICK_SLEEP)
            return
        ev = event.ButtonPress(detail=btn, time=X.CurrentTime, root=root,
                               window=w, child=X.NONE, root_x=x, root_y=y,
                               event_x=x, event_y=y, state=0, same_screen=1)
        w.send_event(ev, event_mask=X.ButtonPressMask)
        d.sync()
        time.sleep(CLICK_SLEEP)

    i, n = 0, 0
    while i < len(actions):
        k = actions[i]
        if k.startswith("CTRL+"):
            ch = k.split("+", 1)[1].lower()
            keypress(d.keysym_to_keycode(ord(ch)), CTRLMASK)
            time.sleep(0.1)
        elif k == "CLICK":
            x, y = int(actions[i + 1]), int(actions[i + 2])
            b = 1
            if i + 3 < len(actions) and actions[i + 3] == "BTN":
                b = int(actions[i + 4])
                i += 2
            click(x, y, b)
            i += 2
        elif k == "WHEELUP":
            click(400, 400, 4)
        elif k == "WHEELDN":
            click(400, 400, 5)
        elif k in SYM:
            keypress(d.keysym_to_keycode(SYM[k]))
        else:
            for ch in k:
                keypress(d.keysym_to_keycode(ord(ch)))
        n += 1
        i += 1

    if shot:
        time.sleep(AFTER_SLEEP)
        subprocess.run(["import", "-window", "0x%x" % w.id, shot], check=True)
        print("shot: %s" % shot)
    else:
        print("done: %d acoes (sem shot)" % n)


main()
