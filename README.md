# ⚡ CmdKeepa — local-first snippets

A cozy, personal snippet manager. Hosted publicly, but **your snippets never leave your browser** — everything lives in `localStorage`. No login, no backend, no database.

Think "Raycast/Obsidian for code": open, `Ctrl+K`, find `docker postgres`, copy, done.

## Run it

```bash
npm install
npm run dev      # local dev
npm run build    # production build → dist/
npm run preview  # serve the build
```

Deploy `dist/` to any static host (Vercel, Netlify, GitHub Pages, …).

## Atalhos do app nativo

O binário X11 em assembly (`native/cmdkeepa`) é operado por teclado.
Dentro do app, **`Ctrl+H`** abre esta mesma tabela.

| Tecla | Ação |
| --- | --- |
| `↑` / `↓` | Navega na lista (e no seletor de coleção) |
| `Tab` | Alterna busca → sidebar → lista |
| `Enter` | Edita o snippet (título → código → tipo → tags → descrição) |
| `Tab` | Próximo campo durante a edição |
| `Ctrl+S` | Salva no banco |
| `Ctrl+Z` / `Ctrl+Y` | Desfaz / refaz a edição (palavra a palavra: para no espaço/Enter) |
| `Ctrl+N` | Novo snippet |
| `Ctrl+G` | Nova coleção |
| `Ctrl+F` | Favorita / desfavorita |
| `Ctrl+C` | Copia o código |
| `Ctrl+V` | Cola do clipboard |
| `Ctrl+X` | Recorta a seleção; com a sidebar focada, apaga a coleção (2×) |
| `Del` / `Ctrl+D` | Apaga o snippet (2× confirma) |
| `Ctrl+U` | Limpa a busca |
| `Ctrl+L` | Move o snippet para uma coleção |
| `Ctrl+R` | Renomeia a coleção (sidebar) ou atribui o snippet |
| `Ctrl+H` | Abre esta tabela de comandos |
| `Esc` | Cancela / fecha; `Esc` de novo sai do app |

**Mouse:** arrastar no código seleciona (depois use `Ctrl+C`/`Ctrl+X`),
clicar reposiciona o cursor, e clicar fora da coluna de detalhe salva e sai
da edição.

### Banco de dados

Os dados ficam em **`~/.cmdkeepa/db.json`** (mesmo JSON v1 do export web).
Para apagar todo vestígio do app, basta apagar **`~/.cmdkeepa/`** e a pasta
deste repositório — o binário e os `.o` são artefatos, nada mais fica fora
desses dois lugares.

### Build e release

```bash
./native/build.sh              # dev: binário local (glibc do host)
./native/portable.sh           # release: compila em glibc 2.31 (Docker)
./native/release.sh v1.2.3     # portable + commit na tag + push
```

A release é **um único arquivo de ~51 KB**, sem libs para baixar: roda em
qualquer Linux x86-64 com glibc ≥ 2.31 que tenha X11 (ou XWayland) e fontes.
Xft/fontconfig/freetype são usados se existirem; sem Xft, cai na fonte core.
O binário fica fora do `main` (`.gitignore`); ele entra **só no commit da
tag** de release. Para ensaiar: `--no-push` (não envia) ou `--dry-run` (só
mostra o plano).

## Features

**Core (MVP)**
- Create / edit / delete snippets with CodeMirror (highlighting, line numbers, folding, search keymap)
- 20 languages, auto-detect + title/tag suggestions
- Global search across title, code, description, tags, language
- Tags (click to filter) + collections + favorites
- Copy (variable-rendered), dark/light cozy themes, font size, word wrap

**Beyond MVP**
- `Ctrl+K` command palette (commands + snippet jumping)
- Quick capture (`paste → save → organize later`)
- `{{variables}}` — fill values, copy ready-to-run commands
- Version history with line diff (snapshotted on every edit)
- Fork / duplicate snippets
- Serverless share links (`#/s/…` — snippet compressed into the URL)
- JS/TS runner + HTML preview
- Export / import JSON (all or per-collection), storage meter, local stats
- PWA manifest, offline-friendly static build

## Structure

```
src/
  App.tsx                  # composition + UI state only (~400 lines)
  hooks/useStore.ts        # snippets/collections/settings/theme state, persistence, CRUD
  lib/core.ts              # types, search, language detection, variables, share codec, export
  lib/codeLangs.ts         # CodeMirror language mapping
  lib/langBadge.ts         # language badge styling
  lib/clipboard.ts         # clipboard with fallback
  components/
    Sidebar.tsx            # library / collections / tags
    SnippetList.tsx        # filter + result cards
    SnippetDetail.tsx      # viewer, variables, runner, version history + diff
    EditorForm.tsx         # create/edit form (owns its draft, Ctrl+S)
    Palette.tsx            # Ctrl+K command palette
    Dialogs.tsx            # welcome, quick capture, share, incoming share, settings
    CodeEditor.tsx         # CodeMirror wrapper
    ui.tsx                 # ActionBtn, Modal primitives
```

## Data model

```json
{
  "app": "cmdkeepa",
  "version": 1,
  "snippets": [{ "id, title, code, language, description, tags[], collectionId, favorite, createdAt, updatedAt, views, versions[]" }],
  "collections": [{ "id, name, emoji, createdAt" }]
}
```

Keys: `cmdkeepa.snippets.v1`, `cmdkeepa.collections.v1`, `cmdkeepa.settings.v1`, `cmdkeepa.theme`. Back up with Export — `localStorage` is ~5 MB per origin.
