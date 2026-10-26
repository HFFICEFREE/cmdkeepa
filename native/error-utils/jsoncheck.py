#!/usr/bin/env python3
"""jsoncheck.py — valida o round-trip JSON do DB nativo (origem vs estado salvo).

CONTEXTO (p/ LLMs):
  O nativo trata o arquivo apontado por argv[1] (default ~/.cmdkeepa/db.json)
  como O BANCO: db_save grava no MESMO caminho, atomicamente (tmp+fsync+rename).
  Não existe mais sidecar `.native.json` — se você procurava um, está usando
  doc/harness velho. `run.sh -f fixture` copia a fixture p/ `<shot>.db.json`
  e roda contra a cópia; passe ESSE caminho como SALVO aqui.
  O contrato (ver contract.md) é perda-zero: mesmos snippets/coleções,
  `versions` preservadas e crescendo, `collectionId` vazio emitido como `null`
  (igual ao web). Bugs reais pegos à mão aqui: título com NULs, `v0` com
  código alheio, `createdAt` zerado, chave sumindo, mutação não persistida
  (favoritar sem salvar). Use após qualquer fluxo que salva.

USO: jsoncheck.py ORIG.json SALVO.json [--expect-count N] [--expect-colls M]
  Default: espera mesma contagem. Para criar/deletar, passe --expect-*.
SAÍDA: 0 + "OK ..." se tudo passa; 1 + lista de problemas, caso contrário.
CHECKS:
  1. ambos parseiam; 2. contagem (+colls se --expect-colls); 3. por id em
     comum: mesmo conjunto de chaves, versions não encolhe; 4. ids
     adicionados/removidos reportados (não falham); 5. todo collectionId
     não-nulo existe nas collections; 6. ids de coll únicos.
"""
import json
import sys

KEYS = {"id", "title", "code", "language", "description", "tags",
        "collectionId", "favorite", "createdAt", "updatedAt", "views", "versions"}


def load(p):
    try:
        return json.load(open(p))
    except Exception as e:
        print("FALHA: %s não parseia: %s" % (p, e))
        sys.exit(1)


def take(args, flag):
    if flag in args:
        i = args.index(flag)
        v = int(args[i + 1])
        return v, args[:i] + args[i + 2:]
    return None, args


def main():
    args = sys.argv[1:]
    exp, args = take(args, "--expect-count")
    expc, args = take(args, "--expect-colls")
    orig_p, salvo_p = args[0], args[1]
    o, s = load(orig_p), load(salvo_p)
    problems = []
    osn, ssn = {x["id"]: x for x in o["snippets"]}, {x["id"]: x for x in s["snippets"]}
    if exp is None:
        exp = len(osn)
    if len(ssn) != exp:
        problems.append("contagem: esperado %d, salvo tem %d" % (exp, len(ssn)))
    oc, sc = len(o.get("collections", [])), len(s.get("collections", []))
    if expc is not None and sc != expc:
        problems.append("coleções: esperado %d, salvo tem %d" % (expc, sc))
    for sid in sorted(set(osn) & set(ssn)):
        a, b = osn[sid], ssn[sid]
        ka, kb = set(a), set(b)
        if ka != kb:
            problems.append("id %s: chaves divergem (-%s +%s)" % (sid, sorted(ka - kb), sorted(kb - ka)))
        va, vb = len(a.get("versions", [])), len(b.get("versions", []))
        if vb < va:
            problems.append("id %s: versions encolheu %d->%d" % (sid, va, vb))
    for sid in sorted(set(ssn) - set(osn)):
        b = ssn[sid]
        if set(b) != KEYS:
            problems.append("id novo %s: chaves %s (esperado %s)" % (sid, sorted(set(b)), sorted(KEYS)))
    for sid in sorted(set(osn) - set(ssn)):
        print("info: id removido %s" % sid)
    collids = {c["id"] for c in s.get("collections", [])}
    if len(collids) != len(s.get("collections", [])):
        problems.append("ids de coleção duplicados")
    for sid, b in ssn.items():
        cid = b.get("collectionId")
        if cid is not None and cid not in collids:
            problems.append("id %s: collectionId %r sem coleção" % (sid, cid))
    if problems:
        print("FALHA:")
        for p in problems:
            print("  - %s" % p)
        sys.exit(1)
    print("OK: %d snippets, %d collections, versions ok" % (len(ssn), len(s.get("collections", []))))


main()
