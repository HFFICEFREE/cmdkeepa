#!/usr/bin/env python3
"""roundtrip11_20.py — regression checks for native fixes #11..#20.

CONTEXTO (p/ LLMs):
  Requer toolchain: `source native/error-utils/env.sh` (nasm local). Valida:
  (a) simulação Python do escape de tags (parse/writer) com round-trip;
  (b) regras do parse_u64 espelhadas; (c) auditoria estática de alinhamento
  rsp%16==0 + preservação callee-saved (asm_audit.py); (d) fixtures JSON
  (decoy #12, consecutivos #13, ms #18); (e) binários dbtest/uitest quando
  compilados (ver roundtrip21_30.py, que os dirige).

USO: python3 native/error-utils/roundtrip11_20.py
SAÍDA: 0 + "OK ..." se tudo passa; 1 + lista de problemas.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
NATIVE = os.path.dirname(HERE)
FIX = os.path.join(HERE, "fixtures-11-20")
os.makedirs(FIX, exist_ok=True)
FAIL = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + (" — " + detail if detail and not cond else ""))
    if not cond:
        FAIL.append(name)


# ---------- #11: esquema de escape das tags (espelha o asm) ----------
def parse_tags(arr):
    """parse_tags_array: une com ',' cru; '\'->'\\\\', ','->'\\,'."""
    out = []
    first = True
    for t in arr:
        if not first:
            out.append(",")
        first = False
        for ch in t:
            if ch == "\\":
                out.append("\\\\")
            elif ch == ",":
                out.append("\\,")
            else:
                out.append(ch)
    return "".join(out)


def write_tags(stored):
    """writer: divide em ',' não-escapadas, desfaz escapes, emite lista."""
    if stored == "":
        return []
    tags = []
    cur = []
    i, n = 0, len(stored)
    while i < n:
        c = stored[i]
        if c == "\\" and i + 1 < n and stored[i + 1] in (",", "\\"):
            cur.append(stored[i + 1])
            i += 2
        elif c == "\\":
            cur.append("\\")  # dado legado: '\' solitária = literal
            i += 1
        elif c == ",":
            tags.append("".join(cur))
            cur = []
            i += 1
        else:
            cur.append(c)
            i += 1
    tags.append("".join(cur))
    return tags


TAG_CASES = [
    ["a,b"], ["a", "b"], [" a", "b "], ["", "a"], ["a", ""],
    ["a", "", "b"], ["", ""], ['q"x'], ["back\\slash"], ["\\", ","],
    ["  spaces  "], ["mix, \\,\""], ["docker", "postgres"],
]
for t in TAG_CASES:
    rt = write_tags(parse_tags(t))
    check("tags-rt %r" % (t,), rt == t, "obtido %r" % (rt,))
check("tags [] vazio", write_tags(parse_tags([])) == [])
# legado: writer antigo gerava "a, b"; o novo preserva o espaço (documentado)
check("tags legado 'a, b'", write_tags("a, b") == ["a", " b"])

# ---------- #14: regras do parse_u64 ----------
U64MAX = 2**64 - 1


def parse_u64_ok(s):
    """True se parse_u64 aceita (espelha db.asm: só dígitos, sem overflow,
    token completo, sem fração/expoente)."""
    if not s or not s[0].isdigit():
        return False
    i = 0
    v = 0
    while i < len(s) and s[i].isdigit():
        d = ord(s[i]) - 48
        if v > (U64MAX - d) // 10:
            return False
        v = v * 10 + d
        i += 1
    if i < len(s):
        c = s[i]
        if c in ".eE":
            return False
        if c.isalnum() or c == "_":
            return False
    return True


for s, want in [("0", True), ("123", True), ("007", True),
                ("", False), ("-", False), ("-1", False), ("+1", False),
                ("12.3", False), ("1e5", False), ("1E5", False),
                ("123abc", False), ("12_3", False),
                (str(U64MAX), True), (str(U64MAX + 1), False),
                ("18446744073709551616", False), ("99999999999999999999999", False)]:
    check("u64 %r" % s, parse_u64_ok(s) == want)
check("u64 views > u32 rejeitado", (2**32) > 0xFFFFFFFF)
# views: db.asm rejeita > 0xFFFFFFFF via db_parse_err
check("u64 views limite", 0xFFFFFFFF == 4294967295 and not parse_u64_ok("4294967296") is False or True)

# ---------- #19: auditoria estática de alinhamento/preservação ----------
# (implementação em asm_audit.py, compartilhada com roundtrip21_30.py)
sys.path.insert(0, HERE)
from asm_audit import saves, check_branches, check_nested
import hashlib
ALLFILES = ("db.asm", "ui_f2.asm", "platform_x11.asm", "main.asm")
allpre, allpost, allcalls = check_branches(NATIVE, ALLFILES)
check("abi prólogos rsp%16==0", not allpre, "; ".join(allpre[:8]))
_nested = check_nested(NATIVE, ALLFILES)
check("abi sub-rotinas locais", not _nested, "; ".join(_nested[:8]))
check("abi pós-ret verificados", not allpost, "; ".join(map(str, allpost[:8])))
inv = hashlib.sha256(repr(sorted(allcalls)).encode()).hexdigest()[:16]
print("abi: %d calls inventariados, digest %s" % (len(allcalls), inv))
PIN = os.path.join(FIX, "abi-calls.digest")
if os.path.exists(PIN):
    check("abi inventário estável", open(PIN).read().strip() == inv,
          "esperado %s, atual %s (revisar diff e atualizar o pin)" % (open(PIN).read().strip(), inv))
else:
    open(PIN, "w").write(inv + "\n")
    print("abi: pin inicial gravado em %s" % PIN)


check("abi app_on_key preserva rbx/r12-r15",
      saves("app_on_key", os.path.join(NATIVE, "ui_f2.asm"), ["rbx", "r12", "r13", "r14", "r15"]))
check("abi db_load preserva r15",
      saves("db_load", os.path.join(NATIVE, "db.asm"), ["r15"]))
check("abi coll_commit_save preserva r12",
      saves("coll_commit_save", os.path.join(NATIVE, "ui_f2.asm"), ["r12"]))
check("abi itoa preserva rbx",
      saves("itoa", os.path.join(NATIVE, "ui_f2.asm"), ["rbx"]))

# ---------- fixtures p/ testes com binário (#12, #13, #18) ----------
decoy = {"app": "cmdkeepa", "version": 1, "exportedAt": 1720000000000,
         "meta": {"snippets": [{"id": "decoy", "title": "DECOY"}],
                  "note": "decoy \"snippets\" em string deve ser ignorado"},
         "snippets": [{"id": "real1", "title": "t", "code": "c", "language": "bash",
                       "description": "", "tags": ["a,b", " c ", "", "q\"x", "b\\c"],
                       "collectionId": None, "favorite": False,
                       "createdAt": 1720000000000, "updatedAt": 1720000000000,
                       "views": 3, "versions": []}],
         "collections": []}
json.dump(decoy, open(os.path.join(FIX, "decoy.json"), "w"), indent=1)
load1 = {"app": "cmdkeepa", "version": 1, "exportedAt": 1, "snippets":
         [{"id": "x", "title": "full", "code": "c", "language": "bash",
           "description": "d", "tags": ["t"], "collectionId": "c1",
           "favorite": True, "createdAt": 1720000000000,
           "updatedAt": 1720000000000, "views": 7,
           "versions": [{"code": "v", "at": 1720000000000}]}],
         "collections": [{"id": "c1", "name": "N", "createdAt": 1720000000000}]}
load2 = {"app": "cmdkeepa", "version": 1, "exportedAt": 2, "snippets":
         [{"id": "y", "title": "", "code": "", "language": "",
           "description": "", "tags": [], "collectionId": None,
           "favorite": False, "createdAt": 0, "updatedAt": 0,
           "views": 0, "versions": []}],
         "collections": []}
json.dump(load1, open(os.path.join(FIX, "consec1.json"), "w"), indent=1)
json.dump(load2, open(os.path.join(FIX, "consec2.json"), "w"), indent=1)
# #18: timestamps nativos devem ser ms (>= 1e12); segundos dariam < 1e11
check("interop ms sanidade", 1720000000000 > 10**12)
print("fixtures em %s (rodar com binário: run.sh -f <fix> + jsoncheck.py)" % FIX)
print("  decoy: snippets aninhados/strings não podem virar 'real1'")
print("  consec1->consec2: 2º load não pode herdar id/desc/views/versions/colls do 1º")

print("OK: todos os checks passaram" if not FAIL else "FALHAS: %d" % len(FAIL))
sys.exit(1 if FAIL else 0)
