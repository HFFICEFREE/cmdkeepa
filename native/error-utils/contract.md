# Contrato do CmdKeepa nativo (NASM x86-64 + Xlib)

> Este arquivo existe porque **cada regra abaixo nasceu de
> um bug real** com segfault ou corrupção silenciosa. Não "otimize" contra ele.
> A referência de layout dos registros está em `../rec.inc`.

## 1. Registradores (ABI local, além da System V)

- **Preservados através de calls**: `rbx`, `r12–r15` e **`r11`**.
  `r11` carrega índice de loop em chamadores (foi destruído por `emit_u64` e o
  loop de `versions` saía após 1 iteração — F4).
- **Scratch livre**: `rax, rcx, rdx, rsi, rdi, r8–r10`.
- **Regra de-facto herdada**: `match_rec`/`contains_ci`/`cid_match` **não
  destroem `rbx/rcx/rdx/rsi/rdi` na prática** (`contains_ci` só lê esses).
  `filter_rebuild` depende disso p/ `rbx`/`r12`, **mas recarrega o limite do
  loop (`rcx`) a cada iteração** — porque um dia `match_rec` sujou `rcx` via
  `cid_match` e o loop correu até `r12=71` e segfaultou (F5). **Limite de loop
  nunca sobrevive a `call`: recarregue da memória.**

## 2. Campos dword vs qword (`rec.inc`)

- `TLEN/LLEN/GLEN/CLEN/FAV/VNUM/VIEWS` (+`_OFF`) são **dword**.
  `CREATED/UPDATED` são **qword**. `VIEWS` é dword (cuidado: fica entre qwords).
- **Sempre `mov eax, [...]` (ou `e..`) p/ dword.** `mov rax ← [CLEN]` lê
  `fav/id` junto (`r10d=0xffbf9935`) e já deu segfault (F4). `lint.sh` acusa.
- Vale também para **globais dword**: `ev_kind`/`ev_btn` são `resd` e ficam
  colados em `ev_char` (resb). `cmp qword [ev_kind],22` lia o último caractere
  digitado junto e o `Ctrl+H` "parava" depois de digitar/renomear (F9). Use
  `cmp dword [ev_kind],22` (ou carregue em `eax`). `lint.sh` acusa qword em
  `ev_kind`/`ev_btn` e nos campos dword do rec.
- Stores: `mov [campo], eax` / `dec dword [...]`. NUL sempre após `tlen`.

## 3. Pilha

- Entrada de proc: `rsp%16==8`. Antes de `call`, `rsp%16==0`.
- Contagem: `push rbp` + N pushes → ajuste com `sub rsp` p/ alinhar.
- Um `sub rsp,8` a mais **antes de `XNextEvent` segfaultou dentro da Xlib**
  (F0). Na dúvida, conte nos dedos no comentário (vide `platform_poll`).

## 4. Eventos X11 (`platform_x11.asm` × `main.asm` × `ui_f2.asm`)

- Janela de tamanho **fixo 1280x800** via `XSetWMNormalHints` (min=max): toda
  a UI é em coords absolutas; sem a trava, o maximize do WM esticava a janela
  e o desenho quebrava. Layout responsivo = reescrever tudo (fora de escopo).

- `platform_poll` retorna: 0=nada/ignorado, 1=sair, 2=tecla/mouse
  (`ev_kind` 2..20). `main.asm` filtra a faixa — **ao criar kind novo,
  atualize o `cmp` no main.** Kinds atuais: 2=bs 3=up 4=down 5=copy 6=save
  7=fav 8=clearq 9=enter 10=esc 11/12=setas 13=mouse 14=cria-snippet
  15/16=del-snippet 17=tab 18=cria-coll 19=renomeia-coll 20=del-coll
  21=movecoll (snippet -> próxima coll, circula até unfiled) 22=help (Ctrl+H).
- `edit_mode`: 0=normal 1=código 2=título 3=nome de coleção 4=seletor de
  coleção **5=language 6=tags**. Modos 5/6 usam helpers genéricos
  `field_setup`/`fld_*` (rdi=base, rsi=&len dword, rdx=&cursor, ecx=cap) e
  `fld_char` p/ o char pendente (scratch morre em call). Ciclo de Tab:
  2→1→5→6→2. `language` vazia vira `plaintext` no commit. Up/Down no modo 5
  cicla `lang_tab` (slots de LANG_SLOT=16 bytes).
- **`Ctrl+R` é contextual** (não deixe tecla sem efeito dependendo da seleção):
  com coleção selecionada (`libsel>=3`) renomeia; com snippet (`libsel<3`)
  abre o seletor de coleção (mesmo caminho do `Ctrl+L`). Clicar numa coleção
  no seletor atribui o snippet.
- `q_focus` é o foco da busca (independente de `edit_mode`): clique na caixa
  foca; qualquer clique fora desfoca; digitar foca; **Esc desfoca primeiro e
  só fecha o app no segundo** (não "mate" o app ao sair da busca).
- `help_open` (Ctrl+H) desenha a tabela de comandos por cima de tudo, no fim de
  `ui_draw`. Enquanto aberta, só fecha (Esc/Ctrl+H/clique) e ignora o resto.
  **A UI não ensina teclas por extenso** — só a dica "Ctrl+H ajuda" no topo; ao
  adicionar/alterar comando, atualize `help_rows` (par chave/descrição).
- Mensagens do canto inferior direito (`msg_buf`) são **efêmeras**: `msg_len` é
  zerado no topo de `app_on_key`, então qualquer ação nova apaga o texto e só
  quem quer avisar reescreve. Sem isso, "Esc de novo fecha"/"apagar? ..."
  ficavam órfãos depois de o estado armado ser cancelado.
- Indicadores de estado (`[EDITANDO]` em `edit_mode` 1/2/3/5/6, `[MOVER]` no 4)
  ficam no **canto inferior esquerdo** (16, 791) — não no topbar. O topbar só
  tem o título e a dica "Ctrl+H ajuda".
- Ações destrutivas exigem **2 toques** (igual ao Esc): `Del`/`Ctrl+D` apaga
  snippet e `Ctrl+X` apaga coleção — o 1º arma (`arm_kind`/`arm_ptr`/`arm_idx`,
  msg "apagar? ... de novo") e o 2º, **no mesmo alvo**, executa. Qualquer outro
  evento zera `arm_kind` (limpo no topo de `app_on_key` para kinds ≠ 15/16/20).
  Nunca apagar direto no primeiro toque.
- `Esc` segue o MESMO contrato (`esc_armed`): o 1º desfoca a busca se preciso e
  arma; o 2º consecutivo sai. **Qualquer evento entre eles cancela** (regra no
  topo de `app_on_key` para kinds ≠ 10). No editor, Esc cancela a edição e não
  arma a saída.
- `INPUT_MASK` precisa cobrir todo evento tratado (`ButtonPressMask` etc.).
- `XButtonEvent`: `x@64, y@68, button@84` (dwords). Wheel = botões 4/5.
- Teclas sintéticas (teste) chegam com `state=0`: sem Shift (ver `keys.py`).

## 5. Geometria (convenção anti-"1px errado")

- **Baseline do texto = topo da hit-box + 20** (fonte 9x15; vale p/ linhas da
  LIBRARY, coleções e lista). Texto nunca na borda da caixa.
- **Hit-box == highlight == mesma fórmula.** Mudar um exige mudar os outros
  dois (coleções já quebraram por isso — F5).
- `match_rec` combina `libsel` (0=todos 1=fav 2=unfiled 3+=coll) + query.
  `cid` vazio = unfiled; `coll_ids` são NUL-terminated; seed com `cid`
  ligado (bare run precisa filtrar — F5).

## 6. Filtros e estado (`filt_idx`/`filt_n`/`sel`)

- `filter_rebuild` roda a cada `ui_draw`. **Após qualquer mutação de
  `sn_count`/`qlen`/`libsel` no meio de um handler, chame `filter_rebuild`
  antes de `cur_rec`/`begin_edit`** (`.mknew` snapshotou o rec errado por
  filtro velho — F5: título com NULs, `v0` alheio).
- `draw` faz clamp de `sel/scroll`; handlers podem ser relaxados quanto a isso.

## 7. Round-trip JSON (`db.asm`)

- Writer emite as 12 chaves no shape do `parseImport` do web; `collectionId`
  vazio sai como `null` (igual ao web). `id/desc/cid` medidos por NUL
  (`strlen_cap`) — **sempre NUL-terminar**.
- `db_save` grava **no mesmo caminho carregado** (é o banco), atomicamente:
  escreve `<path>.tmp`, `fsync`, `rename`. Não existe sidecar. Toda mutação
  precisa chamar `db_save` no próprio handler (favoritar não salvava — F7).
- `.seed` materializa o seed no 1º start (ids/datas estáveis entre execuções).
- `versions[]`: até 8, `{code 2KB + at}`, `vnum` com cap. Validar com
  `jsoncheck.py` após todo fluxo que salva.

## Checklist de review (código novo)

1. Novo `call` dentro de loop: o que ele suja? Limite recarregado? (`r12=71`)
2. Label **global** (sem ponto) no meio de um proc re-escopa todos os labels
   locais seguintes (`assign_save` no meio de `app_on_key` quebrou 60+ refs —
   helpers sempre DEPOIS do `.ret` do proc).
3. Helper que assume `rbx=rec` (ex. `ensure_vis`→`line_index`) precisa
   resolver o rec sozinho (chamar `cur_rec`) ou o chamador deve setar rbx.
   Esquecer isso deu `si_addr=0x102` ao dar Enter nas tags (F8).
4. Valor em scratch (ex. char em `dl`) **não sobrevive** a helper call —
   stash na pilha/BSS antes (`coll_insert` escrevia `0x03` — F6; `.e5_ins`
   mandava `0x01` porque `al` era `ev_kind` — F8).
5. Load de campo `rec.inc`: largura certa? (`lint.sh`)
6. Novo `ev_kind`: main atualizado? máscara cobre? (`kinds 2..21`)
7. Novo desenho clicável: baseline=topo+20? hit==highlight? (3 lugares)
8. Mutação de `sn_count/qlen/libsel`: `filter_rebuild` antes do próximo uso?
9. Novo campo persistido: NUL-terminado? emitido nas 12 chaves? `jsoncheck` passa?
10. Ação destrutiva nova: 2 toques no MESMO alvo? (`arm_kind`)
11. Mutação nova: chama `db_save`? Testou reabrir o MESMO DB? (F7: favorito sumia)
12. Seed coerente p/ bare run? (ids fixos; `cid` ligado às coleções)
13. Campo 1-linha novo: snapshot no `begin_edit` E restore no `.e_cancel`?
