# error-utils — kit de sobrevivência do CmdKeepa nativo

Ferramentas nascidas dos incidentes reais do projeto. Cada script tem bloco
de cabeçalho com contexto p/ LLMs — **leia o cabeçalho antes de usar**.

## Workflow padrão

```sh
source native/error-utils/env.sh     # 1. toolchain no PATH + checks
native/error-utils/build.sh          # 2. compila (erros por arquivo)
native/error-utils/lint.sh           # 3. auditoria heurística (dword, extern/global)
native/error-utils/run.sh -s shot.png -f fixture.json -- CLICK 100 214
                                     # 4. teste X11 robusto (1 app, shot por ID)
native/error-utils/jsoncheck.py orig.json /tmp/out.db.json
                                     # 5. valida round-trip após salvar

## Persistência (F7)

O arquivo passado em `argv[1]` (default `~/.cmdkeepa/db.json`) é **o banco**:
toda mutação (favoritar, editar/commitar, criar, apagar, mover, coleções)
grava no mesmo caminho, atomicamente (`<db>.tmp` → fsync → rename). No 1º
start o DB é criado/seeded automaticamente (ids e datas ficam estáveis).
Consequências:
- Não existe mais `<origem>.native.json`; docs/testes antigos que o citam
  estão desatualizados.
- `run.sh -f fixture` copia a fixture para `<shot>.db.json` e testa contra a
  cópia (o fixture original nunca é mutado). O caminho é impresso como `db: ...`.
- Rodar sem `-f` usa o DB REAL do usuário (`~/.cmdkeepa/db.json`) — cuidado.
```

## Mapa problema → ferramenta

| Sintoma | Ferramenta |
|---|---|
| `nasm: command not found` | `env.sh` |
| `unable to open include file rec.inc` | `build.sh` (usa `-I`) |
| Click sem efeito / shot mostra outro estado ("fantasmas") | `run.sh` (pkill `-x`, asserts, shot por ID) |
| App morre (exit 139) ou some | `crash.sh` (gdb: bt+regs+símbolo) ou `crash.sh --strace` |
| Título NUL / `v0` estranho / chave sumindo após salvar | `jsoncheck.py` |
| Suspeita de load com largura errada / símbolo faltando | `lint.sh` |
| Dúvida de convenção (regs, pilha, geometria, filtro) | `contract.md` |

## Arquivos

- `env.sh`, `build.sh`, `run.sh`, `crash.sh`, `lint.sh` (bash)
- `keys.py`, `getwid.py`, `jsoncheck.py` (python3; `keys.py` precisa de `python-xlib`)
- `contract.md` (regras que previnem as classes de bug já vistas + checklist)
- Convenciona-se: **nada de harness em `/tmp`** — o que for útil é absorvido aqui.

## Notas de ambiente (Wayland/XWayland + foco)

- Clicks vão por **XTEST** (ver `keys.py`): ButtonPress via XSendEvent é
  descartado de forma intermitente sob XWayland (strace provou zero chegadas).
  Efeito: o cursor real é movido até a janela durante o teste.
- A janela nova **rouba o foco**: não digite em outro lugar durante `run.sh`
  — keystrokes reais caem na query do app e poluem o filtro (incidentes
  "rig"/"ain"). Comece sequências sensíveis a filtro com `CTRL+U` (limpa).
- Janela morreu no meio do teste → `crash.sh`, não repetição cega.

## Notas p/ F6 (collections CRUD)

F6 usa este kit como harness oficial: `run.sh` p/ fluxos de criar/editar/deletar
coleção, `jsoncheck.py` p/ validar `collections[]` (ids referenciados existem,
`createdAt` preservado), `lint.sh` antes de cada sessão.
