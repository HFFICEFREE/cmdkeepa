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
  21=movecoll (snippet -> próxima coll, circula até unfiled) 22=help (Ctrl+H)
  23=button-release 24=motion (arrasto: seleção de texto no código)
  25=paste pronto (SelectionNotify do XConvertSelection) 26=paste (Ctrl+V)
  27=undo (Ctrl+Z) 28=redo (Ctrl+Y): snapshot do campo em edição antes de
  cada mutação, coalescido em unidades de palavra/rajada: mesma palavra
  (mesmo campo, posição contígua, mesma classe) sempre funde, e classes
  diferentes fundem se digitadas na mesma rajada (<1s entre teclas).
  **Exceção: espaço/tab/newline são âncoras** — fundem p/ trás (ficam com a
  palavra anterior) e selam o run (`undo_run_seal`): a próxima palavra sempre
  abre unidade nova, mesmo na rajada. "ola mundo" desfaz em 2 Ctrl+Z ("mundo",
  depois "ola "), nunca tudo de uma vez; Enter segue a mesma regra.
  Delete/paste/navegação/troca de campo quebram a unidade. Digitar por cima
  de seleção substitui (não engole o char) e desfaz em 1x; trocar de campo/
  commit/cancel/begin_edit zera o histórico.
- `edit_mode`: 0=normal 1=código 2=título 3=nome de coleção 4=seletor de
  coleção **5=language 6=tags**. Modos 5/6 usam helpers genéricos
  `field_setup`/`fld_*` (rdi=base, rsi=&len dword, rdx=&cursor, ecx=cap) e
  `fld_char` p/ o char pendente (scratch morre em call). Ciclo de Tab:
  2→1→5→6→2. `language` vazia vira `plaintext` no commit. Up/Down no modo 5
  cicla `lang_tab` (slots de LANG_SLOT=16 bytes).
- **Clicar fora da coluna de detalhe encerra a edição**: com `edit_mode` em
  1/2/3/5/6/7, um clique com x<601 (sidebar, busca ou lista) chama
  `leave_edit_commit` (comita; em falha de save permanece editando) e depois
  processa o clique normalmente. O modo 4 (seletor de coleção) é exceção:
  clique na sidebar escolhe a coleção.
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
- Clipboard é snapshot: Ctrl+C copia para `clip_buf` e `SelectionRequest`
  serve esse buffer imutável; nunca aponte `clip_ptr` para `sn_recs`.
  `SelectionClear` zera `clip_len` e volta `clip_ptr` para `clip_buf`.
- Seleção de texto (código): soltar o botão ANCORA (`sel_active=1`,
  `btn_down=0` bloqueia hover no `.motion`); sem auto-cópia. Ctrl+C copia o
  trecho (`sel_copy`), Ctrl+X recorta (`sel_copy` + `sel_delete_range`,
  kind 20 no modo código), Backspace/Delete/digitar consomem via
  `sel_maybe_delete`, setas/Tab/commit/cancel/begin_edit limpam. `copy` sem
  seleção continua copiando o código inteiro.

## 5. Geometria (convenção anti-"1px errado")

- **Baseline do texto = topo da hit-box + 20** (fonte 9x15; vale p/ linhas da
  LIBRARY, coleções e lista). Texto nunca na borda da caixa.
- **Hit-box == highlight == mesma fórmula.** Mudar um exige mudar os outros
  dois (coleções já quebraram por isso — F5).
- `match_rec` combina `libsel` (0=todos 1=fav 2=unfiled 3+=coll) + query.
  `cid` vazio = unfiled; `coll_ids` são NUL-terminated; seed com `cid`
  ligado (bare run precisa filtrar — F5).
- **Código com soft wrap (`CODE_WRAP`=69 células):** linha lógica longa ocupa
  várias faixas visuais; o buffer/DB **não muda** (só desenho). Scroll,
  navegação (Up/Down lógicos), seleção (offsets absolutos) e undo continuam
  no modelo lógico; só render, caret e click passam pelas faixas via
  `wrap_rows`/`wrap_vrow`/`wrap_vrow_off` (+`wrap_cb0/cb1`, `wrap_os/oe`,
  `wrap_chunk` como tmp de render). Ao mexer no draw do código: redesenhe
  por faixa, recalcule `vs/ve` por faixa, nunca assuma 1 linha = 1 faixa e
  nunca corte sequência UTF-8 no meio (`bytecol`, não byte cru).

## 6. Filtros e estado (`filt_idx`/`filt_n`/`sel`)

- `filter_rebuild` roda a cada `ui_draw`. **Após qualquer mutação de
  `sn_count`/`qlen`/`libsel` no meio de um handler, chame `filter_rebuild`
  antes de `cur_rec`/`begin_edit`** (`.mknew` snapshotou o rec errado por
  filtro velho — F5: título com NULs, `v0` alheio).
- `draw` faz clamp de `sel/scroll`; handlers podem ser relaxados quanto a isso.
- Nos modos de edição de texto (1/2/5/6), **`begin_edit` fixa `edit_rec`** e
  todos os helpers de edição/cancel/commit/desenho usam **`resolve_rec`**.
  `cur_rec` direto só vale para o alvo inicial e para código fora da edição;
  modos 3/4 continuam com `coll_cur`/`pick_rec`.
- Mutação chama `db_snapshot` antes; se `db_save` falhar, chame `db_restore`.
  Deleções restauram e refazem o filtro; commit/rename falhado mantém o editor
  aberto para retry, sem duplicar versão. `db_save` recusa salvar em modo
  somente-leitura.

## 7. Round-trip JSON (`db.asm`)

- Writer emite as 12 chaves no shape do `parseImport` do web; `collectionId`
  vazio sai como `null` (igual ao web). `id/desc/cid` medidos por NUL
  (`strlen_cap`) — **sempre NUL-terminar**.
- `db_save` grava **no mesmo caminho carregado** (é o banco), atomicamente:
  escreve `<path>.tmp`, `fsync`, `rename`. Não existe sidecar. Toda mutação
  precisa chamar `db_save` no próprio handler (favoritar não salvava — F7).
  Se qualquer emissor atingir `FILE_MAX`, `db_save` aborta antes de escrever,
  remove o temporário e retorna `-1`; nunca renomeia JSON truncado.
- `db_load` só faz seed quando `open` retorna `ENOENT`. Arquivo existente com
  erro de abertura/leitura, oversize, JSON malformado ou import com perdas não
  é sobrescrito: `db_error`/`db_readonly` são setados, a UI abre vazia em modo
  somente-leitura e o app mostra o motivo no boot. Falha de parse/limite limpa
  o estado em memória (`db_clear_state`).
- `.seed` materializa o seed no 1º start (ids/datas estáveis entre execuções).
- IDs novos usam `P-epoch-pid-seq` (`make_sn_id`/`make_coll_id`) com checagem
  de colisão no namespace; nunca assuma que o segundo == segundo anterior.
- `\uXXXX` decodifica para UTF-8 (com pares substitutos), `U+0000` vira
  `U+FFFD`, e truncamento por limite marca `db_lossy` em vez de salvar.
- `versions[]`: até 8, `{code 4KB + at + note}`, `vnum` com cap. Validar com
  `jsoncheck.py` após todo fluxo que salva.
- Commit versiona SÓ com diff real de código (len+bytes vs backup); só
  metadados atualiza updatedAt e salva sem empurrar versão; sem diff algum
  fecha com `sem alteracoes` (fix #21). Versão guarda código CHEIO
  (VER_CODE_LEN==REC_CODE_LEN) + `note` do web; offsets via VER_AT_OFF/
  VER_NOTE_OFF, REC_SIZE derivado (fix #22). Nota `null` vira "".
- Detail somente-leitura rende código da linha 0 (`edit_mode==1` usa scroll);
  CRLF=1 terminador e CR não entra no `linelen`/render, CR solitário é
  conteúdo (fix #23/#24). Linha lang-tags usa LANG_DISP_MAX/TAGS_DISP_MAX
  no render, lt_pick e carets (fix #25).
- Criação (Ctrl+N/G) seta creating_sn/coll (índice; -1=nenhum, init único —
  BSS 0 seria índice válido!); Esc remove e avisa `criacao cancelada`;
  commit limpa a flag (fix #26). Índices estáveis: nada compacta em edit mode.
- X11: GC nulo falha o init com cleanup único (fecha display, zera handles);
  main chama shutdown no .fail (fix #27). Close exige janela+WM_PROTOCOLS+
  formato 32+DELETE (fix #28). Esc por KeySym 0xFF1B, nunca keycode (fix #29).
  Selection: property None->target, XA_STRING converte p/ Latin-1 (recusa se
  irrepresentável), claim/serve com timestamps (fix #30).
- Alinhamento/ABI (fix #19): na entrada rsp%16==8; antes de cada `call`,
  reserva líquida (pushes+subs-pops-adds) ≡8 (mod 16), i.e. rsp%16==0.
  pushes ÍMPARES dispensam sub; pushes PARES exigem `sub rsp,8` (+`add` no
  epílogo). Toda rotina preserva os callee-saved que usa (rbx,rbp,r12-r15),
  em TODAS as saídas. Convenção verificada por `roundtrip11_20.py`.
- Tags com escape (fix #11): internas `a\,b,c` (`\`->`\\`, `,`->`\,`,
  espaços verbatim, `,,`=tag vazia); `[]` e `[""]` colidem em vazio.
  Writer divide em vírgulas NÃO-escapadas com flag first-tag (r11d), nunca
  por comprimento acumulado. Seeds usam `docker,postgres` (sem espaço).
- Timestamps em ms (fix #18): `now_ms` (clock_gettime) em todo created/
  updated/exported/at/ids; `itoa` é u64 (buf≥20); `ibuf` tem 40B.
- Números (fix #14): `parse_u64` rejeita sinal/fração/expoente/continuação
  alfanumérica e overflow (via `db_parse_err`); `views` rejeita > u32.
- Chaves raiz (fix #12): `find_key_array` só aceita profundidade 1 (decoys
  aninhados/strings ignorados). Paths (fix #15): nunca mutar o arg const;
  rejeitar overlong antes de mudar estado. Temp (fix #16): `<path>.<pid>.tmp`
  com O_EXCL|O_NOFOLLOW, 0600. Rename com fsync do dir-pai (fix #17).

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
6. Novo `ev_kind`: main atualizado? máscara cobre? (`kinds 2..28`)
7. Novo desenho clicável: baseline=topo+20? hit==highlight? (3 lugares)
8. Mutação de `sn_count/qlen/libsel`: `filter_rebuild` antes do próximo uso?
9. Novo campo persistido: NUL-terminado? emitido nas 12 chaves? `jsoncheck` passa?
10. Ação destrutiva nova: 2 toques no MESMO alvo? (`arm_kind`)
11. Mutação nova: chama `db_save`? Testou reabrir o MESMO DB? (F7: favorito sumia)
    Falha de save restaura (`db_snapshot`/`db_restore`), mantém editor aberto
    no commit e não duplica versão no retry?
12. Seed coerente p/ bare run? (ids fixos; `cid` ligado às coleções)
    IDs novos únicos no mesmo segundo/processo e sem colisão com importados?
13. Campo 1-linha novo: snapshot no `begin_edit` E restore no `.e_cancel`?
14. Parse novo: chaves com `key_eq` (sem ler além de `r15`), `\uXXXX` com UTF-8,
    truncamento marcando `db_lossy` e raiz validada até o `}` final?
15. Click no título/desc usa UM helper nos dois modos; scroll tem teto
    max(filt_n-ROWS_VISIBLE,0) + visibilidade (fix #31). rec.inc tem
    LANG/DESC/TAGS_DISP_MAX + CODE_TOP_Y compartilhados (fix #25) e asserts
    de offsets derivados (fix #35).
16. Descrição é 1ª classe (fix #32): busca (strlen), detail em DESC_BASE_Y,
    modo 7 no ciclo (tab 6->7->2, Enter commita), snapshot/cancel via
    desc_len+backup, compare no commit. Código começa em CODE_TOP_Y.
    Mouse (.e_mouse) vale em 1/2/5/6/7 — sem ele, click no código com
    desc em edição era ignorado e Enter commitava em vez de newline.
17. UTF-8 (fix #33, sem XIM/Xft — adiado): poll enfileira multibyte validado;
    edição anda/apaga por sequência nos 16 caminhos; fonte exige largura 9
    ou o init falha. Sub-rotina local (`call .x`) começa com `sub rsp,8`.
    utf8_* sujam rax/rcx/rdx: NUNCA reusar esses regs após o call — recarregar
    tudo (r10/r11/r12-r14 sobrevivem). Cursor andar sem o texto mudar é o
    sintoma clássico. `desc_len` (BSS) é a célula viva da descrição.
    Ao salvar regs na pilha p/ um call: consumir rax (retorno) ANTES dos pops,
    e dar pop em reg MORTO — `pop rcx` após o call apagou min(col,len) e o
    cursor de click do código foi p/ 2*pos (NUL + `\n` fora do lugar no save).
    Harness C (`uitest.c`) compila com `-O2`: shims de teste com `call`
    escondido dentro de `asm` + locais `+r` quebram no `-O0` — o GCC mantém
    os locais na red zone e os pushes do call escondido os clobberam
    (hang/FAILs/crash no exit; o binário real, via `build.sh`, não é afetado).
18. main despacha só em poll==2 (fix #34); F1 em archive/; expose só com
    count==0 (fix #36). Portão: `gate.sh` cobre #11-36.
