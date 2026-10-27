#!/usr/bin/env python3
"""roundtrip21_30.py — regression checks for native fixes #21..#30.

CONTEXTO (p/ LLMs):
  Requer toolchain (`source native/error-utils/env.sh`) e objetos montados.
  Compila e dirige os harnesses C headless (dbtest, uitest — sem X11) e confere
  conteúdo JSON exato: versões sem duplicata (#21), revisões completas + notes
  (#22), CRLF consistente (#24), lt_pick com lang longa (#25), Esc cancelando
  criação (#26). #23 (scroll) e #27-30 (X11) são cobertos por inspeção +
  smoke de boot via run.sh (init/GC/keys precisam de servidor X).

USO: python3 native/error-utils/roundtrip21_30.py   (a partir da raiz do repo)
SAÍDA: 0 + "OK ..." se tudo passa; 1 + lista de problemas.
"""
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
NATIVE = os.path.join(ROOT, "native")
EU = os.path.join(NATIVE, "error-utils")
FIX = os.path.join(EU, "fixtures-11-20")
os.makedirs(FIX, exist_ok=True)
FAIL = []


def check(name, cond, detail=""):
    print(("PASS " if cond else "FAIL ") + name + (" — " + detail if detail and not cond else ""))
    if not cond:
        FAIL.append(name)


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=ROOT)


# ---------- build harnesses ----------
r = sh("gcc -no-pie native/error-utils/dbtest.c native/db.o -o /tmp/dbtest")
check("build dbtest", r.returncode == 0, r.stderr[-500:])
r = sh("gcc -no-pie native/error-utils/uitest.c native/ui_f2.o native/db.o "
       "native/platform_x11.o -lX11 -o /tmp/uitest")
check("build uitest", r.returncode == 0, r.stderr[-500:])
with open("/tmp/rt.c", "w") as f:
    f.write('extern long db_load(const char*); extern long db_save(void);\n'
            '#include <stdio.h>\n'
            'int main(int a, char **v) {\n'
            '    long n = db_load(v[1]); long s = db_save();\n'
            '    printf("%ld %ld\\n", n, s); return 0; }\n')
r = sh("gcc -no-pie /tmp/rt.c native/db.o -o /tmp/rt")
check("build rt", r.returncode == 0, r.stderr[-500:])

# ---------- #21/#26/#24/#25 via uitest ----------
r = subprocess.run(["/tmp/uitest"], capture_output=True, text=True)
for line in r.stdout.splitlines():
    if line.startswith(("PASS", "FAIL")):
        print(("uitest " if line.startswith("PASS") else "") + line)
check("uitest exit 0", r.returncode == 0)

# ---------- #22: notes + full-size via db round-trip ----------
if not os.path.exists(os.path.join(FIX, "ver-note.json")):
    vcode = "V" * 3000
    d = {"app": "cmdkeepa", "version": 1, "exportedAt": 1, "snippets":
         [{"id": "n1", "title": "T", "code": "cur", "language": "py",
           "description": "", "tags": [], "collectionId": None, "favorite": False,
           "createdAt": 1, "updatedAt": 1, "views": 0,
           "versions": [{"code": vcode, "at": 1720000000000, "note": "web-note-αβ"}]}],
         "collections": []}
    json.dump(d, open(os.path.join(FIX, "ver-note.json"), "w"))
shutil.copy(os.path.join(FIX, "ver-note.json"), "/tmp/rt-vn.json")
out = subprocess.run(["/tmp/rt", "/tmp/rt-vn.json"], capture_output=True, text=True).stdout.strip()
s = json.load(open("/tmp/rt-vn.json"))["snippets"][0]
v = s["versions"][0]
check("22 load+save", out == "1 1", out)
check("22 vcode 3000B", len(v["code"]) == 3000, str(len(v["code"])))
check("22 note utf-8", v["note"] == "web-note-αβ", repr(v["note"]))
check("22 at", v["at"] == 1720000000000)

# ---------- #21 no-dup via save cycles (jsoncheck) ----------
shutil.copy(os.path.join(FIX, "ui-21.json"), "/tmp/rt-cyc.json")
subprocess.run(["/tmp/rt", "/tmp/rt-cyc.json"], capture_output=True)
r = subprocess.run([sys.executable, os.path.join(EU, "jsoncheck.py"),
                    os.path.join(FIX, "ui-21.json"), "/tmp/rt-cyc.json"],
                   capture_output=True, text=True)
check("jsoncheck ciclo", r.returncode == 0, r.stdout.strip()[:200])

# ---------- #23: inspeção (gate edit_mode==1 no render) ----------
src = open(os.path.join(NATIVE, "ui_f2.asm")).read()
check("23 gate edit_mode no render",
      "cmp qword [edit_mode], 1" in src and "sempre rende da linha zero" in src)

# ---------- #27-30: inspeção platform ----------
plat = open(os.path.join(NATIVE, "platform_x11.asm")).read()
check("27 GC checado", "test rax, rax\n    jz .fail" in plat and "mov [p_gc], rax" in plat)
check("27 cleanup unificado", "mov qword [p_display], 0" in plat and "XCloseDisplay wrt ..plt" in plat
      and plat.count("XCloseDisplay wrt ..plt") >= 2)
check("28 WM_PROTOCOLS", "[p_wm_protos]" in plat and "cmp dword [p_event+48], 32" in plat
      and "KEY_ESC" not in plat)
check("29 keysym Esc", "0xFF1B" in plat)
check("30 latin/prop/time", "latin_buf" in plat and "mov r14, r13" in plat
      and "[p_owntime]" in plat and "[p_evtime]" in plat)
main = open(os.path.join(NATIVE, "main.asm")).read()
check("27 main chama shutdown no fail", "platform_shutdown" in main)

print("OK: todos os checks 21-30 passaram" if not FAIL else "FALHAS: %d" % len(FAIL))
sys.exit(1 if FAIL else 0)
