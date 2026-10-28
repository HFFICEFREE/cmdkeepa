#!/usr/bin/env python3
"""asm_audit.py — auditoria estática compartilhada (fixes #19, #27-30).

Convenção: na entrada rsp%16==8; antes de cada `call`, a reserva líquida
(pushes+subs-pops-adds) deve ser ≡8 (mod 16), i.e. rsp%16==0. O scan linear
é exato p/ calls pré-ret (pares push/pop balanceados, sem ret no caminho).
Calls pós-ret (após o 1º `ret` textual) vão p/ allowlist de revisão manual.

Uso: audit(path) -> (prologue_errs, postret, calls); saves(fn,path,regs).
"""
import re

ALLOW_POSTRET = {
    ("app_on_key", None),                    # saída .quitapp (bal de prólogo)
    ("parse_tags_array", "skip_value"),      # .notarr após .ret textual
    ("platform_init", "XCloseDisplay"),      # .fail usa o mesmo frame
    ("coll_cancel", "set_msg"),           # .unmake após .out (bal de prólogo)
}


def audit(path):
    lines = open(path).read().split("\n")
    # sub-rotinas locais (`call .x`): alvos chamados
    called = set()
    cur0 = None
    for ln in lines:
        m = re.match(r"^([A-Za-z_][\w.]*):", ln)
        if m and not ln.startswith((" ", "\t")):
            cur0 = m.group(1)
            continue
        mc = re.match(r"\s*call\s+(\.[\w]+)\b", ln)
        if mc and cur0:
            called.add((cur0, mc.group(1)))
    cur, bal = None, 0
    entry_bal, have_entry = 0, False
    prologue_errs, postret, calls = [], [], set()
    seen_ret = False
    prev_sig = None  # última linha significativa (p/ fallthrough em .local)
    for i, ln in enumerate(lines):
        m = re.match(r"^([A-Za-z_][\w.]*):", ln)
        if m and not ln.startswith((" ", "\t")):
            cur, bal, seen_ret = m.group(1), 0, False
            entry_bal, have_entry = 0, False
            prev_sig = "label"
            continue
        if cur is None:
            continue
        ml = re.match(r"^(\.[\w]+):", ln)
        if ml and (cur, ml.group(1)) in called and prev_sig in ("jmp", "ret"):
            # segmento só alcançável via `call .x`: entra com bal+8
            if have_entry:
                bal = entry_bal + 8
        s = ln.strip()
        if re.match(r"pushfq", s):
            bal += 8  # pushfq empurra RFLAGS (8B em 64-bit, como push reg)
        elif re.match(r"popfq", s):
            bal -= 8
        elif re.match(r"push\s+\S+", s):
            bal += 8
        elif re.match(r"pop\s+\S+", s):
            bal -= 8
        elif re.match(r"sub\s+rsp,\s*(\d+)", s):
            bal += int(re.match(r"sub\s+rsp,\s*(\d+)", s).group(1))
        elif re.match(r"add\s+rsp,\s*(\d+)", s):
            bal -= int(re.match(r"add\s+rsp,\s*(\d+)", s).group(1))
        mc = re.match(r"call\s+(\S+)", s)
        if mc and "syscall" not in s:
            tgt = mc.group(1).split()[0]
            calls.add((cur, tgt))
            if not have_entry:
                entry_bal, have_entry = bal, True
            # bal == entry: modelo linear exato (caminhos balanceados) — checa
            # direto. bal != entry após ret: artefato ou bug — revisão manual.
            if not seen_ret or bal == entry_bal:
                if bal % 16 != 8:
                    prologue_errs.append("%s:%d %s bal=%d" % (cur, i + 1, tgt, bal))
            else:
                postret.append((cur, tgt))
        if s == "ret":
            seen_ret = True
            if have_entry:
                bal = entry_bal  # bloco pós-ret recomeça do bal de prólogo
        if s and not s.startswith(";"):
            if s.startswith("jmp "):
                prev_sig = "jmp"
            elif s == "ret":
                prev_sig = "ret"
            else:
                prev_sig = "other"
    return prologue_errs, postret, calls


def saves(fn, path, regs):
    txt = open(path).read()
    m = re.search(r"^%s:\n(.*?)(?=\n[A-Za-z_][\w.]*:\n|\Z)" % fn, txt, re.S | re.M)
    body = m.group(1) if m else ""
    return all(("push %s" % r) in body for r in regs)


def check_branches(native, files):
    """Retorna (erros_prologo, postret_nok, inventario)."""
    pre, post, inv = [], [], set()
    for f in files:
        e, p, c = audit("%s/%s" % (native, f))
        pre += ["%s: %s" % (f, x) for x in e]
        post += [(f,) + x for x in p]
        inv |= set((f,) + x for x in c)
    bad = [p for p in post
           if (p[1], None) not in ALLOW_POSTRET and (p[1], p[2]) not in ALLOW_POSTRET]
    return pre, bad, inv


def check_nested(native, files):
    """Sub-rotina local (`call .x`) entra com rsp%16==8 pelo ret-addr do call:
    seu 1º instr deve ser `sub rsp,N` com N%16==8 (fix #19). Retorna erros."""
    errs = []
    for f in files:
        lines = open("%s/%s" % (native, f)).read().split("\n")
        cur = None
        for i, ln in enumerate(lines):
            m = re.match(r"^([A-Za-z_][\w.]*):", ln)
            if m and not ln.startswith((" ", "\t")):
                cur = m.group(1)
                continue
            mc = re.match(r"\s*call\s+(\.[\w]+)\b", ln)
            if mc and cur:
                tgt = mc.group(1)
                # acha o rótulo e a 1ª instrução do segmento
                for j in range(i, len(lines)):
                    if re.match(r"^%s:" % re.escape(tgt), lines[j]):
                        k = j + 1
                        while k < len(lines) and (not lines[k].strip() or
                                                 lines[k].strip().startswith(";")):
                            k += 1
                        ms = re.match(r"sub\s+rsp,\s*(\d+)", lines[k].strip())
                        if not ms or int(ms.group(1)) % 16 != 8:
                            errs.append("%s:%s %s sem sub de entrada (linha %d)" %
                                        (f, cur, tgt, j + 1))
                        break
    return errs
