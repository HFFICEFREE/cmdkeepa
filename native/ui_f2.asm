; ui_f2.asm — UI interativa F2: busca digitável, setas, dados do db.asm.
; Estado: query, sel, scroll, filtro. Desenho usa lens reais dos registros.
; ASCII na busca; UTF-8 do JSON passa cru (limitação conhecida F2).
default rel
%include "rec.inc"

global ui_draw
global app_on_key
; API de teste headless (harness error-utils/uitest.c; sem X11): fluxos de
; edição/commit/cancel e helpers de linha. Aditiva — não muda o app.
global edit_commit_save
global coll_commit_save
global coll_cancel
global begin_edit
global lt_pick
global linelen
global line_start
global line_index
global prev_start
global col_of_cursor
global filter_rebuild
global edit_mode
global edit_rec
global edit_backup
global backup_len
global edit_cursor
global edit_goal
global title_backup
global title_blen
global title_cursor
global lang_backup
global lang_blen
global lang_cursor
global tags_backup
global tags_blen
global tags_cursor
global desc_len
global desc_backup
global desc_blen
global desc_cursor
global coll_backup
global coll_blen
global coll_cursor
global creating_sn
global creating_coll
global code_scroll
global sel_active
global sel_a
global sel_b
global sel_rec
global sel
global scroll
global filt_n
global filt_idx
global qlen
global libsel
global match_rec
global qbuf
global utf8_step_back
global utf8_step_fwd
global wrap_rows
global wrap_vrow
global wrap_vrow_off
global fld_insert
global fld_backspace
global fld_delfwd
global fld_left
global fld_right

extern platform_fill_rect
extern platform_draw_text
extern platform_claim_clipboard
extern ev_kind
extern ev_char
extern ev_btn
extern ev_mx
extern ev_my
extern clip_ptr
extern clip_len
extern clip_buf
extern paste_buf
extern paste_len
extern platform_request_paste
extern dead_pending
extern db_save
extern db_error
extern db_readonly
extern db_snapshot
extern db_restore
extern j_memeq
extern strlen_cap
extern now_ms
extern sn_recs
extern sn_count
extern coll_names
extern coll_lens
extern coll_count
extern coll_ids
extern coll_cats

%define C_BG     0x161513
%define C_PANEL  0x1E1C1A
%define C_SEL    0x3A4534
%define C_BOX    0x1C1B19
%define C_BORDER 0x2E2A27
%define C_TEXT   0xECE7DF
%define C_DIM    0xA8A29E
%define C_ACCENT 0xC9D2C2
%define C_CODE   0xD6D0C7
%define C_ACCENT_DIM 0x55644F

%macro FILL 5
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov ecx, %4
    mov r8d, %5
    call platform_fill_rect wrt ..plt
%endmacro

%macro DTEXT 4
    mov edi, %1
    mov esi, %2
    mov edx, %3
    lea rcx, [%4]
    mov r8d, %4_len
    call platform_draw_text wrt ..plt
%endmacro

; DTEXTR x_reg32, y_reg32, color_imm, ptr_reg, len_reg32 — desenho com len runtime
%macro DTEXTR 5
    mov edi, %1
    mov esi, %2
    mov edx, %3
    mov rcx, %4
    mov r8d, %5
    call platform_draw_text wrt ..plt
%endmacro

section .data
    t_helptitle: db "Comandos"
t_helptitle_len equ $ - t_helptitle
    t_helpclose: db "Esc / Ctrl+H fecha"
t_helpclose_len equ $ - t_helpclose
    hk_up:      db "Up / Down", 0
    hd_up:      db "navega na lista (e no seletor de colecao)", 0
    hk_tab2:     db "Tab", 0
    hd_tab2:     db "alterna busca > sidebar > lista", 0
    hk_enter:   db "Enter", 0
    hd_enter:   db "edita o snippet (titulo -> codigo -> tipo -> tags)", 0
    hk_tab:     db "Tab", 0
    hd_tab:     db "proximo campo durante a edicao", 0
    hk_save:    db "Ctrl+S", 0
    hd_save:    db "salva no banco", 0
    hk_new:     db "Ctrl+N", 0
    hd_new:     db "novo snippet", 0
    hk_fav:     db "Ctrl+F", 0
    hd_fav:     db "favoritar / desfavoritar", 0
    hk_copy:    db "Ctrl+C", 0
    hd_copy:    db "copia o codigo", 0
    hk_paste:   db "Ctrl+V", 0
    hd_paste:   db "cola do clipboard", 0
    hk_undo:    db "Ctrl+Z", 0
    hd_undo:    db "desfazer edicao", 0
    hk_redo:    db "Ctrl+Y", 0
    hd_redo:    db "refazer edicao", 0
    hk_clear:   db "Ctrl+U", 0
    hd_clear:   db "limpa a busca", 0
    hk_move:    db "Ctrl+L", 0
    hd_move:    db "move o snippet p/ uma colecao", 0
    hk_newc:    db "Ctrl+G", 0
    hd_newc:    db "nova colecao", 0
    hk_renc:    db "Ctrl+R", 0
    hd_renc:    db "renomeia (sidebar) ou atribui o snippet", 0
    hk_delc:    db "Ctrl+X", 0
    hd_delc:    db "recorta selecao; sidebar: apaga colecao (2x)", 0
    hk_del:     db "Del / Ctrl+D", 0
    hd_del:     db "apaga o snippet (2x confirma)", 0
    hk_help:    db "Ctrl+H", 0
    hd_help:    db "esta tabela", 0
    hk_esc:     db "Esc", 0
    hd_esc:     db "cancela / fecha (2x sai do app)", 0
    ; pares (ptr_chave, ptr_desc), NUL-terminadas
    help_rows:
        dq hk_up, hd_up
        dq hk_tab2, hd_tab2
        dq hk_enter, hd_enter
        dq hk_tab, hd_tab
        dq hk_save, hd_save
        dq hk_new, hd_new
        dq hk_fav, hd_fav
        dq hk_copy, hd_copy
        dq hk_paste, hd_paste
        dq hk_undo, hd_undo
        dq hk_redo, hd_redo
        dq hk_clear, hd_clear
        dq hk_move, hd_move
        dq hk_newc, hd_newc
        dq hk_renc, hd_renc
        dq hk_delc, hd_delc
        dq hk_del, hd_del
        dq hk_help, hd_help
        dq hk_esc, hd_esc
    help_rows_end:
    m_blur:    db "Esc de novo fecha"
m_blur_len equ $ - m_blur
    t_edittag: db "[EDITANDO]"
t_edittag_len equ $ - t_edittag
    t_library: db "LIBRARY"
t_library_len equ $ - t_library
    t_all:     db "All snippets"
t_all_len equ $ - t_all
    t_fav:     db "Favorites"
t_fav_len equ $ - t_fav
    t_unfiled: db "Unfiled"
t_unfiled_len equ $ - t_unfiled
    t_colls:   db "COLLECTIONS"
t_colls_len equ $ - t_colls
    t_c1:      db "dotfiles"
t_c1_len equ $ - t_c1
    t_c2:      db "docker"
t_c2_len equ $ - t_c2
    t_c3:      db "sql"
t_c3_len equ $ - t_c3
    t_search:  db "Search snippets..."
t_search_len equ $ - t_search
    t_sep:     db " - "
t_sep_len equ $ - t_sep
    t_desc:    db "desc: "
t_desc_len equ $ - t_desc
    t_nomatch: db "No matches"
t_nomatch_len equ $ - t_nomatch
    ; dicas contextuais do estado vazio, centralizadas na coluna (241..600):
    t_emptyclear: db "Ctrl+U limpa a busca"
t_emptyclear_len equ $ - t_emptyclear   ; 20ch -> x330
    t_emptynew: db "Ctrl+N novo snippet"
t_emptynew_len equ $ - t_emptynew       ; 19ch -> x334
    t_favtag:  db " - fav"
t_favtag_len equ $ - t_favtag
    t_star:    db "*"
t_star_len equ $ - t_star
    m_copied:  db "copiado: "
m_copied_len equ $ - m_copied
    m_busy:    db "clipboard ocupado"
m_busy_len equ $ - m_busy
    m_nothing: db "nada p/ copiar"
m_nothing_len equ $ - m_nothing
    m_pasted:  db "colado: "
m_pasted_len equ $ - m_pasted
    m_pempty:  db "nada p/ colar"
m_pempty_len equ $ - m_pempty
    m_cut:     db "recortado: "
m_cut_len equ $ - m_cut
    m_saved:   db "salvo "
m_saved_len equ $ - m_saved
    m_fail:    db "falha ao salvar"
m_fail_len equ $ - m_fail
    m_dberr1:  db "db ilegivel na abertura: original preservado (somente leitura)"
m_dberr1_len equ $ - m_dberr1
    m_dberr2:  db "db ilegivel na leitura: original preservado (somente leitura)"
m_dberr2_len equ $ - m_dberr2
    m_dberr3:  db "db excede 1 MiB: original preservado (somente leitura)"
m_dberr3_len equ $ - m_dberr3
    m_dberr4:  db "db com JSON invalido: original preservado (somente leitura)"
m_dberr4_len equ $ - m_dberr4
    m_dberr5:  db "db excede limites nativos: original preservado (somente leitura)"
m_dberr5_len equ $ - m_dberr5
    m_dberr6:  db "save inicial falhou: seed em memoria (somente leitura)"
m_dberr6_len equ $ - m_dberr6
    m_favon:   db "fav: "
m_favon_len equ $ - m_favon
    m_favoff:  db "unfav: "
m_favoff_len equ $ - m_favoff
    m_cancel:  db "edicao cancelada"
m_cancel_len equ $ - m_cancel
    m_unmade:  db "criacao cancelada"
m_unmade_len equ $ - m_unmade
    m_nochange: db "sem alteracoes"
m_nochange_len equ $ - m_nochange
    m_full:    db "limite 4KB"
m_full_len equ $ - m_full
    m_maxsn:   db "limite 64 snippets"
m_maxsn_len equ $ - m_maxsn
    m_new:     db "novo: digite o titulo, Enter vai p/ codigo"
m_new_len equ $ - m_new
    m_created: db "criado: "
m_created_len equ $ - m_created
    m_deleted: db "apagado: "
m_deleted_len equ $ - m_deleted
    m_delarm:  db "apagar? Del de novo: "
m_delarm_len equ $ - m_delarm
    m_delcarm: db "apagar colecao? X de novo: "
m_delcarm_len equ $ - m_delcarm
    m_notitle: db "titulo cheio"
m_notitle_len equ $ - m_notitle
    m_fieldfull: db "campo cheio"
m_fieldfull_len equ $ - m_fieldfull
    m_collnew: db "nova colecao: digite o nome, Enter salva"
m_collnew_len equ $ - m_collnew
    m_collmax: db "limite 16 colecoes"
m_collmax_len equ $ - m_collmax
    m_colldel: db "colecao apagada: "
m_colldel_len equ $ - m_colldel
    m_nocoll:  db "selecione uma colecao"
m_nocoll_len equ $ - m_nocoll
    m_norec:   db "selecione um snippet"
m_norec_len equ $ - m_norec
    m_collfull: db "nome cheio"
m_collfull_len equ $ - m_collfull
    m_undo:    db "desfeito"
m_undo_len equ $ - m_undo
    m_redo:    db "refeito"
m_redo_len equ $ - m_redo
    m_noundo:  db "nada a desfazer"
m_noundo_len equ $ - m_noundo
    m_noredo:  db "nada a refazer"
m_noredo_len equ $ - m_noredo
    m_moved:   db "movido p/ "
m_moved_len equ $ - m_moved
    m_unfiled2: db "sem colecao"
m_unfiled2_len equ $ - m_unfiled2
    m_nocolls: db "sem colecoes (Ctrl+G cria)"
m_nocolls_len equ $ - m_nocolls
    t_picktag: db "[MOVER]"
t_picktag_len equ $ - t_picktag
    t_movehint: db "Up/Down escolhe a colecao - Enter confirma - Esc cancela"
t_movehint_len equ $ - t_movehint   ; picker via Ctrl+L (setas)
    t_movehint_mouse: db "clique na colecao destino - Esc cancela"
t_movehint_mouse_len equ $ - t_movehint_mouse ; picker via Ctrl+R (mouse)
    t_plain:   db "plaintext"
t_plain_len equ $ - t_plain
    ; tabela de tipos p/ o seletor Up/Down no campo language (slots fixos de
    ; LANG_SLOT bytes, NUL-terminados). Adicionar entrada = 1 linha aqui.
LANG_SLOT equ 16
%macro LANGENT 1
%%l:
    db %1, 0
    times LANG_SLOT - ($ - %%l) db 0
%endmacro
lang_tab:
    LANGENT "plaintext"
    LANGENT "bash"
    LANGENT "sh"
    LANGENT "zsh"
    LANGENT "fish"
    LANGENT "python"
    LANGENT "javascript"
    LANGENT "typescript"
    LANGENT "jsx"
    LANGENT "tsx"
    LANGENT "go"
    LANGENT "rust"
    LANGENT "java"
    LANGENT "c"
    LANGENT "cpp"
    LANGENT "sql"
    LANGENT "jq"
    LANGENT "yaml"
    LANGENT "json"
    LANGENT "toml"
    LANGENT "html"
    LANGENT "css"
    LANGENT "markdown"
    LANGENT "dockerfile"
    LANGENT "makefile"
    LANGENT "lua"
    LANGENT "php"
    LANGENT "ruby"
    LANGENT "awk"
    LANGENT "sed"
lang_tab_end:
LANG_COUNT equ (lang_tab_end - lang_tab) / LANG_SLOT
    t_cnew:    db "Nova colecao"
t_cnew_len equ $ - t_cnew
    sp_byte:   db " "
; undo/redo de edição (Ctrl+Z / Ctrl+Y): snapshot por campo antes de cada
; mutação. Entrada = id(8) + len(8) + cursor(8) + bytes do campo (4096).
UNDO_DEPTH equ 32
UNDO_BYTES equ 4096
UNDO_ENTRY equ 24 + UNDO_BYTES
UNDO_BURST_MS equ 1000             ; rajada: teclas <1s fundem mesmo entre classes
                                          ; (menos após fronteira selada: espaço/tab/newline)
UE_FIELD equ 0
UE_LEN equ 8
UE_CURSOR equ 16
UE_BYTES equ 24

section .bss
    qbuf:     resb 128
    qlen:     resq 1
    sel:      resq 1
    scroll:   resq 1
    filt_idx: resb MAX_SNIPPETS
    filt_n:   resq 1
    ibuf:     resb 40             ; ids "n-<ms>-<pid>-<seq>" (ms=13 dígitos)
    msg_buf:  resb 128
    msg_len:  resq 1
    edit_mode: resq 1            ; 0=normal, 1=editando código, 2=título, 3=nome de coleção
    edit_cursor: resq 1          ; índice no code
    edit_goal: resq 1            ; coluna preferida (Up/Down)
    edit_backup: resb REC_CODE_LEN
    backup_len: resq 1
    code_scroll: resq 1          ; primeira linha visível do detail
    libsel: resq 1              ; 0=todos 1=fav 2=unfiled 3+=coleção
    title_cursor: resq 1        ; índice no title (modo 2)
    title_backup: resb REC_TITLE_LEN
    title_blen: resq 1
    lang_cursor: resq 1         ; índice no language (modo 5)
    lang_backup: resb REC_LANG_LEN
    lang_blen: resq 1
    tags_cursor: resq 1         ; índice em tags "a, b" (modo 6)
    tags_backup: resb REC_TAGS_LEN
    tags_blen: resq 1
    desc_len: resd 1              ; len viva da descrição (sem célula no rec #32)
    desc_blen: resq 1
    desc_backup: resb REC_DESC_LEN
    desc_cursor: resq 1           ; índice na descrição (modo 7)
    fld_char: resb 1            ; char pendente p/ inserção em campo 1-linha
    click_col: resq 1           ; coluna calculada do click (lang/tags)
    q_focus: resq 1             ; 1 = busca com foco (borda+caret, Esc sai)
    arm_kind: resq 1            ; 0=nenhum 1=snippet 2=coleção (confirmação)
    arm_ptr: resq 1             ; rec armado (snippet)
    arm_idx: resq 1             ; índice k armado (coleção)
    esc_armed: resq 1           ; 1 = 1º Esc já dado (2º consecutivo sai)
    help_open: resq 1           ; 1 = tabela de comandos (Ctrl+H) aberta
    del_title: resb 40           ; título do rec apagado (p/ msg pós-save)
    del_tlen: resq 1
    coll_cursor: resq 1         ; índice no nome da coll (modo 3)
    coll_backup: resb COLL_NAME_LEN
    coll_blen: resq 1
    delc_name: resb 40           ; nome da coll apagada (p/ msg pós-save)
    delc_len: resq 1
    delc_id: resb COLL_ID_LEN    ; id da coll apagada (p/ unfile snippets)
    mv_k: resq 1                ; índice destino do assign (-1 = unfiled)
    pick_sel: resq 1            ; cursor do seletor (0=unfiled, 1+k=coll k)
    pick_rec: resq 1            ; rec alvo do seletor (estável: sem mutação no modo 4)
    edit_rec: resq 1            ; rec fixo durante edição 1/2/5/6 (não segue o filtro)
    creating_sn: resq 1         ; índice do snippet em criação, -1 = nenhum (#26)
    creating_coll: resq 1       ; índice da coleção em criação, -1 = nenhuma (#26)
    ui_init_done: resq 1        ; 1 = BSS de criação já inicializado p/ -1
    boot_err_done: resq 1       ; 1 = mensagem de db_load ilegível já exibida
    id_seq: resq 1              ; contador para IDs únicos dentro do processo
    id_tmp: resb 64             ; candidato a ID antes da checagem de colisão
    sel_active: resq 1         ; 1 = arrasto de seleção no código (F4)
    btn_down: resq 1           ; 1 = botão 1 pressionado (motion só vale em arrasto)
    sel_a: resq 1              ; âncora (offset absoluto no code)
    sel_b: resq 1              ; ponta viva (offset absoluto no code)
    sel_rec: resq 1            ; rec da seleção (só rende/lê nele)
    sel_o1: resd 1             ; tmp de render: início clampado na linha
    sel_o2: resd 1             ; tmp de render: fim clampado na linha
    wrap_os: resd 1            ; tmp de render: sel início (bytes, rel. à linha)
    wrap_oe: resd 1            ; tmp de render: sel fim (bytes, rel. à linha)
    wrap_cb0: resd 1           ; tmp de render: início da faixa (bytes, rel. à linha)
    wrap_cb1: resd 1           ; tmp de render: fim da faixa (bytes, rel. à linha)
    wrap_chunk: resq 1         ; tmp de render: índice da faixa atual
    side_focus: resq 1        ; 1 = sidebar com foco de teclado (Tab; setas movem libsel)
    pick_mouse: resq 1        ; 1 = seletor aberto via Ctrl+R (hint de mouse)
    undo_n: resq 1            ; entradas válidas em undo_buf (Ctrl+Z)
    redo_n: resq 1            ; entradas válidas em redo_buf (Ctrl+Y)
    undo_hold: resq 1         ; 1 = paste em andamento: helpers não empurram
    undo_run: resq 1          ; 1 = run de digitação aberto (mesma palavra)
    undo_run_field: resq 1    ; campo do run
    undo_run_end: resq 1      ; próxima posição esperada (byte offset)
    undo_run_class: resq 1    ; classe do run (1=word, 0=outro)
    undo_run_time: resq 1     ; ms da última tecla do run (rajada)
    undo_run_seal: resq 1     ; 1 = run termina em fronteira (espaço/tab/newline):
                              ; a próxima palavra abre unidade nova (âncora Ctrl+Z)
    undo_skip: resq 1         ; 1 = próximo insert consome sem push (replace)
    undo_tmp: resb UNDO_ENTRY ; slot de captura/comparação
    undo_buf: resb UNDO_DEPTH*UNDO_ENTRY
    redo_buf: resb UNDO_DEPTH*UNDO_ENTRY

section .text

; ---------- entrada ----------

; int app_on_key(void) — eax 1 = sair, 0 = continuar
; Preserva rbx,r12-r15 (callee-saved, fix #19): usa rbx (rec) e r12 (contadores)
; em todos os handlers. 6 pushes (par) + sub 8: entrada rsp%16==8 -> 0, calls ok.
app_on_key:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    ; mensagens do canto inferior direito valem SÓ para o evento atual: ao
    ; "resetar" um estado (Esc armado, Del armado, edição), o texto de ajuda
    ; não pode ficar órfão na tela. Handlers que querem avisar re-setam abaixo.
    ; Exceção (F4): no modo mover (4) a orientação persiste enquanto o modo
    ; durar — commit/cancel sobrescrevem a msg na saída.
    cmp qword [edit_mode], 4
    je .msgkeep
    mov qword [msg_len], 0
.msgkeep:
    cmp qword [boot_err_done], 0
    jne .bootshown
    mov rax, [db_error]
    test rax, rax
    jz .bootshown
    cmp rax, 1
    je .berr1
    cmp rax, 2
    je .berr2
    cmp rax, 3
    je .berr3
    cmp rax, 4
    je .berr4
    cmp rax, 5
    je .berr5
    lea rsi, [m_dberr6]
    mov edx, m_dberr6_len
    jmp .berrshow
.berr1:
    lea rsi, [m_dberr1]
    mov edx, m_dberr1_len
    jmp .berrshow
.berr2:
    lea rsi, [m_dberr2]
    mov edx, m_dberr2_len
    jmp .berrshow
.berr3:
    lea rsi, [m_dberr3]
    mov edx, m_dberr3_len
    jmp .berrshow
.berr4:
    lea rsi, [m_dberr4]
    mov edx, m_dberr4_len
    jmp .berrshow
.berr5:
    lea rsi, [m_dberr5]
    mov edx, m_dberr5_len
.berrshow:
    call set_msg
    mov qword [boot_err_done], 1
.bootshown:
    ; BSS nasce zerado mas "nenhuma criação" é -1 (0 = índice válido!): init único
    cmp qword [ui_init_done], 0
    jne .inited
    mov qword [creating_sn], -1
    mov qword [creating_coll], -1
    mov qword [ui_init_done], 1
.inited:
    ; confirmação de apagar expira em QUALQUER evento que não seja delete
    ; (15/16 = snippet via Del/Ctrl+D, 20 = coleção via Ctrl+X). Assim o 2o
    ; toque precisa ser imediato e no mesmo alvo.
    mov eax, [ev_kind]
    cmp eax, 15
    je .armkeep
    cmp eax, 16
    je .armkeep
    cmp eax, 20
    je .armkeep
    mov qword [arm_kind], 0
.armkeep:
    ; mesma regra p/ o Esc: só o Esc consecutivo sai
    cmp eax, 10
    je .esckeep
    mov qword [esc_armed], 0
.esckeep:
    ; seleção do mouse (F4): navegação (setas/Esc) limpa; edição, cópia,
    ; cola, press/release/motion preservam — o handler consome ou limpa.
    cmp eax, 3
    je .selclr
    cmp eax, 4
    je .selclr
    cmp eax, 10
    je .selclr
    cmp eax, 11
    je .selclr
    cmp eax, 12
    je .selclr
    jmp .selkeep
.selclr:
    mov qword [sel_active], 0
.selkeep:
    ; tecla morta pendente (F4): só uma imprimível (kind 1) a consome;
    ; qualquer outra ação (seta, Esc, clique etc.) a descarta.
    cmp eax, 1
    je .deadkeep
    mov dword [dead_pending], 0
.deadkeep:
    ; tabela de comandos (Ctrl+H): enquanto aberta, só fecha (Esc/Ctrl+H/clique)
    cmp qword [help_open], 0
    je .help_closed
    mov eax, [ev_kind]
    cmp eax, 10
    je .help_close
    cmp eax, 22
    je .help_close
    cmp eax, 13
    je .help_close
    jmp .ret
.help_close:
    mov qword [help_open], 0
    jmp .ret
.help_closed:
    ; ev_kind é DWORD (resd) e ev_char vem logo depois: um `cmp qword
    ; [ev_kind],22` lê o char digitado junto e a comparação falha sempre que
    ; qualquer tecla imprimível anterior deixou ev_char != 0 (bug do Ctrl+H
    ; parar depois de digitar/renomear). Sempre `cmp dword`/eax p/ ev_*.
    cmp dword [ev_kind], 22
    jne .help_noopen
    mov qword [help_open], 1
    mov qword [q_focus], 0
    mov qword [arm_kind], 0
    mov qword [esc_armed], 0
    jmp .ret
.help_noopen:
    mov eax, [ev_kind]
    cmp eax, 23
    je .release
    cmp eax, 24
    je .motion
    cmp eax, 25
    je .paste_ready
    ; clique fora da coluna de detalhe (sidebar ou lista) encerra a edição:
    ; comita (não perde o que foi digitado) e segue o fluxo normal de clique,
    ; que seleciona o item clicado. Se o save falhar, permanece editando.
    ; O seletor de coleção (modo 4) fica de fora: clicar na sidebar é como se
    ; escolhe a coleção.
    cmp qword [edit_mode], 0
    je .not_outside
    cmp qword [edit_mode], 4
    je .not_outside
    cmp dword [ev_kind], 13
    jne .not_outside
    cmp dword [ev_mx], 601
    jae .not_outside
    call leave_edit_commit
    cmp qword [edit_mode], 0
    jne .ret
    jmp .mouse
.not_outside:
    cmp qword [edit_mode], 0
    jne .edit
    mov eax, [ev_kind]
    cmp eax, 1
    je .print
    cmp eax, 2
    je .back
    cmp eax, 3
    je .up
    cmp eax, 4
    je .down
    cmp eax, 5
    je .copy
    cmp eax, 26
    je .paste_req
    cmp eax, 6
    je .save
    cmp eax, 7
    je .fav
    cmp eax, 8
    je .clearq
    cmp eax, 9
    je .enter_edit
    cmp eax, 10
    je .quit
    cmp eax, 13
    je .mouse
    cmp eax, 14
    je .mknew
    cmp eax, 15
    je .del
    cmp eax, 16
    je .del
    cmp eax, 17
    je .tabfocus
    cmp eax, 18
    je .mkcoll
    cmp eax, 19
    je .rencoll
    cmp eax, 20
    je .delcoll
    cmp eax, 21
    je .movecoll
    cmp eax, 23
    je .release
    cmp eax, 24
    je .motion
    jmp .cont0
.print:
    mov qword [q_focus], 1          ; digitar mantém a busca focada (caret visível)
    mov qword [side_focus], 0       ; digitar volta o foco p/ busca+lista
    mov rax, [qlen]
    cmp rax, QUERY_MAX
    jae .ret
    mov cl, [ev_char]
    mov [qbuf+rax], cl
    inc rax
    mov [qlen], rax
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.back:
    mov qword [side_focus], 0
    mov rax, [qlen]
    test rax, rax
    jz .ret
    dec rax
    mov [qlen], rax
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.up:
    cmp qword [side_focus], 0
    jne .up_side
    mov rax, [sel]
    test rax, rax
    jz .ret
    dec rax
    mov [sel], rax
    jmp .ret
.up_side:
    mov rax, [libsel]
    test rax, rax
    jz .ret
    dec rax
    mov [libsel], rax
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.down:
    cmp qword [side_focus], 0
    jne .down_side
    mov rax, [sel]
    inc rax
    mov [sel], rax
    jmp .ret
.down_side:
    mov rax, [libsel]
    mov rdx, [coll_count]
    add rdx, 2                        ; teto: 0=all,1=fav,2=unfiled,3+=colls
    cmp rax, rdx
    jae .ret
    inc rax
    mov [libsel], rax
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.tabfocus:
    ; Tab alterna o foco: lista -> busca -> sidebar -> lista ...
    cmp qword [q_focus], 0
    je .tab_list
    mov qword [q_focus], 0
    mov qword [side_focus], 1
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.tab_list:
    cmp qword [side_focus], 0
    je .tab_search
    mov qword [side_focus], 0
    jmp .ret
.tab_search:
    mov qword [q_focus], 1
    mov qword [sel], 0
    jmp .ret
.clearq:
    mov qword [side_focus], 0
    mov qword [qlen], 0
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.copy:
    cmp qword [filt_n], 0
    jne .hascopy
    lea rsi, [m_nothing]
    mov edx, m_nothing_len
    call set_msg
    jmp .ret
.hascopy:
    call resolve_rec
    test eax, eax
    jz .copynone
    ; seleção ativa no código? copia o trecho (não o código inteiro)
    cmp qword [edit_mode], 1
    jne .copywhole
    cmp qword [sel_active], 0
    je .copywhole
    cmp rbx, [sel_rec]
    jne .copywhole
    call sel_copy
    cmp eax, 0
    jg .copysel
    jl .copybusy
    jmp .copywhole
.copysel:
    lea rsi, [m_copied]
    mov edx, m_copied_len
    call set_msg
    mov eax, [clip_len]
    lea rdi, [ibuf]
    call itoa                       ; "copiado: N" como feedback
    lea rsi, [ibuf]
    mov edx, eax
    call append_msg
    jmp .ret
.copywhole:
    mov eax, [rbx+REC_CLEN_OFF]
    cmp eax, REC_CODE_LEN - 1
    jbe .copyok
    mov eax, REC_CODE_LEN - 1
.copyok:
    mov [clip_len], eax
    lea rsi, [rbx+REC_CODE_OFF]
    lea rdi, [clip_buf]
    mov ecx, eax
    rep movsb
    lea rax, [clip_buf]
    mov [clip_ptr], rax
    call platform_claim_clipboard wrt ..plt
    test eax, eax
    jz .copybusy
    lea rsi, [m_copied]
    mov edx, m_copied_len
    call set_msg
    call append_title
    jmp .ret
.copybusy:
    lea rsi, [m_busy]
    mov edx, m_busy_len
    call set_msg
    jmp .ret
.copynone:
    lea rsi, [m_nothing]
    mov edx, m_nothing_len
    call set_msg
    jmp .ret
.save:
    call do_save
    jmp .ret
.fav:
    cmp qword [filt_n], 0
    je .ret
    mov rax, [sel]
    movzx eax, byte [filt_idx+rax]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    call db_snapshot wrt ..plt
    xor byte [rbx+REC_FAV_OFF], 1
    ; persiste na hora: favoritar é mutação de DB (antes ficava só em memória
    ; e sumia ao fechar — mesmo buraco do sidecar, mas por handler)
    call db_save wrt ..plt
    cmp rax, 0
    jl .favfail
    cmp byte [rbx+REC_FAV_OFF], 0
    je .favoff
    lea rsi, [m_favon]
    mov edx, m_favon_len
    call set_msg
    call append_title
    jmp .ret
.favoff:
    lea rsi, [m_favoff]
    mov edx, m_favoff_len
    call set_msg
    call append_title
    jmp .ret
.favfail:
    call db_restore wrt ..plt
    lea rsi, [m_fail]
    mov edx, m_fail_len
    call set_msg
    jmp .ret
.enter_edit:
    mov edi, 1
    call begin_edit
    test eax, eax
    jz .cont0
    jmp .ret
.quit:
    ; Esc também é confirmação em 2 toques, com o MESMO contrato do Del:
    ; o 1º arma (e desfoca a busca), o 2º — sem nenhuma ação no meio — sai.
    ; Qualquer evento entre eles zera esc_armed (regra no topo de app_on_key).
    cmp qword [esc_armed], 0
    jne .quitapp
    mov qword [q_focus], 0
    mov qword [side_focus], 0
    mov qword [esc_armed], 1
    lea rsi, [m_blur]
    mov edx, m_blur_len
    call set_msg
    jmp .ret
.quitapp:
    mov qword [esc_armed], 0
    mov eax, 1
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
; .release/.motion (F4): soltura ancora a seleção (sem copiar) e motion
; estende — a cópia/recorte/apagar vêm depois, por tecla (Ctrl+C / Ctrl+X /
; Backspace/Delete). Válidos em qualquer modo de edição do código; ignorados
; sem arrasto ativo ou sem botão pressionado (hover não estende).
; Preservam rbx (chamador ui_draw depende disso via .ret).
.release:
    mov qword [btn_down], 0
    cmp qword [sel_active], 0
    je .ret
    call click_to_cursor            ; cursor = ponto de soltura
    mov rax, [edit_cursor]
    mov [sel_b], rax
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [sel_a]
    cmp rax, [sel_b]
    jne .ret                        ; mantém a seleção p/ Ctrl+C/X/Del
    mov qword [sel_active], 0       ; clique simples (sem arrasto): sem seleção
    jmp .ret
.motion:
    cmp qword [btn_down], 0
    je .ret                         ; hover (sem botão): não estende
    cmp qword [sel_active], 0
    je .ret
    call click_to_cursor            ; cursor segue o arrasto
    mov rax, [edit_cursor]
    mov [sel_b], rax
    jmp .ret
; .paste_req (kind 26 = Ctrl+V): pede o CLIPBOARD ao platform; se os bytes já
; estão prontos insere na hora, se vieram de fora o kind 25 insere ao chegar.
.paste_req:
    call platform_request_paste wrt ..plt
    cmp eax, 0
    jg .paste_got
    je .paste_empty
    jmp .ret                        ; -1: pedido enviado; 25 insere depois
.paste_empty:
    lea rsi, [m_pempty]
    mov edx, m_pempty_len
    call set_msg
    jmp .ret
.paste_got:
    call paste_insert
    jmp .ret
; .paste_ready (kind 25): o dono externo respondeu; insere no alvo atual.
.paste_ready:
    cmp dword [paste_len], 0
    je .ret
    call paste_insert
    jmp .ret
.mouse:
    mov eax, [ev_btn]
    cmp eax, 4
    je .m_wheelup
    cmp eax, 5
    je .m_wheeldown
    cmp eax, 1
    jne .ret
    mov qword [btn_down], 1       ; arrasto: motion passa a estender
    mov qword [sel_active], 0       ; novo clique cancela arrasto anterior
    mov qword [side_focus], 0       ; foco volta p/ lista/busca (sidebar reativa)
    mov qword [q_focus], 0          ; clique fora da busca tira o foco
    mov eax, [ev_mx]
    mov ecx, [ev_my]
    cmp eax, 240
    jb .m_side
    cmp eax, 601
    jae .m_detail
    ; faixa central: caixa de busca (y<84) ou lista (linhas a partir de 84)
    cmp ecx, 84
    jb .m_searchfocus
    sub ecx, 84
    mov eax, ecx
    mov ebx, 58
    xor edx, edx
    div ebx                         ; eax=row
    cmp eax, ROWS_VISIBLE
    jae .ret
    mov rdx, [scroll]
    add rdx, rax
    cmp rdx, [filt_n]
    jae .ret
    mov [sel], rdx
    jmp .ret
.m_wheelup:
    cmp qword [filt_n], 0
    je .ret
    mov rax, [sel]
    sub rax, 3
    jae .m_wu
    xor eax, eax
.m_wu:
    mov [sel], rax
    jmp .ret
.m_wheeldown:
    cmp qword [filt_n], 0
    je .ret
    mov rax, [sel]
    add rax, 3
    mov [sel], rax                  ; draw faz clamp
    jmp .ret
.m_searchfocus:
    mov qword [q_focus], 1
    mov qword [sel], 0
    jmp .ret
.m_side:
    cmp ecx, 70
    jb .ret
    cmp ecx, 154
    jb .m_lib
    cmp ecx, 194
    jb .ret
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jbe .m_cshown
    mov rax, MAX_COLLS
.m_cshown:
    test rax, rax
    jz .ret
    imul eax, eax, 28
    add eax, 194
    cmp ecx, eax
    jae .ret
    sub ecx, 194
    mov eax, ecx
    mov ebx, 28
    xor edx, edx
    div ebx
    add rax, 3
    mov [libsel], rax
    mov qword [side_focus], 1       ; clique na sidebar foca o painel
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.m_lib:
    sub ecx, 70
    mov eax, ecx
    mov ebx, 28
    xor edx, edx
    div ebx                         ; 0=all 1=fav 2=unfiled
    mov [libsel], rax
    mov qword [side_focus], 1       ; clique na sidebar foca o painel
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.m_detail:
    cmp qword [filt_n], 0
    je .ret
    cmp ecx, 77
    jb .ret
    cmp ecx, 103
    jb .m_title
    cmp ecx, 127
    jb .m_langtags
    cmp ecx, 159
    jb .m_desc                        ; linha da descrição (fix #32)
    mov edi, 1
    call begin_edit
    test eax, eax
    jz .ret
    ; detail somente-leitura sempre rende da linha 0; begin_edit rola p/ o fim
    ; (ensure_vis no cursor=end). Zerar o scroll aqui faz o clique mapear contra
    ; o que o usuário VIU — sem isso, snippet longo saltava e selecionava outra
    ; linha (clique na 28 virava 39).
    mov qword [code_scroll], 0
    call click_to_cursor
    mov rax, [edit_cursor]          ; F4: ancora o arrasto de seleção
    mov [sel_a], rax
    mov [sel_b], rax
    mov rax, [edit_rec]
    mov [sel_rec], rax
    mov qword [sel_active], 1
    jmp .ret
.m_desc:
    mov edi, 7
    call begin_edit
    test eax, eax
    jz .ret
    call desc_click_to_cursor
    jmp .ret
.m_langtags:
    ; linha "lang - tags": escolhe o campo e a coluna pelo x do click
    call lt_pick
    test eax, eax
    jz .ret
    mov [click_col], rdx
    mov edi, eax
    call begin_edit
    test eax, eax
    jz .ret
    mov rax, [click_col]
    cmp qword [edit_mode], 5
    jne .m_lt_tags
    mov [lang_cursor], rax
    jmp .ret
.m_lt_tags:
    mov [tags_cursor], rax
    jmp .ret
.m_title:
    mov edi, 2
    call begin_edit
    test eax, eax
    jz .ret
    call title_click_to_cursor
    jmp .ret
.mknew:
    call now_ms wrt ..plt             ; ms Unix (fix #18, par do Date.now)
    mov r10, rax                    ; epoch-ms
    mov rax, [sn_count]
    cmp rax, MAX_SNIPPETS
    jae .m_maxmsg
    lea rdi, [ibuf]
    call make_sn_id
    mov r11d, eax                   ; idlen
    mov rax, [sn_count]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    mov rdi, rbx
    mov ecx, REC_SIZE
    xor eax, eax
    rep stosb
    ; language nasce VAZIA: no modo 5 o user digita (bash, jq...) ou usa
    ; Up/Down; ao commitar, vazio vira "plaintext" (default do web)
    lea rsi, [ibuf]
    lea rdi, [rbx+REC_ID_OFF]
    mov ecx, r11d
    rep movsb
    mov byte [rdi], 0
    mov [rbx+REC_CREATED_OFF], r10
    mov [rbx+REC_UPDATED_OFF], r10
    inc qword [sn_count]
    mov rax, [sn_count]
    dec rax
    mov [creating_sn], rax            ; em criação até commit/Esc (fix #26)
    mov qword [qlen], 0
    mov qword [libsel], 0
    ; filtro estava velho (7 recs): rebuild ANTES de begin_edit, senão
    ; cur_rec resolve filt[sel] obsoleto e os cursores nascem errados
    call filter_rebuild
    mov rax, [filt_n]
    dec rax
    mov [sel], rax
    mov qword [scroll], 0
    mov edi, 2                      ; começa pelo título
    call begin_edit
    lea rsi, [m_new]
    mov edx, m_new_len
    call set_msg
    jmp .ret
.m_maxmsg:
    lea rsi, [m_maxsn]
    mov edx, m_maxsn_len
    call set_msg
    jmp .ret
.del:
    cmp qword [filt_n], 0
    je .ret
    mov rax, [sel]
    movzx eax, byte [filt_idx+rax]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    ; confirmação em 2 toques (como o Esc): 1o arma, 2o no MESMO rec apaga
    cmp qword [arm_kind], 1
    jne .del_arm
    cmp rbx, [arm_ptr]
    jne .del_arm
    mov qword [arm_kind], 0
    jmp .del_do
.del_arm:
    mov qword [arm_kind], 1
    mov [arm_ptr], rbx
    lea rsi, [m_delarm]
    mov edx, m_delarm_len
    call set_msg
    mov eax, [rbx+REC_TLEN_OFF]
    cmp eax, 40
    jbe .da_ok
    mov eax, 40
.da_ok:
    lea rsi, [rbx+REC_TITLE_OFF]
    mov edx, eax
    call append_msg
    jmp .ret
.del_do:
    call db_snapshot wrt ..plt
    mov ecx, [rbx+REC_TLEN_OFF]
    cmp ecx, 40
    jbe .dlok
    mov ecx, 40
.dlok:
    mov [del_tlen], rcx
    lea rsi, [rbx+REC_TITLE_OFF]
    lea rdi, [del_title]
    test ecx, ecx
    jz .dl0
    rep movsb
.dl0:
    mov rax, [sel]
    movzx r10d, byte [filt_idx+rax]
    mov eax, [sn_count]
    dec eax
    sub eax, r10d                   ; recs após o idx
    jbe .dnomove
    imul eax, eax, REC_SIZE
    mov ecx, eax
    mov eax, r10d
    imul eax, eax, REC_SIZE
    lea rdi, [sn_recs+rax]
    lea rsi, [rdi+REC_SIZE]
    rep movsb
.dnomove:
    dec qword [sn_count]
    mov qword [edit_mode], 0
    mov qword [sel_active], 0       ; rec sumiu: anchors inválidos
    call db_save wrt ..plt          ; rax=n ou -1
    cmp rax, 0
    jl .dfail
    lea rsi, [m_deleted]
    mov edx, m_deleted_len
    call set_msg
    lea rsi, [del_title]
    mov edx, [del_tlen]
    call append_msg
    jmp .ret
.dfail:
    call db_restore wrt ..plt
    call filter_rebuild
    lea rsi, [m_fail]
    mov edx, m_fail_len
    call set_msg
    jmp .ret
.mkcoll:
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .m_cmax
    call now_ms wrt ..plt             ; ms Unix (fix #18)
    mov r10, rax                    ; epoch-ms
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .m_cmax
    mov r11d, eax                   ; k (make_coll_id preserva r11)
    imul eax, eax, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    lea rsi, [t_cnew]
    mov ecx, t_cnew_len
    rep movsb
    mov byte [rdi], 0
    mov dword [coll_lens+r11*4], t_cnew_len
    lea rdi, [ibuf]
    call make_coll_id
    mov ecx, eax
    lea rsi, [ibuf]
    imul eax, r11d, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    rep movsb
    mov byte [rdi], 0
    mov [coll_cats+r11*8], r10
    inc qword [coll_count]
    mov [creating_coll], r11          ; em criação até commit/Esc (fix #26)
    mov qword [qlen], 0
    mov qword [sel], 0
    mov qword [scroll], 0
    mov rax, r11
    add rax, 3
    mov [libsel], rax
    call coll_snapshot              ; cursor=fim; filtro nem existia p/ ela
    mov qword [edit_mode], 3
    mov qword [side_focus], 0 ; edição de coleção cancela foco sidebar
    lea rsi, [m_collnew]
    mov edx, m_collnew_len
    call set_msg
    jmp .ret
.m_cmax:
    lea rsi, [m_collmax]
    mov edx, m_collmax_len
    call set_msg
    jmp .ret
.rencoll:
    ; Ctrl+R respeita o foco: sidebar focada (Tab) + coleção = renomeia;
    ; senão abre o seletor de coleção p/ o snippet (hint de mouse).
    cmp qword [side_focus], 0
    je .mv_via_mouse
    cmp qword [libsel], 3
    jb .mv_via_mouse
    call coll_snapshot
    test eax, eax
    jz .renone
    mov qword [edit_mode], 3
    mov qword [side_focus], 0 ; edição de coleção cancela foco sidebar
    jmp .ret
.mv_via_mouse:
    mov qword [pick_mouse], 1
    jmp .mv_body
.renone:
    lea rsi, [m_nocoll]
    mov edx, m_nocoll_len
    call set_msg
    jmp .ret
.delcoll:
    ; Ctrl+X idem: só apaga coleção com a sidebar focada (Tab). Senão, avisa.
    cmp qword [side_focus], 0
    je .dclnone
    mov eax, [libsel]
    sub eax, 3
    jb .dclnone
    mov rdx, [coll_count]
    cmp rax, rdx
    jae .dclnone
    mov r10d, eax                   ; k
    ; confirmação em 2 toques (como o Esc): 1o arma, 2o na MESMA coll apaga
    cmp qword [arm_kind], 2
    jne .dcl_arm
    cmp r10, [arm_idx]
    jne .dcl_arm
    mov qword [arm_kind], 0
    jmp .dcl_do
.dcl_arm:
    mov qword [arm_kind], 2
    mov [arm_idx], r10
    lea rsi, [m_delcarm]
    mov edx, m_delcarm_len
    call set_msg
    mov eax, [coll_lens+r10*4]
    cmp eax, 40
    jbe .dca_ok
    mov eax, 40
.dca_ok:
    mov r11d, eax
    imul eax, r10d, COLL_NAME_LEN
    lea rsi, [coll_names+rax]
    mov edx, r11d
    call append_msg
    jmp .ret
.dcl_do:
    call db_snapshot wrt ..plt
    mov r10, [arm_idx]              ; k (scratch não sobrevive a set_msg/append)
    imul eax, r10d, COLL_NAME_LEN
    lea rsi, [coll_names+rax]
    mov eax, [coll_lens+r10*4]
    cmp eax, 40
    jbe .dclok
    mov eax, 40
.dclok:
    mov [delc_len], rax
    lea rdi, [delc_name]
    mov ecx, eax
    test ecx, ecx
    jz .dcl0
    rep movsb
.dcl0:
    imul eax, r10d, COLL_ID_LEN
    lea rsi, [coll_ids+rax]
    lea rdi, [delc_id]
    mov ecx, COLL_ID_LEN
    rep movsb
    mov eax, [coll_count]
    dec eax
    sub eax, r10d                   ; entries após k
    jbe .dclnomove
    mov r11d, eax
    imul eax, r10d, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    lea rsi, [rdi+COLL_NAME_LEN]
    mov ecx, r11d
    imul ecx, ecx, COLL_NAME_LEN
    rep movsb
    imul eax, r10d, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    lea rsi, [rdi+COLL_ID_LEN]
    mov ecx, r11d
    imul ecx, ecx, COLL_ID_LEN
    rep movsb
    lea rdi, [coll_lens+r10*4]
    lea rsi, [rdi+4]
    mov ecx, r11d
    rep movsd
    lea rdi, [coll_cats+r10*8]
    lea rsi, [rdi+8]
    mov ecx, r11d
    rep movsq
.dclnomove:
    dec qword [coll_count]
    xor r12d, r12d                  ; unfile snippets com esse id
.dclu: mov rax, [sn_count]
    cmp r12, rax
    jae .dcludone
    mov rax, r12
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    lea rsi, [rbx+REC_CID_OFF]
    lea rdi, [delc_id]
    xor ecx, ecx
.dclcmp: mov al, [rsi+rcx]
    cmp al, [rdi+rcx]
    jne .dclnext
    test al, al
    jz .dclmatch
    inc ecx
    cmp ecx, COLL_ID_LEN
    jb .dclcmp
    jmp .dclnext
.dclmatch:
    mov byte [rbx+REC_CID_OFF], 0
.dclnext:
    inc r12
    jmp .dclu
.dcludone:
    mov qword [libsel], 0
    mov qword [sel], 0
    mov qword [scroll], 0
    mov qword [edit_mode], 0
    call db_save wrt ..plt
    cmp rax, 0
    jl .dclfail
    lea rsi, [m_colldel]
    mov edx, m_colldel_len
    call set_msg
    lea rsi, [delc_name]
    mov edx, [delc_len]
    call append_msg
    jmp .ret
.dclfail:
    call db_restore wrt ..plt
    call filter_rebuild
    lea rsi, [m_fail]
    mov edx, m_fail_len
    call set_msg
    jmp .ret
.dclnone:
    lea rsi, [m_nocoll]
    mov edx, m_nocoll_len
    call set_msg
    jmp .ret
; .movecoll (Ctrl+L) — abre o seletor de coleção p/ o snippet atual (modo 4).
; pick_sel inicia na coleção atual (0=unfiled). rbx=rec sobrevive a
; db_save (callee-saved); k destino vai p/ mv_k (r11 morre no syscall).
.movecoll:
    mov qword [pick_mouse], 0     ; Ctrl+L = picker via setas
.mv_body:
    cmp qword [filt_n], 0
    jne .mv_hasrec
    lea rsi, [m_norec]
    mov edx, m_norec_len
    call set_msg
    jmp .ret
.mv_hasrec:
    mov rax, [coll_count]
    test rax, rax
    jz .mvnone
    mov rax, [sel]
    movzx eax, byte [filt_idx+rax]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    lea rsi, [rbx+REC_CID_OFF]
    mov r10d, -1                    ; cur
    xor r11d, r11d                  ; k
.mvfind:
    mov rax, [coll_count]
    cmp r11, rax
    jae .mvgot
    mov eax, r11d
    imul eax, eax, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    xor ecx, ecx
.mvcmp: mov al, [rsi+rcx]
    cmp al, [rdi+rcx]
    jne .mvnext
    test al, al
    jz .mvhit
    inc ecx
    cmp ecx, COLL_ID_LEN
    jb .mvcmp
    jmp .mvnext
.mvhit:
    mov r10d, r11d
    jmp .mvgot
.mvnext:
    inc r11d
    jmp .mvfind
.mvgot:
    mov eax, r10d
    inc eax                         ; cur+1 (cur=-1 vira 0=unfiled)
    mov [pick_sel], rax
    mov [pick_rec], rbx
    mov qword [edit_mode], 4
    mov qword [side_focus], 0 ; edição de coleção cancela foco sidebar
    cmp qword [pick_mouse], 0  ; hint conforme a entrada (setas x mouse)
    je .mv_hintkeys
    lea rsi, [t_movehint_mouse]
    mov edx, t_movehint_mouse_len
    jmp .mv_hintset
.mv_hintkeys:
    lea rsi, [t_movehint]     ; orientação no canto inferior direito (slot de hints)
    mov edx, t_movehint_len
.mv_hintset:
    call set_msg
    jmp .ret
.mvnone:
    lea rsi, [m_nocolls]
    mov edx, m_nocolls_len
    call set_msg
    jmp .ret
.cont0:
    xor eax, eax
    jmp .ret
.edit:
    mov eax, [ev_kind]
    cmp qword [edit_mode], 3
    je .edit3
    cmp qword [edit_mode], 4
    je .edit4
    cmp qword [edit_mode], 5
    je .edit56
    cmp qword [edit_mode], 6
    je .edit56
    cmp qword [edit_mode], 7
    je .edit56
    cmp eax, 1
    je .e_ins
    cmp eax, 2
    je .e_bs
    cmp eax, 3
    je .e_up
    cmp eax, 4
    je .e_down
    cmp eax, 5
    je .copy                        ; Ctrl+C copia mesmo editando
    cmp eax, 26
    je .paste_req                    ; Ctrl+V cola mesmo editando
    cmp eax, 6
    je .e_commit
    cmp eax, 9
    je .e_nl
    cmp eax, 10
    je .e_cancel
    cmp eax, 11
    je .e_left
    cmp eax, 12
    je .e_right
    cmp eax, 13
    je .e_mouse
    cmp eax, 16
    je .e_delfwd
    cmp eax, 17
    je .e_tab
    cmp eax, 20
    je .e_cut                        ; Ctrl+X recorta a seleção (modo código)
    cmp eax, 27
    je .e_undo                        ; Ctrl+Z desfaz edição
    cmp eax, 28
    je .e_redo                        ; Ctrl+Y refaz edição
    jmp .cont0
.e_ins:
    call sel_maybe_delete           ; com seleção: apaga e cai p/ inserir
    mov al, [ev_char]
    cmp qword [edit_mode], 2
    je .e_tins
    call edit_insert
    jmp .ret
.e_tins:
    call title_insert
    jmp .ret
.e_nl:
    call sel_maybe_delete           ; com seleção: troca o trecho (ou limpa)
    test eax, eax
    jnz .ret
    cmp qword [edit_mode], 2
    je .e_to_code
    cmp qword [edit_mode], 5
    je .e_lang2tags
    cmp qword [edit_mode], 6
    je .e_tags2title
    cmp qword [edit_mode], 7
    je .e_commit                   ; desc é o último campo: Enter commita
    mov al, 10
    call edit_insert
    jmp .ret
.e_lang2tags:
    mov qword [sel_active], 0
    mov qword [edit_mode], 6
    jmp .ret
.e_tags2title:
    mov qword [sel_active], 0
    mov qword [edit_mode], 1
    call ensure_vis
    jmp .ret
.e_to_code:
    mov qword [sel_active], 0
    ; Enter no título -> vai p/ edição do código (cursor no fim)
    call resolve_rec
    test eax, eax
    jz .ret
    mov eax, [rbx+REC_CLEN_OFF]
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
    mov qword [edit_mode], 1
    jmp .ret
.e_bs:
    call sel_maybe_delete           ; com seleção: apaga o trecho
    test eax, eax
    jnz .ret
    cmp qword [edit_mode], 2
    je .e_tbs
    call edit_backspace
    jmp .ret
.e_tbs:
    call title_backspace
    jmp .ret
.e_up:
    mov qword [sel_active], 0       ; navegar limpa a seleção
    call edit_up
    jmp .ret
.e_down:
    mov qword [sel_active], 0
    call edit_down
    jmp .ret
.e_left:
    mov qword [sel_active], 0
    cmp qword [edit_mode], 2
    je .e_tleft
    call edit_left
    jmp .ret
.e_tleft:
    call title_left
    jmp .ret
.e_right:
    mov qword [sel_active], 0
    cmp qword [edit_mode], 2
    je .e_tright
    call edit_right
    jmp .ret
.e_tright:
    call title_right
    jmp .ret
.e_delfwd:
    call sel_maybe_delete           ; com seleção: apaga o trecho
    test eax, eax
    jnz .ret
    cmp qword [edit_mode], 2
    je .e_tdelfwd
    call edit_delfwd
    jmp .ret
.e_tdelfwd:
    call title_delfwd
    jmp .ret
.e_cut:
    ; Ctrl+X no código: recorta a seleção (copia + apaga). Sem seleção: nada;
    ; clipboard ocupado: não apaga (recorte seguro).
    cmp qword [edit_mode], 1
    jne .ret
    cmp qword [sel_active], 0
    je .ret
    call resolve_rec
    test eax, eax
    jz .ret
    cmp rbx, [sel_rec]
    jne .cutstale
    call sel_copy
    cmp eax, 0
    jg .cutdel
    jl .cutbusy
    jmp .ret
.cutstale:
    mov qword [sel_active], 0
    jmp .ret
.cutdel:
    call sel_delete_range
    lea rsi, [m_cut]
    mov edx, m_cut_len
    call set_msg
    mov eax, [clip_len]
    lea rdi, [ibuf]
    call itoa                       ; "recortado: N" como feedback
    lea rsi, [ibuf]
    mov edx, eax
    call append_msg
    jmp .ret
.cutbusy:
    lea rsi, [m_busy]
    mov edx, m_busy_len
    call set_msg
    jmp .ret
.e_tab:
    mov qword [sel_active], 0       ; troca de campo limpa a seleção
    ; ciclo: titulo(2) -> codigo(1) -> lang(5) -> tags(6) -> desc(7) -> titulo
    mov rax, [edit_mode]
    cmp rax, 2
    je .e_tab2code
    cmp rax, 1
    je .e_tab_lang
    cmp rax, 5
    je .e_tab_tags
    cmp rax, 6
    je .e_tab_desc
    ; 7 -> título
    mov qword [edit_mode], 2
    jmp .ret
.e_tab_lang:
    mov qword [edit_mode], 5
    jmp .ret
.e_tab_tags:
    mov qword [edit_mode], 6
    jmp .ret
.e_tab_desc:
    mov qword [edit_mode], 7
    jmp .ret
.e_tab2code:
    mov qword [edit_mode], 1
    call ensure_vis
    jmp .ret
.e_mouse:
    mov eax, [ev_btn]
    cmp eax, 1
    jne .ret
    mov qword [btn_down], 1       ; arrasto: motion passa a estender
    mov qword [sel_active], 0       ; novo clique cancela arrasto anterior
    mov eax, [ev_mx]
    mov ecx, [ev_my]
    cmp eax, 601
    jb .ret
    cmp ecx, 77
    jb .ret
    cmp ecx, 103
    jb .e_mtitle
    cmp ecx, 127
    jb .e_mlangtags
    cmp ecx, 159
    jb .e_mdesc
    mov qword [edit_mode], 1
    call click_to_cursor
    mov rax, [edit_cursor]          ; F4: ancora o arrasto de seleção
    mov [sel_a], rax
    mov [sel_b], rax
    mov rax, [edit_rec]
    mov [sel_rec], rax
    mov qword [sel_active], 1
    jmp .ret
.e_mdesc:
    mov qword [edit_mode], 7
    call desc_click_to_cursor
    jmp .ret
.e_mlangtags:
    call lt_pick
    test eax, eax
    jz .ret
    mov [click_col], rdx
    mov [edit_mode], rax
    mov rax, [click_col]
    cmp qword [edit_mode], 5
    jne .e_mlt_tags
    mov [lang_cursor], rax
    jmp .ret
.e_mlt_tags:
    mov [tags_cursor], rax
    jmp .ret
.e_mtitle:
    call title_click_to_cursor       ; igual ao click normal (fix #31)
    mov qword [edit_mode], 2
    jmp .ret
; .edit3 — modo 3: renomeando coleção (libsel-3). Só teclas de texto.
.edit3:
    mov eax, [ev_kind]
    cmp eax, 1
    je .e3_ins
    cmp eax, 2
    je .e3_bs
    cmp eax, 26
    je .paste_req
    cmp eax, 6
    je .e3_commit
    cmp eax, 9
    je .e3_commit
    cmp eax, 10
    je .e3_cancel
    cmp eax, 11
    je .e3_left
    cmp eax, 12
    je .e3_right
    cmp eax, 16
    je .e3_delfwd
    cmp eax, 27
    je .e_undo
    cmp eax, 28
    je .e_redo
    jmp .cont0
.e3_ins:
    call sel_maybe_delete           ; limpa eventual seleção do código
    mov al, [ev_char]
    call coll_insert
    jmp .ret
.e3_bs:
    call sel_maybe_delete
    test eax, eax
    jnz .ret
    call coll_backspace
    jmp .ret
.e3_left:
    call coll_left
    jmp .ret
.e3_right:
    call coll_right
    jmp .ret
.e3_delfwd:
    call coll_delfwd
    jmp .ret
.e3_commit:
    call coll_commit_save
    jmp .ret
.e3_cancel:
    call coll_cancel
    jmp .ret
; .edit4 — modo 4: seletor de coleção. Up/Down move o cursor (0=unfiled),
; Enter confirma (salva), Esc cancela, clique na sidebar escolhe direto.
.edit4:
    mov eax, [ev_kind]
    cmp eax, 3
    je .e4_up
    cmp eax, 4
    je .e4_down
    cmp eax, 9
    je .e4_commit
    cmp eax, 10
    je .e4_cancel
    cmp eax, 13
    je .e4_mouse
    jmp .cont0
.e4_up:
    mov rax, [pick_sel]
    test rax, rax
    jz .ret
    dec rax
    mov [pick_sel], rax
    jmp .ret
.e4_down:
    mov rax, [pick_sel]
    cmp rax, [coll_count]
    jae .ret
    inc rax
    mov [pick_sel], rax
    jmp .ret
.e4_commit:
    mov rax, [pick_sel]
    dec rax
    mov [mv_k], rax
    mov rbx, [pick_rec]
    call assign_save
    mov qword [edit_mode], 0
    mov qword [sel_active], 0       ; seletor fecha: sem seleção pendente
    jmp .ret
.e4_cancel:
    mov qword [edit_mode], 0
    mov qword [sel_active], 0
    lea rsi, [m_cancel]
    mov edx, m_cancel_len
    call set_msg
    jmp .ret
.e4_mouse:
    mov eax, [ev_btn]
    cmp eax, 1
    jne .ret
    mov eax, [ev_mx]
    mov ecx, [ev_my]
    cmp eax, 240
    jae .ret
    cmp ecx, 126
    jb .ret
    cmp ecx, 154
    jb .e4_munf
    cmp ecx, 194
    jb .ret
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jbe .e4m_shown
    mov rax, MAX_COLLS
.e4m_shown:
    test rax, rax
    jz .ret
    imul eax, eax, 28
    add eax, 194
    cmp ecx, eax
    jae .ret
    sub ecx, 194
    mov eax, ecx
    mov ebx, 28
    xor edx, edx
    div ebx
    inc rax
    mov [pick_sel], rax
    jmp .e4_commit
.e4_munf:
    mov qword [pick_sel], 0
    jmp .e4_commit
; .edit56 — campos 1-linha: language (modo 5), tags (6) e descrição (7).
; Insere/apaga/navega via helpers genéricos; Enter/Tab trocam de campo;
; Esc restaura os campos do snapshot; Ctrl+S commita; mouse reposiciona
; (mesma navegação dos modos 1/2 — antes o click era ignorado aqui).
.edit56:
    mov eax, [ev_kind]
    cmp eax, 3
    je .e5_up
    cmp eax, 4
    je .e5_down
    cmp eax, 1
    je .e5_ins
    cmp eax, 2
    je .e5_bs
    cmp eax, 26
    je .paste_req
    cmp eax, 6
    je .e_commit
    cmp eax, 9
    je .e_nl
    cmp eax, 10
    je .e_cancel
    cmp eax, 11
    je .e5_left
    cmp eax, 12
    je .e5_right
    cmp eax, 13
    je .e_mouse
    cmp eax, 16
    je .e5_delfwd
    cmp eax, 17
    je .e_tab
    cmp eax, 27
    je .e_undo
    cmp eax, 28
    je .e_redo
    jmp .cont0
.e5_ins:
    call sel_maybe_delete           ; limpa eventual seleção do código
    mov al, [ev_char]               ; al != ev_kind aqui (kinds são 1..21)
    mov [fld_char], al
    call field_setup
    test eax, eax
    jz .ret
    mov al, [fld_char]
    call fld_insert
    jmp .ret
.e5_up:
    cmp qword [edit_mode], 5
    jne .ret
    mov edi, -1
    call lang_step
    jmp .ret
.e5_down:
    cmp qword [edit_mode], 5
    jne .ret
    mov edi, 1
    call lang_step
    jmp .ret
.e5_bs:
    call sel_maybe_delete
    test eax, eax
    jnz .ret
    call field_setup
    test eax, eax
    jz .ret
    call fld_backspace
    jmp .ret
.e5_left:
    call field_setup
    test eax, eax
    jz .ret
    call fld_left
    jmp .ret
.e5_right:
    call field_setup
    test eax, eax
    jz .ret
    call fld_right
    jmp .ret
.e5_delfwd:
    call sel_maybe_delete
    test eax, eax
    jnz .ret
    call field_setup
    test eax, eax
    jz .ret
    call fld_delfwd
    jmp .ret
.e_cancel:
    mov qword [sel_active], 0       ; anchors viram lixo no restore
    ; restaura backup (código + título + language + tags)
    call resolve_rec
    test eax, eax
    jz .ret
    ; em criação (Ctrl+N sem commit)? remove o rec em vez de restaurar (#26)
    mov rax, rbx
    lea rcx, [sn_recs]
    sub rax, rcx
    mov ecx, REC_SIZE
    xor edx, edx
    div rcx                            ; rax = índice do rec atual
    cmp rax, [creating_sn]
    je .e_unmake
    mov ecx, [backup_len]
    mov [rbx+REC_CLEN_OFF], ecx
    lea rsi, [edit_backup]
    lea rdi, [rbx+REC_CODE_OFF]
    test ecx, ecx
    jz .rst0
    rep movsb
.rst0:
    mov byte [rdi], 0
    mov ecx, [title_blen]
    mov [rbx+REC_TLEN_OFF], ecx
    lea rsi, [title_backup]
    lea rdi, [rbx+REC_TITLE_OFF]
    test ecx, ecx
    jz .rst1
    rep movsb
.rst1:
    mov byte [rdi], 0
    mov ecx, [lang_blen]
    mov [rbx+REC_LLEN_OFF], ecx
    lea rsi, [lang_backup]
    lea rdi, [rbx+REC_LANG_OFF]
    test ecx, ecx
    jz .rst2
    rep movsb
.rst2:
    mov byte [rdi], 0
    mov ecx, [tags_blen]
    mov [rbx+REC_GLEN_OFF], ecx
    lea rsi, [tags_backup]
    lea rdi, [rbx+REC_TAGS_OFF]
    test ecx, ecx
    jz .rst3
    rep movsb
.rst3:
    mov byte [rdi], 0
    mov ecx, [desc_blen]
    mov [desc_len], ecx
    lea rsi, [desc_backup]
    lea rdi, [rbx+REC_DESC_OFF]
    test ecx, ecx
    jz .rst4
    rep movsb
.rst4:
    mov byte [rdi], 0
    mov qword [edit_mode], 0
    call undo_reset                ; Esc: histórico da sessão morre junto
    lea rsi, [m_cancel]
    mov edx, m_cancel_len
    call set_msg
    jmp .ret
.e_unmake:
    ; Esc descartou a criação: compacta os recs após idx (igual .del_do, mas
    ; sem snapshot — nada foi persistido) e limpa o estado de edição.
    mov r10, rax                    ; idx (div não toca r10)
    mov rax, [sn_count]
    dec rax
    sub rax, r10                    ; recs após o idx
    jbe .e_nomove
    imul eax, eax, REC_SIZE
    mov ecx, eax
    mov eax, r10d
    imul eax, eax, REC_SIZE
    lea rdi, [sn_recs+rax]
    lea rsi, [rdi+REC_SIZE]
    rep movsb
.e_nomove:
    dec qword [sn_count]
    mov qword [creating_sn], -1
    mov qword [edit_mode], 0
    mov qword [edit_rec], 0
    call undo_reset
    call filter_rebuild
    mov qword [sel], 0
    mov qword [scroll], 0
    lea rsi, [m_unmade]
    mov edx, m_unmade_len
    call set_msg
    jmp .ret
.e_undo:
    call do_undo
    jmp .ret
.e_redo:
    call do_redo
    jmp .ret
.e_commit:
    mov qword [sel_active], 0       ; commit encerra a seleção
    call edit_commit_save
    jmp .ret
.ret:
    mov qword [undo_skip], 0        ; skip do replace vale só no evento atual
    xor eax, eax
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; title_click_to_cursor — title_cursor = coluna do click (ev_mx), clamp no len.
; Um helper p/ os dois caminhos de click no título (normal .m_title e em
; edição .e_mtitle — antes o segundo só trocava o modo, fix #31).
; Preserva rbx/r11 do chamador (r11d é scratch interno, salvo na pilha).
title_click_to_cursor:
    push rbx
    push r11
    sub rsp, 8                      ; 2 pushes + sub: calls alinhados (fix #19)
    mov eax, [ev_mx]
    sub eax, 621
    jge .txok
    xor eax, eax
.txok:
    mov ecx, 9
    xor edx, edx
    div ecx                         ; eax = col (chars)
    mov r11d, eax
    call resolve_rec                ; rbx=rec (r11 intacto: só rax/rbx)
    test eax, eax
    jz .ret
    lea rsi, [rbx+REC_TITLE_OFF]
    mov ecx, [rbx+REC_TLEN_OFF]
    mov edx, r11d
    call bytecol                    ; eax = byte offset
    mov [title_cursor], rax
.ret:
    add rsp, 8
    pop r11
    pop rbx
    ret

; desc_click_to_cursor — desc_cursor = coluna do click (origem DESC_TXT_X),
; convertida p/ byte offset (sem partir UTF-8). Usa resolve_rec.
desc_click_to_cursor:
    push rbx
    mov eax, [ev_mx]
    sub eax, DESC_TXT_X
    jge .dxok
    xor eax, eax
.dxok:
    mov ecx, 9
    xor edx, edx
    div ecx                         ; eax = col chars
    mov r11d, eax
    call resolve_rec
    test eax, eax
    jz .ret
    lea rsi, [rbx+REC_DESC_OFF]
    mov ecx, [desc_len]
    mov edx, r11d
    call bytecol                    ; eax = byte offset
    mov [desc_cursor], rax
.ret:
    pop rbx
    ret
; col=(mx-638)/9, faixa=(my-CODE_TOP_Y+9)/18. Mapeia a faixa visual (com
; wrap) p/ (início da linha lógica, chunk) e a coluna p/ byte offset.
; O +9 (meia fileira) ancora a linha no MEIO visual do glifo: sem ele, clicar
; no corpo das letras (que fica ~7px acima do baseline) caía na linha de cima.
; Preserva rbx/r12/r13 do chamador.
click_to_cursor:
    push rbx
    push r12
    push r13
    ; 3 pushes: entrada rsp%16==8 -> 0: calls ok, sem sub (fix #19)
    call resolve_rec
    test eax, eax
    jz .ret
    mov eax, [ev_my]
    sub eax, CODE_TOP_Y - 9
    jge .yok
    xor eax, eax
.yok:
    mov ecx, 18
    xor edx, edx
    div ecx
    mov r13d, eax                   ; faixa visual relativa (salvo: r13 sobrevive)
    mov eax, [ev_mx]
    sub eax, 638
    jge .xok
    xor eax, eax
.xok:
    mov ecx, 9
    xor edx, edx
    div ecx
    mov r12d, eax                   ; col em células (mouse)
    lea rsi, [rbx+REC_CODE_OFF]
    mov ecx, [rbx+REC_CLEN_OFF]
    mov edx, r13d                   ; faixa rel
    mov r8d, [code_scroll]
    call wrap_vrow_off              ; eax=início da linha, edx=chunk
    mov r10d, eax                   ; line_start abs
    imul edx, edx, CODE_WRAP
    add edx, r12d                   ; col em células (chunk*69 + mouse)
    mov r12d, edx                   ; col salva (bytecol suja edx)
    ; len da linha lógica a partir de line_start (clamp do bytecol):
    lea rsi, [rbx+REC_CODE_OFF]
    mov ecx, [rbx+REC_CLEN_OFF]     ; total
    mov eax, r10d
.clscan:
    cmp eax, ecx
    jae .gotlen
    cmp byte [rsi+rax], 10
    je .gotlen
    inc eax
    jmp .clscan
.gotlen:
    sub eax, r10d                   ; eax = len bytes
    lea rsi, [rbx+REC_CODE_OFF]
    add rsi, r10                    ; ptr da linha
    mov ecx, eax                    ; maxlen
    mov edx, r12d                   ; col em células
    call bytecol                    ; eax = byte offset (sem partir UTF-8)
    add eax, r10d
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
.ret:
    pop r13
    pop r12
    pop rbx
    ret

; cid_match(rbx=rec, rax=coll k) — eax 1 se rec.cid == coll_ids[k].
; Leaf: só rax/r8/r10/r11 (preserva rcx/rdx — filter_rebuild/match_rec
; dependem disso; mesmo contrato de-facto do contains_ci).
cid_match:
    imul eax, eax, COLL_ID_LEN
    lea r10, [coll_ids+rax]
    lea r11, [rbx+REC_CID_OFF]
    xor eax, eax
.cml:
    mov r8b, [r11+rax]
    cmp r8b, [r10+rax]
    jne .cmno
    test r8b, r8b
    jz .cmyes
    inc eax
    cmp eax, COLL_ID_LEN
    jb .cml
.cmyes:
    mov eax, 1
    ret
.cmno:
    xor eax, eax
    ret

; assign_save — aplica [mv_k] (-1=unfiled) ao rec rbx: cid+updated+save+msg.
; Preserva rbx. Usado pelo commit do seletor (tecla, Enter ou clique).
assign_save:
    push rbx
    ; 1 push: na entrada rsp%16==8 -> agora 0: calls ok (fix #19)
    call db_snapshot wrt ..plt
    cmp qword [mv_k], -1
    je .asunf
    mov eax, [mv_k]
    imul eax, eax, COLL_ID_LEN
    lea rsi, [coll_ids+rax]
    lea rdi, [rbx+REC_CID_OFF]
    mov ecx, COLL_ID_LEN
    rep movsb
    jmp .asstamp
.asunf:
    mov byte [rbx+REC_CID_OFF], 0
.asstamp:
    call now_ms wrt ..plt             ; ms Unix (fix #18); preserva rbx/r11
    mov [rbx+REC_UPDATED_OFF], rax
    call db_save wrt ..plt
    cmp rax, 0
    jl .asfail
    lea rsi, [m_moved]
    mov edx, m_moved_len
    call set_msg
    cmp qword [mv_k], -1
    je .asunfiled
    mov rax, [mv_k]
    imul eax, eax, COLL_NAME_LEN
    lea rsi, [coll_names+rax]
    mov rdx, [mv_k]
    mov edx, [coll_lens+rdx*4]
    cmp edx, 40
    jbe .asapp
    mov edx, 40
.asapp:
    call append_msg
    jmp .asdone
.asunfiled:
    lea rsi, [m_unfiled2]
    mov edx, m_unfiled2_len
    call append_msg
    jmp .asdone
.asfail:
    call db_restore wrt ..plt
    lea rsi, [m_fail]
    mov edx, m_fail_len
    call set_msg
.asdone:
    pop rbx
    ret

; ---------- campos 1-linha genéricos (lang/tags) ----------
; Convenção: rdi=base, rsi=&len(dword), rdx=&cursor(qword), ecx=capacidade
; (inclui NUL; máx = cap-1). Clobbers scratch; preserva rbx/r12-r15.
; Todos os loads de len são dword (mov e..): ver contract.md §2.

; field_setup — rbx=rec via cur_rec; aponta o campo do edit_mode (5=lang,
; 6=tags, 7=desc). eax 1 ok / 0 inválido. Deixa rdi/rsi/rdx/ecx prontos.
field_setup:
    push rbx
    call resolve_rec
    test eax, eax
    jz .bad
    cmp qword [edit_mode], 5
    je .lang
    cmp qword [edit_mode], 6
    je .tags
    cmp qword [edit_mode], 7
    je .desc
    jmp .bad
.lang:
    lea rdi, [rbx+REC_LANG_OFF]
    lea rsi, [rbx+REC_LLEN_OFF]
    lea rdx, [lang_cursor]
    mov ecx, REC_LANG_LEN
    mov eax, 1
    pop rbx
    ret
.tags:
    lea rdi, [rbx+REC_TAGS_OFF]
    lea rsi, [rbx+REC_GLEN_OFF]
    lea rdx, [tags_cursor]
    mov ecx, REC_TAGS_LEN
    mov eax, 1
    pop rbx
    ret
.desc:
    lea rdi, [rbx+REC_DESC_OFF]
    lea rsi, [desc_len]
    lea rdx, [desc_cursor]
    mov ecx, REC_DESC_LEN
    mov eax, 1
    pop rbx
    ret
.bad:
    xor eax, eax
    pop rbx
    ret

; fld_insert(al=char) — insere no cursor do campo apontado
fld_insert:
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    ; 4 pushes + sub 8: entrada rsp%16==8 -> 0: o call set_msg ok (fix #19)
    call undo_ins_hook              ; al=char; mesma palavra coalesce
    mov r12, rdi                    ; base
    mov r13, rsi                    ; &len
    mov r14, rdx                    ; &cursor
    mov r15d, ecx                   ; cap
    mov r8b, al
    dec r15d                        ; máx len
    mov eax, [r13]                  ; dword!
    cmp eax, r15d
    jae .full
    mov rcx, [r14]
    cmp rax, rcx
    jbe .ins
    dec rax
.mv: mov r10b, [r12+rax]
    mov [r12+rax+1], r10b
    cmp rax, rcx
    je .ins
    dec rax
    jmp .mv
.ins:
    mov [r12+rcx], r8b
    mov eax, [r13]
    inc eax
    mov [r13], eax
    mov byte [r12+rax], 0
    inc qword [r14]
    jmp .ret
.full:
    lea rsi, [m_fieldfull]
    mov edx, m_fieldfull_len
    call set_msg
.ret:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; fld_backspace — apaga antes do cursor
fld_backspace:
    push r12
    push r13
    push r14
    call undo_del_hook
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    cmp qword [r14], 0
    je .ret
    mov r10, [r14]                  ; cursor (r10/r11 sobrevivem ao helper;
    mov rdi, r12                    ; base. rdx/rcx MORREM no call — nunca
    mov edx, r10d                   ; reusar após call! (bug: usava rdx aqui))
    call utf8_step_back             ; (fix #33)
    mov [r14], rax                  ; cursor = início da sequência
    sub r10, rax                    ; r10 = nbytes removidos
    mov rcx, rax
    mov rsi, rax
    add rsi, r10
    mov edx, [r13]                  ; dword!
.mv: cmp rsi, rdx
    jae .out
    mov r11b, [r12+rsi]
    mov [r12+rcx], r11b
    inc rsi
    inc rcx
    jmp .mv
.out:
    mov eax, [r13]
    sub eax, r10d
    mov [r13], eax
    mov byte [r12+rax], 0
.ret:
    pop r14
    pop r13
    pop r12
    ret

; fld_delfwd — apaga sob o cursor
fld_delfwd:
    push r12
    push r13
    push r14
    call undo_del_hook
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov rdx, [r14]                  ; cursor
    mov esi, [r13]                  ; len
    cmp rdx, rsi
    jae .ret
    mov rdi, r12
    call utf8_step_fwd              ; F (fix #33)
    mov r10d, eax
    mov ecx, [r14]
    mov esi, r10d
    mov edx, [r13]
.mv: cmp esi, edx
    jae .out
    mov r11b, [r12+rsi]
    mov [r12+rcx], r11b
    inc rsi
    inc rcx
    jmp .mv
.out:
    mov eax, [r13]
    sub eax, r10d
    add eax, ecx
    mov [r13], eax
    mov byte [r12+rax], 0
.ret:
    pop r14
    pop r13
    pop r12
    ret

; fld_left / fld_right
fld_left:
    cmp qword [rdx], 0
    je .ret
    sub rsp, 8                      ; sem pushes: alinha p/ call (fix #19)
    mov r10, rdx                    ; &cursor em r10 (rcx MORRE no call!)
    mov edx, [rdx]                  ; pos
    call utf8_step_back             ; (fix #33)
    mov [r10], rax
    add rsp, 8
.ret:
    ret

fld_right:
    mov rax, [rdx]
    cmp eax, [rsi]                  ; dword!
    jae .ret
    sub rsp, 8                      ; sem pushes: alinha p/ call (fix #19)
    mov r10, rdx                    ; &cursor em r10 (rcx MORRE no call!)
    mov edx, eax                    ; pos
    mov esi, [rsi]                  ; len
    call utf8_step_fwd              ; (fix #33)
    mov [r10], rax
    add rsp, 8
.ret:
    ret

; lt_pick — decide language(5)/tags(6) e a coluna a partir de ev_mx.
; eax = modo (0 = sem seleção), edx = coluna clampada. rbx=rec (via cur_rec).
; Geometria: lang em 621; " - " 27px; tags em 621+llen*9+27; coluna = 9px.
; Limiar lang/tags = 621+llen*9+13 (meio do separador).
lt_pick:
    push rbx
    call resolve_rec
    test eax, eax
    jz .bad
    ; largura EXIBIDA (fix #25): render trunca lang em LANG_DISP_MAX; o
    ; hit-test usa o mesmo limite, senão cliques nas tags visíveis caem no lang
    mov r8d, [rbx+REC_LLEN_OFF]
    cmp r8d, LANG_DISP_MAX
    jbe .wok
    mov r8d, LANG_DISP_MAX
.wok:
    ; largura em CÉLULAS p/ o hit-test (bytes deslocariam a fronteira c/ acento)
    lea rsi, [rbx+REC_LANG_OFF]
    mov ecx, r8d
    call charcount
    mov r9d, eax
    mov eax, r9d
    imul eax, eax, 9
    add eax, 634
    mov edx, [ev_mx]
    cmp edx, eax
    jb .lang
    mov eax, r9d
    imul eax, eax, 9
    add eax, 648                    ; 621 + 27
    mov ecx, edx
    sub ecx, eax
    jge .t1
    xor ecx, ecx
.t1:
    mov eax, ecx
    mov ecx, 9
    xor edx, edx
    div ecx                         ; eax = col chars
    mov edx, eax
    lea rsi, [rbx+REC_TAGS_OFF]
    mov ecx, [rbx+REC_GLEN_OFF]
    cmp ecx, TAGS_DISP_MAX           ; tags exibidas truncadas em 36 (fix #25)
    jbe .tgok
    mov ecx, TAGS_DISP_MAX
.tgok:
    call bytecol                    ; eax = byte offset
    mov edx, eax                    ; coluna
    mov eax, 6
    pop rbx
    ret
.lang:
    mov eax, edx
    sub eax, 621
    jge .l1
    xor eax, eax
.l1:
    mov ecx, 9
    xor edx, edx
    div ecx                         ; eax = col chars
    mov edx, eax
    lea rsi, [rbx+REC_LANG_OFF]
    mov ecx, r8d
    call bytecol                    ; eax = byte offset
    mov edx, eax                    ; coluna
    mov eax, 5
    pop rbx
    ret
.bad:
    xor eax, eax
    pop rbx
    ret

; lang_find — rbx=rec; eax = índice do language atual na tabela, ou -1.
lang_find:
    push r12
    push r13
    lea r12, [rbx+REC_LANG_OFF]
    xor r13d, r13d
.loop:
    cmp r13d, LANG_COUNT
    jae .notfound
    mov eax, r13d
    imul eax, eax, LANG_SLOT
    lea rsi, [lang_tab+rax]
    xor ecx, ecx
.cmp:
    mov al, [r12+rcx]
    cmp al, [rsi+rcx]
    jne .next
    test al, al
    jz .found
    inc ecx
    jmp .cmp
.next:
    inc r13d
    jmp .loop
.found:
    mov eax, r13d
    pop r13
    pop r12
    ret
.notfound:
    mov eax, -1
    pop r13
    pop r12
    ret

; lang_step(edi=+1/-1) — cicla o tipo pela tabela; reposiciona o cursor no fim.
; Valor fora da tabela: down começa em 0, up começa no último.
lang_step:
    push rbx
    push r12
    sub rsp, 8
    call undo_del_hook               ; Up/Down no language troca o texto
    mov r12d, edi
    call resolve_rec
    test eax, eax
    jz .ret
    call lang_find
    cmp eax, 0
    jge .have
    test r12d, r12d
    js .last
    xor eax, eax
    jmp .set
.last:
    mov eax, LANG_COUNT - 1
    jmp .set
.have:
    add eax, r12d
    cmp eax, 0
    jge .hi
    add eax, LANG_COUNT
.hi:
    cmp eax, LANG_COUNT
    jl .set
    sub eax, LANG_COUNT
.set:
    imul eax, eax, LANG_SLOT
    lea rsi, [lang_tab+rax]
    lea rdi, [rbx+REC_LANG_OFF]
    xor ecx, ecx
.cp:
    mov al, [rsi+rcx]
    mov [rdi+rcx], al
    inc ecx
    test al, al
    jnz .cp
    dec ecx
    mov [rbx+REC_LLEN_OFF], ecx
    mov [lang_cursor], rcx
.ret:
    add rsp, 8
    pop r12
    pop rbx
    ret

; hstrlen(rdi=ptr) — eax = len até NUL. Leaf.
hstrlen:
    xor eax, eax
.l: cmp byte [rdi+rax], 0
    je .d
    inc eax
    jmp .l
.d: ret

; help_draw — overlay central com a tabela de comandos (Ctrl+H).
; Desenhado por último em ui_draw, então cobre a UI normal.
help_draw:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    ; pass 1: maior desc (cap 100 p/ caber em 1280); card se ajusta ao texto.
    lea rbx, [help_rows]
    xor r15d, r15d
.hm_loop:
    lea rax, [help_rows_end]
    cmp rbx, rax
    jae .hm_done
    mov rdi, [rbx+8]
    call hstrlen
    cmp eax, 100
    jbe .hm_ok
    mov eax, 100
.hm_ok:
    cmp eax, r15d
    jbe .hm_next
    mov r15d, eax
.hm_next:
    add rbx, 16
    jmp .hm_loop
.hm_done:
    ; largura 264+max*9 (mínimo 680 p/ conteúdo curto); x centralizado e par.
    mov r11d, r15d                  ; r11d = teto do texto (chars)
    mov eax, r15d
    imul eax, eax, 9
    add eax, 264
    cmp eax, 680
    jae .hm_wok
    mov eax, 680
.hm_wok:
    mov r12d, eax                   ; r12d = largura
    mov ebx, eax
    shr ebx, 1
    mov eax, 640
    sub eax, ebx
    and eax, -2
    mov r15d, eax                   ; r15d = card_x
    ; fundo + moldura
    mov edi, r15d
    mov esi, 140
    mov edx, r12d
    mov ecx, 520
    mov r8d, C_PANEL
    call platform_fill_rect wrt ..plt
    mov edi, r15d
    mov esi, 140
    mov edx, r12d
    mov ecx, 2
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
    mov edi, r15d
    mov esi, 659
    mov edx, r12d
    mov ecx, 1
    mov r8d, C_BORDER
    call platform_fill_rect wrt ..plt
    mov edi, r15d
    mov esi, 140
    mov edx, 1
    mov ecx, 520
    mov r8d, C_BORDER
    call platform_fill_rect wrt ..plt
    mov edi, r15d
    add edi, r12d
    sub edi, 1
    mov esi, 140
    mov edx, 1
    mov ecx, 520
    mov r8d, C_BORDER
    call platform_fill_rect wrt ..plt
    lea edi, [r15+24]
    mov esi, 180
    mov edx, C_TEXT
    lea rcx, [t_helptitle]
    mov r8d, t_helptitle_len
    call platform_draw_text wrt ..plt
    mov edi, r15d
    add edi, r12d
    sub edi, 24
    mov eax, t_helpclose_len
    imul eax, eax, 9
    sub edi, eax
    mov esi, 180
    mov edx, C_DIM
    lea rcx, [t_helpclose]
    mov r8d, t_helpclose_len
    call platform_draw_text wrt ..plt
    lea edi, [r15+24]
    mov esi, 196
    mov edx, r12d
    sub edx, 48
    mov ecx, 1
    mov r8d, C_BORDER
    call platform_fill_rect wrt ..plt
    lea rbx, [help_rows]
    mov r14d, 222
.hloop:
    lea rax, [help_rows_end]
    cmp rbx, rax
    jae .hdone
    mov rdi, [rbx]
    call hstrlen
    mov r13d, eax
    lea edi, [r15+24]
    mov esi, r14d
    mov edx, C_ACCENT
    mov rcx, [rbx]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    mov rdi, [rbx+8]
    call hstrlen
    mov r13d, eax
    cmp r13d, r11d
    cmova r13d, r11d
    lea edi, [r15+240]
    mov esi, r14d
    mov edx, C_TEXT
    mov rcx, [rbx+8]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    add rbx, 16
    add r14d, 24
    jmp .hloop
.hdone:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; set_msg(rsi=ptr, edx=len) — substitui msg (cap 127)
set_msg:
    mov eax, edx
    mov ecx, 127
    cmp eax, ecx
    cmova eax, ecx
    mov [msg_len], rax
    test eax, eax
    jz .ret
    lea rdi, [msg_buf]
    mov ecx, eax
    rep movsb
.ret:
    ret

; append_msg(rsi=ptr, edx=len) — concatena em msg (cap total 127)
append_msg:
    push rbx
    mov rax, [msg_len]
    mov ecx, 127
    sub ecx, eax
    jbe .done
    cmp edx, ecx
    cmova edx, ecx
    mov ebx, edx
    lea rdi, [msg_buf]
    add rdi, rax
    mov ecx, edx
    rep movsb
    add [msg_len], rbx
.done:
    pop rbx
    ret

; append_title — rbx=rec; concatena title (cap 40)
append_title:
    mov eax, [rbx+REC_TLEN_OFF]
    mov edx, 40
    cmp eax, edx
    cmova eax, edx
    lea rsi, [rbx+REC_TITLE_OFF]
    mov edx, eax
    jmp append_msg

; do_save — db_save + msg "salvo N (nativo)". Preserva rbx.
do_save:
    push rbx
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call db_save wrt ..plt          ; rax = n ou -1
    cmp rax, 0
    jl .fail
    mov rbx, rax
    lea rsi, [m_saved]
    mov edx, m_saved_len
    call set_msg
    mov eax, ebx
    lea rdi, [ibuf]
    call itoa
    lea rsi, [ibuf]
    mov edx, eax
    call append_msg
    jmp .done
.fail:
    lea rsi, [m_fail]
    mov edx, m_fail_len
    call set_msg
.done:
    pop rbx
    ret

; ---------- modo edição ----------
; Convenção: rbx = rec corrente (via cur_rec). Helpers preservam rbx e
; r12-r15; scratch: rax,rcx,rdx,rsi,rdi,r8-r11.

; cur_rec — rbx = rec de filt[sel]; eax 1 ok / 0 vazio
cur_rec:
    xor eax, eax
    cmp qword [filt_n], 0
    je .ret
    mov rax, [sel]
    movzx eax, byte [filt_idx+rax]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    mov eax, 1
.ret:
    ret

; resolve_rec — rbx = rec da edição ativa nos modos 1/2/5/6; senão cur_rec.
; Os helpers de edição chamam isto porque filt[sel] pode mudar enquanto o
; texto é digitado. Modos 3/4 continuam com cur_rec/coll_cur/pick_rec.
resolve_rec:
    mov rax, [edit_mode]
    cmp rax, 1
    je .pin
    cmp rax, 2
    je .pin
    cmp rax, 5
    je .pin
    cmp rax, 6
    je .pin
    cmp rax, 7
    je .pin
    jmp cur_rec
.pin:
    mov rbx, [edit_rec]
    test rbx, rbx
    jz cur_rec
    mov eax, 1
    ret

; begin_edit(edi=1 código, 2 título) — snapshot código+título, entra no edit.
; eax 1 ok / 0 vazio. Preserva rbx do chamador.
begin_edit:
    push rbx
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19)
    mov r10d, edi                   ; r10d=modo (mov r32 zera o alto)
    call cur_rec
    test eax, eax
    jz .ret
    mov [edit_rec], rbx
    mov qword [sel_active], 0       ; edição nova: seleção antiga é inválida
    mov qword [side_focus], 0       ; edição cancela o foco da sidebar
    mov ecx, [rbx+REC_CLEN_OFF]
    mov [backup_len], rcx
    lea rsi, [rbx+REC_CODE_OFF]
    lea rdi, [edit_backup]
    test ecx, ecx
    jz .bk0
    rep movsb
.bk0:
    mov byte [rdi], 0
    mov rax, [backup_len]
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
    mov ecx, [rbx+REC_TLEN_OFF]
    mov [title_blen], rcx
    lea rsi, [rbx+REC_TITLE_OFF]
    lea rdi, [title_backup]
    test ecx, ecx
    jz .bk1
    rep movsb
.bk1:
    mov byte [rdi], 0
    mov rax, [title_blen]
    mov [title_cursor], rax
    ; language (modo 5) — snapshot p/ Esc restaurar
    mov ecx, [rbx+REC_LLEN_OFF]
    mov [lang_blen], rcx
    lea rsi, [rbx+REC_LANG_OFF]
    lea rdi, [lang_backup]
    test ecx, ecx
    jz .bk2
    rep movsb
.bk2:
    mov byte [rdi], 0
    mov rax, [lang_blen]
    mov [lang_cursor], rax
    ; tags (modo 6) — string com escape ("a\,b,c": '\,'=vírgula literal)
    mov ecx, [rbx+REC_GLEN_OFF]
    mov [tags_blen], rcx
    lea rsi, [rbx+REC_TAGS_OFF]
    lea rdi, [tags_backup]
    test ecx, ecx
    jz .bk3
    rep movsb
.bk3:
    mov byte [rdi], 0
    mov rax, [tags_blen]
    mov [tags_cursor], rax
    ; descrição (modo 7): len viva via strlen (sem célula no rec, fix #32)
    lea rsi, [rbx+REC_DESC_OFF]
    mov edx, REC_DESC_LEN
    call strlen_cap wrt ..plt
    mov [desc_len], eax
    mov [desc_blen], rax
    lea rsi, [rbx+REC_DESC_OFF]
    lea rdi, [desc_backup]
    mov ecx, eax
    test ecx, ecx
    jz .bk4
    rep movsb
.bk4:
    mov byte [rdi], 0
    mov rax, [desc_blen]
    mov [desc_cursor], rax
    mov qword [code_scroll], 0
    mov [edit_mode], r10
    call undo_reset                ; nova sessão: histórico anterior inválido
    call ensure_vis
    mov eax, 1
.ret:
    pop rbx
    ret

; ---------- undo/redo de edição (Ctrl+Z / Ctrl+Y) ----------
; Snapshot do campo em edição ANTES de cada mutação; pilhas separadas p/
; undo e redo, 1 entrada por ação (paste inteiro = 1 entrada via undo_hold).
; Trocar de campo zera o histórico (cada visita ao campo tem o seu); commit,
; cancel e begin_edit também zeram.

; undo_cur_field — eax = id do campo em edição (1=código 2=título 3=coll
; 5=language 6=tags 7=desc), 0 = fora de edição de texto. Leaf.
undo_cur_field:
    mov eax, [edit_mode]
    cmp eax, 1
    je .ok
    cmp eax, 2
    je .ok
    cmp eax, 3
    je .ok
    cmp eax, 5
    je .ok
    cmp eax, 6
    je .ok
    cmp eax, 7
    je .ok
    xor eax, eax
.ok:
    ret

; undo_reset — esvazia undo/redo (e solta undo_hold). Leaf.
undo_reset:
    mov qword [undo_n], 0
    mov qword [redo_n], 0
    mov qword [undo_hold], 0
    mov qword [undo_run], 0
    mov qword [undo_run_field], 0
    mov qword [undo_run_end], 0
    mov qword [undo_run_class], 0
    mov qword [undo_run_time], 0
    mov qword [undo_run_seal], 0
    mov qword [undo_skip], 0
    ret

; undo_capture(eax=id do campo, rdi=entrada) — copia campo+len+cursor.
; eax 1 ok / 0 inválido. Preserva rbx,r11-r15 do chamador.
undo_capture:
    push rbx
    push r11
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                      ; 6 pushes + sub: calls alinhados (fix #19)
    mov r15, rdi                    ; dst (rdi morre nos calls abaixo)
    mov r14d, eax                   ; id
    mov [r15+UE_FIELD], r14
    cmp r14d, 3
    je .coll
    call resolve_rec
    test eax, eax
    jz .bad
    cmp r14d, 2
    je .title
    cmp r14d, 5
    je .fld
    cmp r14d, 6
    je .fld
    cmp r14d, 7
    je .fld
    cmp r14d, 1
    jne .bad
    lea r13, [rbx+REC_CODE_OFF]
    mov eax, [rbx+REC_CLEN_OFF]    ; dword!
    mov [r15+UE_LEN], rax
    mov rax, [edit_cursor]
    mov [r15+UE_CURSOR], rax
    jmp .copy
.title:
    lea r13, [rbx+REC_TITLE_OFF]
    mov eax, [rbx+REC_TLEN_OFF]
    mov [r15+UE_LEN], rax
    mov rax, [title_cursor]
    mov [r15+UE_CURSOR], rax
    jmp .copy
.fld:
    call field_setup               ; rdi=base rsi=&len rdx=&cursor
    test eax, eax
    jz .bad
    mov r13, rdi
    mov eax, [rsi]                 ; dword!
    mov [r15+UE_LEN], rax
    mov rax, [rdx]
    mov [r15+UE_CURSOR], rax
    jmp .copy
.coll:
    call coll_cur                  ; eax=k, rdi=base
    cmp eax, 0
    jl .bad
    mov r13, rdi
    mov r12d, eax
    mov eax, [coll_lens+r12*4]
    mov [r15+UE_LEN], rax
    mov rax, [coll_cursor]
    mov [r15+UE_CURSOR], rax
.copy:
    mov rcx, [r15+UE_LEN]
    mov rsi, r13
    lea rdi, [r15+UE_BYTES]
    rep movsb
    mov eax, 1
    jmp .out
.bad:
    xor eax, eax
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop rbx
    ret

; undo_push — snapshot do campo atual no topo do undo; limpa o redo.
; No-op fora de edição ou em mutação sem efeito (não come profundidade).
; Totalmente transparente: preserva TODOS os regs e flags do chamador
; (pode ser chamada no meio de mutadores com char em al/dl).
undo_push:
    push rbx
    push r11
    push r12
    push r13
    push r14
    push r15
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    pushfq
    ; 15 pushes = 120B: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call undo_cur_field
    test eax, eax
    jz .out
    mov r14d, eax
    lea rdi, [undo_tmp]
    mov eax, r14d
    call undo_capture
    test eax, eax
    jz .out
    mov rax, [undo_n]
    test rax, rax
    jz .store
    dec rax
    imul rax, rax, UNDO_ENTRY
    lea rsi, [undo_buf+rax]        ; topo atual
    cmp qword [rsi+UE_FIELD], r14
    jne .reset
    mov rcx, [undo_tmp+UE_LEN]
    cmp rcx, [rsi+UE_LEN]
    jne .store
    lea rdi, [undo_tmp+UE_BYTES]
    lea rsi, [rsi+UE_BYTES]
    mov edx, ecx
    call j_memeq wrt ..plt         ; 0 = igual
    test eax, eax
    jz .out                        ; sem efeito: não empurra nem limpa redo
    jmp .store
.reset:
    mov qword [undo_n], 0          ; outro campo: recomeça o histórico
    mov qword [redo_n], 0
.store:
    cmp qword [undo_n], UNDO_DEPTH
    jb .nosub
    lea rsi, [undo_buf+UNDO_ENTRY] ; cheio: descarta o mais antigo
    lea rdi, [undo_buf]
    mov ecx, (UNDO_DEPTH-1)*UNDO_ENTRY
    rep movsb
    dec qword [undo_n]
.nosub:
    mov rax, [undo_n]
    imul rax, rax, UNDO_ENTRY
    lea rdi, [undo_buf+rax]
    lea rsi, [undo_tmp]
    mov ecx, UNDO_ENTRY
    rep movsb
    inc qword [undo_n]
    mov qword [redo_n], 0
.out:
    popfq
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop rbx
    ret

; wordclass(al=char) — eax 1 se "word" ([0-9A-Za-z_] ou byte UTF-8 >=0x80).
; Multibyte conta como word p/ a sequência inteira ficar no mesmo run. Leaf.
wordclass:
    cmp al, '0'
    jb .nword
    cmp al, '9'
    jbe .word
    cmp al, 'A'
    jb .nword
    cmp al, 'Z'
    jbe .word
    cmp al, '_'
    je .word
    cmp al, 'a'
    jb .nword
    cmp al, 'z'
    jbe .word
    cmp al, 0x80
    jae .word
.nword:
    xor eax, eax
    ret
.word:
    mov eax, 1
    ret

; undo_ins_hook(al=char) — push coalescido p/ inserção de 1 byte: mesma
; palavra (mesmo campo, posição contígua, mesma classe) estende o run sem
; empurrar; senão empurra (ou consome undo_skip do replace, sem push).
; Fronteira (espaço/tab/newline) é âncora de Ctrl+Z: funde p/ trás (fica com
; a palavra anterior) e sela o run — a próxima palavra sempre abre unidade
; nova, mesmo digitada na rajada (<1s). Assim "ola mundo" desfaz em 2 passos
; ("mundo", depois "ola ") em vez de sumir tudo de uma vez.
; Totalmente transparente: preserva TODOS os regs e flags do chamador.
undo_ins_hook:
    push rbx
    push r11
    push r12
    push r13
    push r14
    push r15
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    pushfq
    ; 15 pushes = 120B: entrada rsp%16==8 -> 0: calls ok
    cmp qword [undo_hold], 0
    jne .out                        ; paste: unidade única da entrada
    mov r15b, al                    ; ch (r15 restaurado no epílogo)
    call undo_cur_field
    test eax, eax
    jz .out
    mov r14d, eax                   ; fid
    cmp r14d, 3
    je .collcur
    cmp r14d, 2
    je .titlecur
    cmp r14d, 5
    je .langcur
    cmp r14d, 6
    je .tagscur
    cmp r14d, 7
    je .desccur
    cmp r14d, 1
    jne .out
    mov r13, [edit_cursor]
    jmp .havepos
.titlecur:
    mov r13, [title_cursor]
    jmp .havepos
.collcur:
    mov r13, [coll_cursor]
    jmp .havepos
.langcur:
    mov r13, [lang_cursor]
    jmp .havepos
.tagscur:
    mov r13, [tags_cursor]
    jmp .havepos
.desccur:
    mov r13, [desc_cursor]
.havepos:
    mov al, r15b
    call wordclass                   ; eax = classe (leaf: só rax)
    mov r12d, eax
    cmp qword [undo_run], 0
    je .newrun
    cmp qword [undo_run_field], r14
    jne .newrun
    cmp qword [undo_run_end], r13
    jne .newrun
    ; fronteira (espaço/tab/newline) é âncora: funde p/ trás e sela o run;
    ; a próxima palavra abre unidade nova mesmo na rajada.
    cmp r15b, 0x20
    je .boundary
    cmp r15b, 0x09
    je .boundary
    cmp r15b, 0x0A
    je .boundary
    cmp qword [undo_run_seal], 0
    jne .newrun                      ; selado: palavra nova após fronteira
    cmp qword [undo_run_class], r12
    je .extend                       ; mesma classe: sempre estende
    call now_ms wrt ..plt           ; classe diferente: só na rajada (<1s)
    sub rax, [undo_run_time]
    cmp rax, UNDO_BURST_MS
    jae .newrun                      ; pausa longa: nova unidade
    add rax, [undo_run_time]         ; rax = now de novo
    jmp .extendts
.extend:
    call now_ms wrt ..plt           ; rax = now
.extendts:
    inc qword [undo_run_end]         ; mesma palavra/rajada: sem push
    mov [undo_run_time], rax
    jmp .out
.boundary:
    inc qword [undo_run_end]         ; fronteira funde p/ trás, sem push
    mov qword [undo_run_seal], 1     ; ...e sela: próxima palavra = nova unidade
    call now_ms wrt ..plt
    mov [undo_run_time], rax
    jmp .out
.newrun:
    cmp qword [undo_skip], 0
    je .push
    mov qword [undo_skip], 0        ; replace: o delete já empurrou
    jmp .openrun
.push:
    mov eax, r14d
    call undo_push                   ; transparente (aninhado ok)
.openrun:
    mov qword [undo_run], 1
    mov qword [undo_run_field], r14
    lea rax, [r13+1]
    mov [undo_run_end], rax
    mov [undo_run_class], r12
    ; o char que abre o run já pode ser fronteira (espaços/tab à frente da
    ; palavra): sela de saída p/ a 1ª palavra virar unidade própria.
    mov qword [undo_run_seal], 0
    cmp r15b, 0x20
    je .seal1
    cmp r15b, 0x09
    je .seal1
    cmp r15b, 0x0A
    jne .seal0
.seal1:
    mov qword [undo_run_seal], 1
.seal0:
    call now_ms wrt ..plt
    mov [undo_run_time], rax
.out:
    popfq
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop rbx
    ret

; undo_del_hook — push + fecha o run (delete/replace sempre quebram a palavra;
; paste em andamento ignora: a unidade única já foi empurrada na entrada).
; Não usa regs do chamador; flags no hook-site estão mortas (início de proc).
undo_del_hook:
    sub rsp, 8                      ; sem pushes: alinha p/ call (fix #19)
    cmp qword [undo_hold], 0
    jne .out
    call undo_push                   ; transparente
    mov qword [undo_run], 0
    mov qword [undo_run_seal], 0
.out:
    add rsp, 8
    ret

; undo_restore(rsi=entrada) — aplica bytes+len+cursor no campo da entrada.
; eax 1 ok / 0 inválido. Preserva rbx,r11-r15 do chamador.
undo_restore:
    push rbx
    push r11
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r15, rsi
    mov r14d, [r15+UE_FIELD]       ; dword! (id pequeno)
    cmp r14d, 3
    je .coll
    call resolve_rec
    test eax, eax
    jz .bad
    cmp r14d, 2
    je .title
    cmp r14d, 5
    je .fld
    cmp r14d, 6
    je .fld
    cmp r14d, 7
    je .fld
    cmp r14d, 1
    jne .bad
    lea r13, [rbx+REC_CODE_OFF]
    lea r12, [rbx+REC_CLEN_OFF]
    lea r11, [edit_cursor]
    jmp .apply
.title:
    lea r13, [rbx+REC_TITLE_OFF]
    lea r12, [rbx+REC_TLEN_OFF]
    lea r11, [title_cursor]
    jmp .apply
.fld:
    call field_setup               ; rdi=base rsi=&len rdx=&cursor
    test eax, eax
    jz .bad
    mov r13, rdi
    mov r12, rsi
    mov r11, rdx
    jmp .apply
.coll:
    call coll_cur
    cmp eax, 0
    jl .bad
    mov r13, rdi
    mov r12d, eax
    lea r12, [coll_lens+r12*4]
    lea r11, [coll_cursor]
.apply:
    mov ecx, [r15+UE_LEN]
    mov [r12], ecx                 ; len ANTES do rep (rep zera rcx!)
    lea rsi, [r15+UE_BYTES]
    mov rdi, r13
    rep movsb
    mov rax, [r15+UE_CURSOR]
    mov [r11], rax                 ; cursor qword
    cmp r14d, 1
    jne .ok
    call col_of_cursor             ; rbx=rec intacto
    mov [edit_goal], rax
    call ensure_vis
.ok:
    mov eax, 1
    jmp .out
.bad:
    xor eax, eax
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop rbx
    ret

; do_undo — Ctrl+Z: estado atual -> redo; topo do undo -> campo.
; eax 1 aplicou / 0 sem histórico. Totalmente transparente (regs+flags).
do_undo:
    push rbx
    push r11
    push r12
    push r13
    push r14
    push r15
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    pushfq
    ; 15 pushes = 120B: entrada rsp%16==8 -> 0: calls ok
    mov qword [undo_run], 0         ; undo/refazer abrem nova palavra depois
    mov qword [undo_run_seal], 0
    cmp qword [undo_n], 0
    je .empty
    call undo_cur_field
    test eax, eax
    jz .empty
    mov r14d, eax
    cmp r14d, 3
    je .cap
    call resolve_rec
    test eax, eax
    jz .empty
.cap:
    cmp qword [redo_n], UNDO_DEPTH
    jb .rnofull
    lea rsi, [redo_buf+UNDO_ENTRY] ; redo cheio: descarta o mais antigo
    lea rdi, [redo_buf]
    mov ecx, (UNDO_DEPTH-1)*UNDO_ENTRY
    rep movsb
    dec qword [redo_n]
.rnofull:
    mov rax, [redo_n]
    imul rax, rax, UNDO_ENTRY
    lea rdi, [redo_buf+rax]
    mov eax, r14d
    call undo_capture
    test eax, eax
    jz .empty
    inc qword [redo_n]
    dec qword [undo_n]
    mov rax, [undo_n]
    imul rax, rax, UNDO_ENTRY
    lea rsi, [undo_buf+rax]
    call undo_restore
    test eax, eax
    jz .empty
    mov qword [sel_active], 0      ; âncoras de seleção obsoletas
    lea rsi, [m_undo]
    mov edx, m_undo_len
    call set_msg
    mov eax, 1
    jmp .out
.empty:
    lea rsi, [m_noundo]
    mov edx, m_noundo_len
    call set_msg
    xor eax, eax
.out:
    popfq
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop rbx
    ret

; do_redo — Ctrl+Y: estado atual -> undo; topo do redo -> campo.
; eax 1 aplicou / 0 sem histórico. Totalmente transparente (regs+flags).
do_redo:
    push rbx
    push r11
    push r12
    push r13
    push r14
    push r15
    push rax
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    pushfq
    ; 15 pushes = 120B: entrada rsp%16==8 -> 0: calls ok
    mov qword [undo_run], 0
    mov qword [undo_run_seal], 0
    cmp qword [redo_n], 0
    je .rempty
    call undo_cur_field
    test eax, eax
    jz .rempty
    mov r14d, eax
    cmp r14d, 3
    je .rcap
    call resolve_rec
    test eax, eax
    jz .rempty
.rcap:
    cmp qword [undo_n], UNDO_DEPTH
    jb .unofull
    lea rsi, [undo_buf+UNDO_ENTRY] ; undo cheio: descarta o mais antigo
    lea rdi, [undo_buf]
    mov ecx, (UNDO_DEPTH-1)*UNDO_ENTRY
    rep movsb
    dec qword [undo_n]
.unofull:
    mov rax, [undo_n]
    imul rax, rax, UNDO_ENTRY
    lea rdi, [undo_buf+rax]
    mov eax, r14d
    call undo_capture
    test eax, eax
    jz .rempty
    inc qword [undo_n]
    dec qword [redo_n]
    mov rax, [redo_n]
    imul rax, rax, UNDO_ENTRY
    lea rsi, [redo_buf+rax]
    call undo_restore
    test eax, eax
    jz .rempty
    mov qword [sel_active], 0
    lea rsi, [m_redo]
    mov edx, m_redo_len
    call set_msg
    mov eax, 1
    jmp .rout
.rempty:
    lea rsi, [m_noredo]
    mov edx, m_noredo_len
    call set_msg
    xor eax, eax
.rout:
    popfq
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rax
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop rbx
    ret

; col_of_cursor — rbx=rec; eax = coluna do cursor em CARACTERES (fix #37).
; edit_goal e carets contam células, não bytes (acento = 1 célula).
col_of_cursor:
    push rbx                      ; alinha p/ charcount + preserva rec
    mov rax, [edit_cursor]
    mov rcx, rax
.cb: test rcx, rcx
    jz .done
    lea rdx, [rbx+REC_CODE_OFF]
    cmp byte [rdx+rcx-1], 10
    je .done
    dec rcx
    jmp .cb
.done:
    ; rax=cursor(byte), rcx=início da linha(byte): conta chars no intervalo
    lea rsi, [rbx+REC_CODE_OFF]
    add rsi, rcx
    sub rax, rcx
    mov ecx, eax
    call charcount
    pop rbx
    ret

; line_start(eax=pos) — rbx=rec; eax = início da linha
line_start:
    mov ecx, eax
.ls: test ecx, ecx
    jz .done
    lea rdx, [rbx+REC_CODE_OFF]
    cmp byte [rdx+rcx-1], 10
    je .done
    dec ecx
    jmp .ls
.done:
    mov eax, ecx
    ret

; linelen(eax=start) — rbx=rec; eax = tamanho da linha (sem terminador).
; CRLF conta como UM terminador e o CR não entra no len (igual ao render —
; fix #24); CR solitário é conteúdo (igual à navegação, que só vê LF).
linelen:
    mov r8d, eax
    mov ecx, [rbx+REC_CLEN_OFF]
    lea rdi, [rbx+REC_CODE_OFF]
    mov edx, r8d
.ll: cmp edx, ecx
    jae .done
    mov al, [rdi+rdx]
    cmp al, 10
    je .done
    cmp al, 13
    jne .next
    lea r9d, [rdx+1]
    cmp r9d, ecx
    jae .next
    cmp byte [rdi+r9], 10
    je .done
.next:
    inc edx
    jmp .ll
.done:
    sub edx, r8d
    mov eax, edx
    ret

; line_index(eax=pos) — rbx=rec; eax = nº da linha (0-based)
line_index:
    mov ecx, eax
    xor eax, eax
    xor edx, edx
    lea rsi, [rbx+REC_CODE_OFF]
.li: cmp edx, ecx
    jae .done
    cmp byte [rsi+rdx], 10
    jne .n
    inc eax
.n: inc edx
    jmp .li
.done:
    ret

; prev_start(eax=início de linha) — rbx=rec; eax = início da anterior
prev_start:
    test eax, eax
    jz .done
    dec eax
    jmp line_start
.done:
    ret

; utf8_step_back(rdi=base, edx=pos) — eax = início da sequência UTF-8 que
; termina em pos (pos>0). Nunca para no meio de sequência (fix #33).
; Leaf: só rax/rcx/rdx.
utf8_step_back:
    test edx, edx
    jz .zero
    dec edx
.back:
    test edx, edx
    jz .out
    mov cl, [rdi+rdx]
    cmp cl, 0x80
    jb .out
    cmp cl, 0xC0
    jae .out
    dec edx
    jmp .back
.out:
    mov eax, edx
    ret
.zero:
    xor eax, eax
    ret

; utf8_step_fwd(rdi=base, esi=len, edx=pos) — eax = pos após a sequência em
; pos (clamp em len). Lead inválido avança 1 (nunca trava). Leaf.
utf8_step_fwd:
    cmp edx, esi
    jae .atend
    mov cl, [rdi+rdx]
    cmp cl, 0x80
    jb .one
    cmp cl, 0xE0
    jb .two
    cmp cl, 0xF0
    jb .three
    cmp cl, 0xF5
    jae .one
    add edx, 4
    jmp .clamp
.three:
    add edx, 3
    jmp .clamp
.two:
    add edx, 2
    jmp .clamp
.one:
    inc edx
.clamp:
    cmp edx, esi
    jbe .out
    mov edx, esi
    jmp .out
.atend:
    mov edx, esi
.out:
    mov eax, edx
    ret

; charcount(rsi=ptr, ecx=len) — eax = nº de caracteres UTF-8 (bytes fora de
; 80..BF). Grade 9px é por CARACTERE; cursores/carets usam isto (fix #37:
; acento de 2 bytes deslocava o caret uma célula p/ direita).
; Leaf: clobbers rax rcx rdx. Preserva rbx rsi rdi r8-r15.
charcount:
    xor eax, eax
    xor edx, edx
.cc_l:
    cmp edx, ecx
    jae .cc_done
    cmp byte [rsi+rdx], 0x80
    jb .cc_one
    cmp byte [rsi+rdx], 0xBF
    ja .cc_one
    inc edx                       ; continuação: pula sem contar
    jmp .cc_l
.cc_one:
    inc eax
    inc edx
    jmp .cc_l
.cc_done:
    ret

; bytecol(rsi=ptr, ecx=maxlen, edx=col_chars) — eax = offset em bytes do
; char nº edx (clamp em maxlen, sem partir sequência). Inverso do charcount.
; Leaf: clobbers rax rcx rdx rsi r8 r9 (SEM pushes: harness C usa red-zone).
; Preserva rbx r10 r11 r12-r15 rbp rsp.
bytecol:
    xor eax, eax
    xor r8d, r8d
.bc_l:
    cmp r8d, edx
    jae .bc_done
    cmp eax, ecx
    jae .bc_done
    mov r9b, [rsi+rax]
    inc eax
    cmp r9b, 0x80
    jb .bc_one
    cmp r9b, 0xE0
    jb .bc_two
    cmp r9b, 0xF0
    jb .bc_three
    cmp r9b, 0xF5
    jae .bc_one
    add eax, 3
    jmp .bc_cl
.bc_three:
    add eax, 2
    jmp .bc_cl
.bc_two:
    inc eax
    jmp .bc_cl
.bc_one:
.bc_cl:
    cmp eax, ecx
    jbe .bc_ok
    mov eax, ecx
    jmp .bc_done
.bc_ok:
    inc r8d
    jmp .bc_l
.bc_done:
    ret

; ---------- soft wrap do código (só desenho; buffer/DB intactos) ----------
; Uma linha lógica com mais de CODE_WRAP células ocupa várias faixas visuais
; de CODE_WRAP células. Scroll/navegação/seleção/undo continuam em linhas
; lógicas e offsets absolutos; só render, caret e click passam pelas faixas.

; wrap_rows(rsi=ptr, ecx=len bytes) — eax = nº de faixas visuais (≥1).
; Leaf (só usa o que charcount usa: rax/rcx/rdx).
wrap_rows:
    sub rsp, 8                      ; sem pushes: alinha p/ call (fix #19)
    call charcount                 ; eax = células
    add rsp, 8
    add eax, CODE_WRAP - 1
    mov ecx, CODE_WRAP
    xor edx, edx
    div ecx                        ; eax = teto
    test eax, eax
    jnz .done
    mov eax, 1                     ; linha vazia ocupa 1 faixa
.done:
    ret

; wrap_vrow(rsi=base, ecx=total bytes, edx=abs_off, r8d=scroll_linhas) —
; eax = faixa visual RELATIVA ao scroll do byte (signed: <0 acima da vista),
; edx = coluna na faixa (células, 0..CODE_WRAP-1).
; Preserva rbx/r12-r15 do chamador.
wrap_vrow:
    push rbx
    push r12
    push r13
    push r14
    push r15
    ; 5 pushes: entrada rsp%16==8 -> 0: calls ok, sem sub (fix #19)
    mov r15, rsi                    ; base
    mov r12d, ecx                   ; total
    mov r13d, edx                   ; alvo
    xor r9d, r9d                    ; vrow abs
    xor r10d, r10d                  ; faixas puladas (linhas < scroll)
    xor r11d, r11d                  ; idx lógico
    xor r14d, r14d                  ; pos abs
.nextline:
    mov eax, r14d                   ; scan [\n] a partir da pos
.snl:
    cmp eax, r12d
    jae .havelen
    cmp byte [r15+rax], 10
    je .havelen
    inc eax
    jmp .snl
.havelen:
    sub eax, r14d                   ; eax = len bytes da linha
    mov rdi, rax                    ; len (rdi sobrevive ao charcount)
    lea rsi, [r15+r14]
    mov ecx, eax
    call charcount                  ; eax = células (full)
    mov rbx, rax                    ; fullcells
    mov edx, r13d
    sub edx, r14d                   ; edx = off bytes do alvo na linha
    cmp edx, edi
    ja .advline                     ; além do \n? próxima linha
    lea rsi, [r15+r14]
    mov ecx, edx
    call charcount                  ; eax = células antes do alvo
    mov ecx, CODE_WRAP
    mov esi, eax
    xor edx, edx
    mov eax, esi
    div ecx                         ; eax = faixa, edx = coluna
    cmp r11d, r8d                   ; linha < scroll?
    jae .normal
    mov r9d, eax                    ; faixa salva (vrow==puladas aqui)
    mov r10d, edx                   ; coluna salva
    mov eax, ebx                    ; fullcells -> faixas da linha
    add eax, CODE_WRAP - 1
    mov ecx, CODE_WRAP
    xor edx, edx
    div ecx
    test eax, eax
    jnz .arows
    mov eax, 1
.arows:
    mov ecx, r9d
    sub ecx, eax                    ; faixa - faixas = rel (≤0, acima da vista)
    mov eax, ecx
    mov edx, r10d                   ; coluna
    jmp .out
.normal:
    add r9d, eax                    ; vrow abs += faixa
    mov eax, r9d
    sub eax, r10d                   ; rel
    jmp .out                        ; edx = coluna
.advline:
    mov eax, ebx                    ; fullcells (células, não bytes!)
    add eax, CODE_WRAP - 1
    mov ecx, CODE_WRAP
    xor edx, edx
    div ecx
    test eax, eax
    jnz .gotrows
    mov eax, 1
.gotrows:
    cmp r11d, r8d                   ; linha < scroll?
    jae .noskip
    add r10d, eax                   ; puladas += faixas
.noskip:
    add r9d, eax
    add r14d, edi                   ; pos += len
    cmp r14d, r12d
    jae .tail                       ; fim do buffer
    inc r14d                        ; pula \n
    inc r11d
    jmp .nextline
.tail:
    ; alvo == total no fim sem \n? cai na última faixa da última linha
    mov eax, r9d
    sub eax, r10d
    xor edx, edx
    jmp .out
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; wrap_vrow_off(rsi=base, ecx=total bytes, edx=faixa visual RELATIVA,
; r8d=scroll_linhas) — eax = abs byte offset do início da faixa, edx = chunk
; dentro da linha. Fail-safe: além do fim → fim do buffer.
; Preserva rbx/r12-r15 do chamador.
wrap_vrow_off:
    push rbx
    push r12
    push r13
    push r14
    push r15
    ; 5 pushes: entrada rsp%16==8 -> 0: calls ok, sem sub (fix #19)
    mov r15, rsi                    ; base
    mov r12d, ecx                   ; total
    xor r9d, r9d                    ; faixas puladas (linhas < scroll)
    xor r11d, r11d                  ; idx lógico
    xor r14d, r14d                  ; pos abs
    ; fase 1: soma as faixas das linhas < scroll
.sk1:
    cmp r11d, r8d
    jae .havebase
    mov eax, r14d                   ; scan [\n]
.snl1:
    cmp eax, r12d
    jae .eob1
    cmp byte [r15+rax], 10
    je .eob1
    inc eax
    jmp .snl1
.eob1:
    sub eax, r14d                   ; len da linha
    lea rsi, [r15+r14]
    mov ecx, eax
    mov r13d, eax                   ; len salvo (r13 livre: alvo ainda não usado)
    call charcount
    mov edi, eax
    add eax, CODE_WRAP - 1
    mov ecx, CODE_WRAP
    xor edx, edx
    div ecx
    test eax, eax
    jnz .r1
    mov eax, 1
.r1:
    add r9d, eax                    ; puladas += faixas
    add r14d, r13d
    cmp r14d, r12d
    jae .pastend
    inc r14d
    inc r11d
    jmp .sk1
.havebase:
    mov r10d, edx
    add r10d, r9d                   ; alvo abs (r10: charcount não toca)
    xor r11d, r11d
    xor r14d, r14d
.walk:
    mov eax, r14d                   ; scan [\n]
.snl2:
    cmp eax, r12d
    jae .eob2
    cmp byte [r15+rax], 10
    je .eob2
    inc eax
    jmp .snl2
.eob2:
    sub eax, r14d
    mov r13d, eax                   ; len salvo
    lea rsi, [r15+r14]
    mov ecx, eax
    call charcount
    mov edi, eax
    add eax, CODE_WRAP - 1
    mov ecx, CODE_WRAP
    xor edx, edx
    div ecx
    test eax, eax
    jnz .r2
    mov eax, 1
.r2:
    cmp r10d, eax                   ; alvo < faixas desta linha?
    jb .found
    sub r10d, eax
    add r14d, r13d
    cmp r14d, r12d
    jae .pastend
    inc r14d
    jmp .walk
.found:
    mov eax, r14d                   ; início da linha
    mov edx, r10d                   ; chunk
    jmp .out
.pastend:
    mov eax, r12d                   ; fim do buffer
    xor edx, edx
.out:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ensure_vis — ajusta code_scroll p/ cursor visível
ensure_vis:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    ; auto-suficiente: resolve o rec via cur_rec. Antes assumia rbx=rec, e os
    ; atalhos de troca de campo (Enter nas tags / Tab titulo->codigo) chamavam
    ; com rbx=lixo -> line_index lia [2+256] e segfaultava (si_addr=0x102).
    call resolve_rec
    test eax, eax
    jz .done
    mov rax, [edit_cursor]
    call line_index
    mov rcx, [code_scroll]
    cmp rax, rcx
    jb .set
    mov rdx, rcx
    add rdx, CODE_ROWS
    cmp rax, rdx
    jb .done
    sub rax, CODE_ROWS - 1
    mov [code_scroll], rax
    jmp .done
.set:
    mov [code_scroll], rax
.done:
    add rsp, 8
    ret

; edit_insert(al=char)
edit_insert:
    push rbx
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call undo_ins_hook              ; al=char; mesma palavra coalesce
    mov dl, al                      ; ch (cur_rec preserva rdx? usa só rax — ok)
    call resolve_rec
    test eax, eax
    jz .ret
    mov eax, [rbx+REC_CLEN_OFF]
    cmp eax, REC_CODE_LEN - 1
    jae .full
    lea rdi, [rbx+REC_CODE_OFF]
    mov rcx, [edit_cursor]
    mov eax, [rbx+REC_CLEN_OFF]     ; dword! mov rax leria 8B (lixo do fav/id)
    cmp rax, rcx
    jbe .ins
    dec rax
.mv: mov r10b, [rdi+rax]
    mov [rdi+rax+1], r10b
    cmp rax, rcx
    je .ins
    dec rax
    jmp .mv
.ins:
    mov [rdi+rcx], dl
    mov eax, [rbx+REC_CLEN_OFF]
    inc eax
    mov [rbx+REC_CLEN_OFF], eax
    mov byte [rdi+rax], 0
    mov rax, rcx
    inc rax
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
    jmp .ret
.full:
    lea rsi, [m_full]
    mov edx, m_full_len
    call set_msg
.ret:
    pop rbx
    ret

; sel_copy — copia a seleção [a,b) do código p/ o clipboard (snapshot em
; clip_buf + claim). eax = bytes (>0 ok), 0 = sem seleção, -1 = clipboard
; ocupado (não copiou). Preserva rbx.
sel_copy:
    push rbx
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19)
    cmp qword [sel_active], 0
    je .none
    call resolve_rec
    test eax, eax
    jz .none
    cmp rbx, [sel_rec]
    jne .none
    mov r8, [sel_a]
    mov r9, [sel_b]
    cmp r8, r9
    je .none
    cmp r8, r9
    jbe .rok
    xchg r8, r9
.rok:
    mov eax, [rbx+REC_CLEN_OFF]     ; dword!
    cmp r8, rax
    jae .none                       ; âncora além do fim: nada a copiar
    cmp r9, rax
    jbe .rok2
    mov r9, rax
.rok2:
    cmp r8, r9
    jae .none
    lea rsi, [rbx+REC_CODE_OFF]
    add rsi, r8
    mov rcx, r9
    sub rcx, r8                     ; rcx = n bytes
    mov [clip_len], ecx            ; ANTES do rep (que zera rcx); dword!
    lea rdi, [clip_buf]
    rep movsb
    lea rax, [clip_buf]
    mov [clip_ptr], rax
    call platform_claim_clipboard wrt ..plt
    test eax, eax
    jz .busy
    mov eax, [clip_len]
    jmp .ret
.busy:
    mov eax, -1
    jmp .ret
.none:
    xor eax, eax
.ret:
    pop rbx
    ret

; sel_delete_range — apaga [min(a,b), max(a,b)) do código (rbx=rec via
; resolve_rec) sem mexer no clipboard. Consome a seleção (sel_active=0).
; eax = bytes removidos (0 = sem seleção). Cursor vai p/ o início.
; Preserva rbx.
sel_delete_range:
    push rbx
    ; 1 push: calls ok (fix #19)
    call undo_del_hook
    cmp qword [sel_active], 0
    je .none
    call resolve_rec
    test eax, eax
    jz .none
    cmp rbx, [sel_rec]
    jne .none
    mov r8, [sel_a]
    mov r9, [sel_b]
    cmp r8, r9
    je .none
    cmp r8, r9
    jbe .rok
    xchg r8, r9
.rok:
    mov eax, [rbx+REC_CLEN_OFF]     ; dword!
    cmp r8, rax
    jae .none
    cmp r9, rax
    jbe .rok2
    mov r9, rax
.rok2:
    sub r9, r8                      ; r9 = n bytes
    jbe .none
    mov r10, r9                     ; n salvo
    lea rdi, [rbx+REC_CODE_OFF]
    add rdi, r8                     ; dst = base+a
    mov rcx, rax
    sub rcx, r8
    sub rcx, r10                    ; rcx = bytes após o trecho
    jz .nomv
    lea rsi, [rbx+REC_CODE_OFF]
    mov rax, r8
    add rax, r10
    add rsi, rax                    ; src = base+a+n
    rep movsb
.nomv:
    mov eax, [rbx+REC_CLEN_OFF]
    sub eax, r10d
    mov [rbx+REC_CLEN_OFF], eax
    mov qword [undo_skip], 1        ; replace: o insert seguinte não empurra
    lea rdi, [rbx+REC_CODE_OFF]
    mov byte [rdi+rax], 0
    mov [edit_cursor], r8
    mov qword [sel_active], 0       ; seleção consumida
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
    mov eax, r10d
    jmp .ret
.none:
    xor eax, eax
.ret:
    pop rbx
    ret

; sel_maybe_delete — se há seleção de código no rec atual, apaga o trecho
; (sem clipboard) e retorna 1; senão limpa eventual seleção obsoleta e
; retorna 0 (chamador segue o fluxo normal). Preserva rbx.
sel_maybe_delete:
    push rbx
    ; 1 push: calls ok (fix #19)
    cmp qword [sel_active], 0
    je .proceed
    call resolve_rec
    test eax, eax
    jz .clear
    cmp qword [edit_mode], 1
    jne .clear                       ; seleção é sempre do código
    cmp rbx, [sel_rec]
    jne .clear
    mov rax, [sel_a]
    cmp rax, [sel_b]
    je .clear                        ; vazia: limpa e segue
    call sel_delete_range
    mov eax, 1
    jmp .ret
.clear:
    mov qword [sel_active], 0
.proceed:
    xor eax, eax
.ret:
    pop rbx
    ret

; paste_insert — insere paste_buf[0..paste_len) no alvo atual e avisa.
; Alvos: código(1)/título(2)/coll(3)/busca(0)/lang-tags-desc(5,6,7, via fld);
; modo 4 (seletor) descarta em silêncio. Conta o inserido de verdade (len
; depois - len antes): os helpers truncam no cap em silêncio e o "colado: N"
; precisa ser honesto. Byte a byte como o kpend: sequência UTF-8 preservada.
; Preserva rbx.
paste_insert:
    push rbx
    sub rsp, 32                     ; slots: rest,idx,len0,(reserva)
    ; bal 8+32=40 ≡ 8: calls ok (fix #19)
    mov eax, [paste_len]
    mov [rsp], eax                  ; rest (dword)
    mov qword [rsp+8], 0            ; idx
    call undo_push                  ; 1 snapshot p/ o paste inteiro
    mov qword [undo_hold], 1        ; loops byte a byte não empurram
    call sel_maybe_delete           ; com seleção no código: cola por cima
    mov eax, [edit_mode]
    cmp eax, 1
    je .ppcode
    cmp eax, 2
    je .pptitle
    cmp eax, 3
    je .ppcoll
    cmp eax, 5
    je .ppfld
    cmp eax, 6
    je .ppfld
    cmp eax, 7
    je .ppfld
    cmp eax, 4
    je .ppret                       ; seletor aberto: descarta em silêncio
    jmp .ppsearch
.ppcode:
    call resolve_rec
    test eax, eax
    jz .ppret
    mov eax, [rbx+REC_CLEN_OFF]     ; dword!
    mov [rsp+16], eax               ; len0
.ppcodeloop:
    mov eax, [rsp]
    test eax, eax
    jz .ppcodeend
    mov rcx, [rsp+8]
    mov al, [paste_buf+rcx]
    call edit_insert
    inc qword [rsp+8]
    dec dword [rsp]
    jmp .ppcodeloop
.ppcodeend:
    mov eax, [rbx+REC_CLEN_OFF]     ; rbx intacto (edit_insert preserva)
    sub eax, [rsp+16]
    jmp .ppdone
.pptitle:
    call resolve_rec
    test eax, eax
    jz .ppret
    mov eax, [rbx+REC_TLEN_OFF]     ; dword!
    mov [rsp+16], eax
.pptitleloop:
    mov eax, [rsp]
    test eax, eax
    jz .pptitleend
    mov rcx, [rsp+8]
    mov al, [paste_buf+rcx]
    call title_insert
    inc qword [rsp+8]
    dec dword [rsp]
    jmp .pptitleloop
.pptitleend:
    mov eax, [rbx+REC_TLEN_OFF]
    sub eax, [rsp+16]
    jmp .ppdone
.ppcoll:
    call coll_cur
    cmp eax, 0
    jl .ppret
    mov r11d, eax
    mov eax, [coll_lens+r11*4]
    mov [rsp+16], eax
.ppcolloop:
    mov eax, [rsp]
    test eax, eax
    jz .ppcolend
    mov rcx, [rsp+8]
    mov al, [paste_buf+rcx]
    call coll_insert
    inc qword [rsp+8]
    dec dword [rsp]
    jmp .ppcolloop
.ppcolend:
    call coll_cur
    mov r11d, eax
    mov eax, [coll_lens+r11*4]
    sub eax, [rsp+16]
    jmp .ppdone
.ppfld:
    call field_setup
    test eax, eax
    jz .ppret
    mov eax, [rsi]                  ; len via &len do setup
    mov [rsp+16], eax
.ppfldloop:
    mov eax, [rsp]
    test eax, eax
    jz .ppfldend
    call field_setup                ; re-aponta (cap varia por modo)
    test eax, eax
    jz .ppfldend
    mov rcx, [rsp+8]
    mov al, [paste_buf+rcx]
    call fld_insert
    inc qword [rsp+8]
    dec dword [rsp]
    jmp .ppfldloop
.ppfldend:
    call field_setup
    mov eax, [rsi]
    sub eax, [rsp+16]
    jmp .ppdone
.ppsearch:
    mov qword [q_focus], 1          ; colar na busca foca a busca (como digitar)
    mov qword [side_focus], 0
    mov rax, [qlen]
    mov [rsp+16], rax               ; len0 (qword)
.ppsearchloop:
    mov eax, [rsp]
    test eax, eax
    jz .ppsearchend
    mov rax, [qlen]
    cmp rax, QUERY_MAX
    jae .ppsearchend
    mov rcx, [rsp+8]
    mov dl, [paste_buf+rcx]
    mov [qbuf+rax], dl
    inc rax
    mov [qlen], rax
    inc qword [rsp+8]
    dec dword [rsp]
    jmp .ppsearchloop
.ppsearchend:
    mov rax, [qlen]
    sub rax, [rsp+16]               ; N cabe em eax (busca é curta)
    jmp .ppdone
.ppdone:
    test eax, eax
    jz .ppempty
    mov [rsp], eax                  ; reusa o slot p/ N
    lea rsi, [m_pasted]
    mov edx, m_pasted_len
    call set_msg
    mov eax, [rsp]
    lea rdi, [ibuf]
    call itoa
    lea rsi, [ibuf]
    mov edx, eax
    call append_msg
    jmp .ppout
.ppempty:
    lea rsi, [m_pempty]
    mov edx, m_pempty_len
    call set_msg
.ppout:
    mov qword [undo_hold], 0
    mov qword [undo_run], 0
    mov qword [undo_run_seal], 0
    mov qword [undo_skip], 0
    add rsp, 32
    pop rbx
    ret
.ppret:
    mov qword [undo_hold], 0
    mov qword [undo_run], 0
    mov qword [undo_run_seal], 0
    mov qword [undo_skip], 0
    add rsp, 32
    pop rbx
    ret

; edit_backspace — apaga char antes do cursor
edit_backspace:
    push rbx
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call undo_del_hook
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    test rax, rax
    jz .ret
    mov r10, rax                    ; cursor (fim da sequência a remover)
    lea rdi, [rbx+REC_CODE_OFF]
    mov edx, eax
    call utf8_step_back             ; eax = início da sequência (fix #33)
    mov [edit_cursor], rax
    sub r10, rax                    ; r10 = nbytes removidos
    mov rcx, rax                    ; dst
    mov rsi, rax
    add rsi, r10                    ; src = cursor antigo
    mov edx, [rbx+REC_CLEN_OFF]     ; dword! (r64 leria fav/id junto)
.mv: cmp rsi, rdx
    jae .mvout
    mov r11b, [rdi+rsi]
    mov [rdi+rcx], r11b
    inc rsi
    inc rcx
    jmp .mv
.mvout:
    sub dword [rbx+REC_CLEN_OFF], r10d
    mov eax, [rbx+REC_CLEN_OFF]
    mov byte [rdi+rax], 0
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
.ret:
    pop rbx
    ret

; edit_left / edit_right
edit_left:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    test rax, rax
    jz .ret
    lea rdi, [rbx+REC_CODE_OFF]
    mov edx, eax
    call utf8_step_back             ; nunca no meio de sequência (fix #33)
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
.ret:
    add rsp, 8
    ret

edit_right:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    cmp eax, [rbx+REC_CLEN_OFF]     ; eax==cursor (pequeno); cmp r64 leria 8B
    jae .ret
    lea rdi, [rbx+REC_CODE_OFF]
    mov esi, [rbx+REC_CLEN_OFF]
    mov edx, eax
    call utf8_step_fwd              ; nunca no meio de sequência (fix #33)
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
.ret:
    add rsp, 8
    ret

; coll_cur — eax = k (libsel-3) com rdi = base do nome; eax=-1 se inválido.
; Leaf: só rax/rdx/rdi/r10. libsel não muda durante o modo 3.
coll_cur:
    mov eax, [libsel]
    sub eax, 3
    jb .bad
    mov rdx, [coll_count]           ; qword! (dword seria lint + bug)
    cmp rax, rdx
    jae .bad
    mov r10d, eax
    imul eax, eax, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    mov eax, r10d
    ret
.bad:
    mov eax, -1
    ret

; coll_snapshot — nome atual -> coll_backup/blen, cursor=fim. eax 1/0.
coll_snapshot:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call coll_cur
    cmp eax, 0
    jl .bad
    mov r11d, eax
    mov rsi, rdi                    ; base do nome
    mov ecx, [coll_lens+r11*4]
    mov [coll_blen], rcx
    lea rdi, [coll_backup]
    test ecx, ecx
    jz .bk0
    rep movsb
.bk0:
    mov byte [rdi], 0
    mov rax, [coll_blen]
    mov [coll_cursor], rax
    mov eax, 1
    add rsp, 8
    ret
.bad:
    xor eax, eax
    add rsp, 8
    ret

; title_insert(al=char) — insere no título (cap 95). Edição ao vivo no rec
; (cancel restaura via title_backup).
title_insert:
    push rbx
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call undo_ins_hook
    mov dl, al
    call resolve_rec
    test eax, eax
    jz .ret
    mov eax, [rbx+REC_TLEN_OFF]
    cmp eax, REC_TITLE_LEN - 1
    jae .full
    lea rdi, [rbx+REC_TITLE_OFF]
    mov rcx, [title_cursor]
    mov eax, [rbx+REC_TLEN_OFF]     ; dword! (r64 leria lang junto)
    cmp rax, rcx
    jbe .ins
    dec rax
.mv: mov r10b, [rdi+rax]
    mov [rdi+rax+1], r10b
    cmp rax, rcx
    je .ins
    dec rax
    jmp .mv
.ins:
    mov [rdi+rcx], dl
    mov eax, [rbx+REC_TLEN_OFF]
    inc eax
    mov [rbx+REC_TLEN_OFF], eax
    mov byte [rdi+rax], 0
    inc rcx
    mov [title_cursor], rcx
    jmp .ret
.full:
    lea rsi, [m_notitle]
    mov edx, m_notitle_len
    call set_msg
.ret:
    pop rbx
    ret

; title_backspace — apaga antes do cursor do título
title_backspace:
    push rbx
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call undo_del_hook
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [title_cursor]
    test rax, rax
    jz .ret
    mov r10, rax
    lea rdi, [rbx+REC_TITLE_OFF]
    mov edx, eax
    call utf8_step_back             ; (fix #33)
    mov [title_cursor], rax
    sub r10, rax
    mov rcx, rax
    mov rsi, rax
    add rsi, r10
    mov edx, [rbx+REC_TLEN_OFF]
.mv: cmp rsi, rdx
    jae .mvout
    mov r11b, [rdi+rsi]
    mov [rdi+rcx], r11b
    inc rsi
    inc rcx
    jmp .mv
.mvout:
    mov eax, [rbx+REC_TLEN_OFF]
    sub eax, r10d                   ; L - nbytes
    mov [rbx+REC_TLEN_OFF], eax
    mov eax, [rbx+REC_TLEN_OFF]
    mov byte [rdi+rax], 0
.ret:
    pop rbx
    ret

; title_delfwd — apaga sob o cursor do título
title_delfwd:
    push rbx
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call undo_del_hook
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [title_cursor]
    mov edx, [rbx+REC_TLEN_OFF]
    cmp rax, rdx
    jae .ret
    lea rdi, [rbx+REC_TITLE_OFF]
    mov esi, edx
    mov edx, eax
    call utf8_step_fwd              ; fim da sequência (fix #33)
    mov r10d, eax                   ; F
    mov ecx, [title_cursor]         ; C
    mov esi, r10d                   ; src=F
    mov edx, [rbx+REC_TLEN_OFF]     ; L
.mv: cmp esi, edx
    jae .mvout
    mov r11b, [rdi+rsi]
    mov [rdi+rcx], r11b
    inc rsi
    inc rcx
    jmp .mv
.mvout:
    mov eax, [rbx+REC_TLEN_OFF]
    sub eax, r10d
    add eax, ecx
    mov [rbx+REC_TLEN_OFF], eax
    mov byte [rdi+rax], 0
.ret:
    pop rbx
    ret

; title_left / title_right
title_left:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [title_cursor]
    test rax, rax
    jz .ret
    lea rdi, [rbx+REC_TITLE_OFF]
    mov edx, eax
    call utf8_step_back             ; (fix #33)
    mov [title_cursor], rax
.ret:
    add rsp, 8
    ret

title_right:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [title_cursor]
    cmp eax, [rbx+REC_TLEN_OFF]
    jae .ret
    lea rdi, [rbx+REC_TITLE_OFF]
    mov esi, [rbx+REC_TLEN_OFF]
    mov edx, eax
    call utf8_step_fwd              ; (fix #33)
    mov [title_cursor], rax
.ret:
    add rsp, 8
    ret

; coll_insert(al=char) — insere no nome da coll (cap 63). Ao vivo em coll_names.
; O char vai p/ pilha: coll_cur suja rax/rdx (scratch não sobrevive a call).
coll_insert:
    sub rsp, 8
    call undo_ins_hook              ; al=char; mesma palavra coalesce
    mov [rsp], al
    call coll_cur
    cmp eax, 0
    jl .ret
    mov dl, [rsp]
    mov r11d, eax
    mov ecx, [coll_lens+r11*4]
    cmp ecx, COLL_NAME_LEN - 1
    jae .full
    mov rax, [coll_cursor]
    cmp rcx, rax
    jbe .ins
    mov rax, rcx
    dec rax
.mv: mov r10b, [rdi+rax]
    mov [rdi+rax+1], r10b
    cmp rax, [coll_cursor]
    je .ins
    dec rax
    jmp .mv
.ins:
    mov rcx, [coll_cursor]
    mov [rdi+rcx], dl
    mov ecx, [coll_lens+r11*4]
    inc ecx
    mov [coll_lens+r11*4], ecx
    mov byte [rdi+rcx], 0
    inc qword [coll_cursor]
    jmp .ret
.full:
    lea rsi, [m_collfull]
    mov edx, m_collfull_len
    call set_msg
    jmp .ret
.ret:
    add rsp, 8
    ret

; coll_backspace — apaga antes do cursor do nome
coll_backspace:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call undo_del_hook
    call coll_cur
    cmp eax, 0
    jl .ret
    mov r11d, eax
    mov rax, [coll_cursor]
    test rax, rax
    jz .ret
    mov r10, rax                    ; cursor
    mov edx, eax
    call utf8_step_back             ; rdi=base de coll_cur (fix #33)
    mov [coll_cursor], rax
    sub r10, rax                    ; nbytes
    mov rcx, rax
    mov rsi, rax
    add rsi, r10
    mov ecx, [coll_lens+r11*4]
    mov edx, ecx
.mv: cmp rsi, rdx
    jae .mvout
    mov r9b, [rdi+rsi]
    mov [rdi+rcx], r9b
    inc rsi
    inc rcx
    jmp .mv
.mvout:
    mov eax, [coll_lens+r11*4]
    sub eax, r10d
    mov [coll_lens+r11*4], eax
    mov byte [rdi+rax], 0
.ret:
    add rsp, 8
    ret

; coll_delfwd — apaga sob o cursor do nome
coll_delfwd:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call undo_del_hook
    call coll_cur
    cmp eax, 0
    jl .ret
    mov r11d, eax
    mov rax, [coll_cursor]
    mov ecx, [coll_lens+r11*4]
    cmp rax, rcx
    jae .ret
    mov esi, ecx
    mov edx, eax
    call utf8_step_fwd              ; F (fix #33; rdi=base, r11 intacto)
    mov r10d, eax
    mov ecx, [coll_cursor]
    mov esi, r10d
    mov edx, [coll_lens+r11*4]
.mv: cmp esi, edx
    jae .mvout
    mov r9b, [rdi+rsi]
    mov [rdi+rcx], r9b
    inc rsi
    inc rcx
    jmp .mv
.mvout:
    mov eax, [coll_lens+r11*4]
    sub eax, r10d
    add eax, ecx
    mov [coll_lens+r11*4], eax
    mov byte [rdi+rax], 0
.ret:
    add rsp, 8
    ret

; coll_left / coll_right
coll_left:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call coll_cur
    cmp eax, 0
    jl .ret
    mov rax, [coll_cursor]
    test rax, rax
    jz .ret
    mov edx, eax
    call utf8_step_back             ; rdi=base (fix #33)
    mov [coll_cursor], rax
.ret:
    add rsp, 8
    ret

coll_right:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call coll_cur
    cmp eax, 0
    jl .ret
    mov r11d, eax
    mov rax, [coll_cursor]
    cmp eax, [coll_lens+r11*4]
    jae .ret
    mov esi, [coll_lens+r11*4]
    mov edx, eax
    call utf8_step_fwd              ; rdi=base (fix #33)
    mov [coll_cursor], rax
.ret:
    add rsp, 8
    ret

; coll_commit_save — db_save + sai do modo 3 + msg. Em falha, restaura e
; mantém o editor aberto para retry (sem duplicar mutação).
; Preserva r12 (callee-saved; era clobberado — fix #19).
coll_commit_save:
    push r12
    ; 1 push: entrada rsp%16==8 -> 0: calls ok
    call coll_cur
    cmp eax, 0
    jl .ret
    call db_snapshot wrt ..plt
    call db_save wrt ..plt
    cmp rax, 0
    jl .cfail
    mov r12, rax
    mov qword [edit_mode], 0
    mov qword [creating_coll], -1     ; criação commitada (fix #26)
    call undo_reset
    lea rsi, [m_saved]
    mov edx, m_saved_len
    call set_msg
    mov eax, r12d
    lea rdi, [ibuf]
    call itoa
    lea rsi, [ibuf]
    mov edx, eax
    call append_msg
    jmp .ret
.cfail:
    call db_restore wrt ..plt
    mov rax, [coll_blen]
    mov [coll_cursor], rax
    lea rsi, [m_fail]
    mov edx, m_fail_len
    call set_msg
.ret:
    pop r12
    ret

; coll_cancel — restaura nome do backup + sai do modo 3.
; Em criação (Ctrl+G sem commit), remove a coleção (fix #26).
coll_cancel:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call coll_cur
    cmp eax, 0
    jl .out
    cmp rax, [creating_coll]        ; rax limpo (coll_cur sempre via mov eax)
    je .unmake
    mov r11d, eax
    mov ecx, [coll_blen]
    mov [coll_lens+r11*4], ecx
    lea rsi, [coll_backup]
    ; rdi = base (de coll_cur, intacto)
    test ecx, ecx
    jz .rst0
    rep movsb
.rst0:
    mov byte [rdi], 0
.out:
    mov qword [edit_mode], 0
    call undo_reset
    lea rsi, [m_cancel]
    mov edx, m_cancel_len
    call set_msg
    add rsp, 8
    ret
.unmake:
    ; Esc descartou a criação: compacta names/lens/ids/cats após k.
    ; A coleção nova não tem membros (assign exige modo 4), sem unfile.
    mov r11d, eax                   ; k (rep movsb só mexe rcx/rsi/rdi)
    mov eax, [coll_count]
    dec eax
    cmp eax, r11d
    jbe .c_countdec                 ; k é a última: sem mover
    sub eax, r11d                   ; n a mover
    mov ecx, eax
    imul ecx, ecx, COLL_NAME_LEN
    mov eax, r11d
    imul eax, eax, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    lea rsi, [rdi+COLL_NAME_LEN]
    rep movsb
    mov eax, [coll_count]
    dec eax
    sub eax, r11d
    mov ecx, eax
    imul ecx, ecx, 4
    lea rdi, [coll_lens+r11*4]
    lea rsi, [rdi+4]
    rep movsb
    mov eax, [coll_count]
    dec eax
    sub eax, r11d
    mov ecx, eax
    imul ecx, ecx, COLL_ID_LEN
    mov eax, r11d
    imul eax, eax, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    lea rsi, [rdi+COLL_ID_LEN]
    rep movsb
    mov eax, [coll_count]
    dec eax
    sub eax, r11d
    mov ecx, eax                    ; n (qwords, não bytes!) p/ rep movsq
    lea rdi, [coll_cats+r11*8]
    lea rsi, [rdi+8]
    rep movsq
.c_countdec:
    dec qword [coll_count]
    mov qword [creating_coll], -1
    mov qword [edit_mode], 0
    ; libsel apontava p/ a removida? volta p/ todos
    mov rax, [libsel]
    sub rax, 3
    cmp eax, r11d
    jne .c_nolib
    mov qword [libsel], 0
.c_nolib:
    mov qword [sel], 0
    mov qword [scroll], 0
    call undo_reset
    lea rsi, [m_unmade]
    mov edx, m_unmade_len
    call set_msg
    add rsp, 8
    ret

; edit_delfwd — apaga char sob o cursor do código (tecla Delete)
edit_delfwd:
    push rbx
    ; 1 push: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call undo_del_hook
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    mov edx, [rbx+REC_CLEN_OFF]     ; dword! (r64 leria fav/id junto)
    cmp rax, rdx
    jae .ret
    lea rdi, [rbx+REC_CODE_OFF]
    mov esi, edx
    call utf8_step_fwd              ; fim da sequência sob o cursor (#33)
    mov r10, rax                    ; r10 = fim (src da cópia)
    mov rcx, [edit_cursor]          ; dst
    mov rsi, r10
    mov edx, [rbx+REC_CLEN_OFF]
.mv: cmp rsi, rdx
    jae .mvout
    mov r11b, [rdi+rsi]
    mov [rdi+rcx], r11b
    inc rsi
    inc rcx
    jmp .mv
.mvout:
    mov ecx, [edit_cursor]          ; dword (cursor < 4KB)
    mov eax, [rbx+REC_CLEN_OFF]
    sub eax, r10d                   ; L - F
    add eax, ecx                    ; + C = L - nbytes
    mov [rbx+REC_CLEN_OFF], eax
    mov byte [rdi+rax], 0
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
.ret:
    pop rbx
    ret

; land_goal(r12d=início da linha, abs) — edit_cursor = start + byteoffset
; da coluna-alvo (edit_goal, em CARACTERES). Up/Down nunca param no meio
; de sequência UTF-8 (fix #37). Preserva rbx/r12/r13.
land_goal:
    push rbx                      ; alinha p/ calls + preserva rec
    mov r10d, r12d
    mov eax, r12d
    call linelen                    ; eax = byte len da linha
    mov r11d, eax
    lea rsi, [rbx+REC_CODE_OFF]
    add rsi, r10
    mov ecx, eax
    call charcount                  ; eax = char len da linha
    mov ecx, [edit_goal]
    cmp ecx, eax
    cmova ecx, eax                  ; goal clampado (dword, goal < 4KB)
    lea rsi, [rbx+REC_CODE_OFF]
    add rsi, r10
    mov edx, ecx
    mov ecx, r11d
    call bytecol                    ; eax = byte offset
    add eax, r10d
    mov [edit_cursor], rax
    pop rbx
    ret

; edit_up / edit_down (preservam r12/r13 p/ ps)
edit_up:
    push r12
    push r13
    sub rsp, 8
    ; 2 pushes + sub 8: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    call line_start
    test eax, eax
    jz .top
    call prev_start
    mov r12d, eax
    call land_goal
    call ensure_vis
    jmp .ret
.top:
    mov qword [edit_cursor], 0
    mov qword [edit_goal], 0
.ret:
    add rsp, 8
    pop r13
    pop r12
    ret

edit_down:
    push r12
    push r13
    sub rsp, 8
    ; 2 pushes + sub 8: entrada rsp%16==8 -> 0: calls ok (fix #19)
    call resolve_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    call line_start
    mov r12d, eax
    mov ecx, [rbx+REC_CLEN_OFF]
    lea rdx, [rbx+REC_CODE_OFF]
    mov eax, r12d
.eos: cmp eax, ecx
    jae .eof
    cmp byte [rdx+rax], 10
    je .eol
    inc eax
    jmp .eos
.eol:
    inc eax
    jmp .gotns
.eof:
    mov eax, ecx
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
    jmp .ret
.gotns:
    mov r12d, eax
    call land_goal
    call ensure_vis
.ret:
    add rsp, 8
    pop r13
    pop r12
    ret

; leave_edit_commit — sai da edição por clique fora (sidebar/lista) comitando.
; Modos 1/2/5/6/7 -> edit_commit_save; modo 3 (renomear coleção) ->
; coll_commit_save. O modo 4 (seletor) não chega aqui. Em falha de save o
; modo permanece (edit_commit_save não zera edit_mode no erro).
leave_edit_commit:
    sub rsp, 8                      ; alinha p/ o call (fix #19)
    cmp qword [edit_mode], 3
    je .coll
    call edit_commit_save
    add rsp, 8
    ret
.coll:
    call coll_commit_save
    add rsp, 8
    ret

; edit_commit_save — push versions + updatedAt + sai do edit + db_save + msg
; Preserva rbx,r12 (callee-saved, fix #19). 2 pushes + sub 8: calls alinhados.
edit_commit_save:
    push rbx
    push r12
    sub rsp, 8
    call resolve_rec
    test eax, eax
    jz .ret
    call db_snapshot wrt ..plt
    ; language vazia -> "plaintext" (default do web)
    cmp dword [rbx+REC_LLEN_OFF], 0
    jne .langok
    lea rsi, [t_plain]
    lea rdi, [rbx+REC_LANG_OFF]
    mov ecx, t_plain_len
    rep movsb
    mov byte [rdi], 0
    mov dword [rbx+REC_LLEN_OFF], t_plain_len
.langok:
    ; fix #21: versiona SÓ se o código mudou (len+bytes vs backup). Título/
    ; lang/tags iguais também não salvam nada (.nochange). Metadados reais
    ; atualizam updatedAt e salvam sem empurrar versão (.metachange).
    mov eax, [rbx+REC_CLEN_OFF]
    cmp eax, [backup_len]
    jne .codechanged
    lea rdi, [rbx+REC_CODE_OFF]
    lea rsi, [edit_backup]
    mov edx, eax
    call j_memeq wrt ..plt
    test eax, eax
    jnz .codechanged
    ; código igual: compara os 3 metadados com os snapshots do begin_edit
    mov eax, [rbx+REC_TLEN_OFF]
    cmp eax, [title_blen]
    jne .metachange
    lea rdi, [rbx+REC_TITLE_OFF]
    lea rsi, [title_backup]
    mov edx, eax
    call j_memeq wrt ..plt
    test eax, eax
    jnz .metachange
    mov eax, [rbx+REC_LLEN_OFF]
    cmp eax, [lang_blen]
    jne .metachange
    lea rdi, [rbx+REC_LANG_OFF]
    lea rsi, [lang_backup]
    mov edx, eax
    call j_memeq wrt ..plt
    test eax, eax
    jnz .metachange
    mov eax, [rbx+REC_GLEN_OFF]
    cmp eax, [tags_blen]
    jne .metachange
    lea rdi, [rbx+REC_TAGS_OFF]
    lea rsi, [tags_backup]
    mov edx, eax
    call j_memeq wrt ..plt
    test eax, eax
    jnz .metachange
    mov eax, [desc_len]
    cmp eax, [desc_blen]
    jne .metachange
    lea rdi, [rbx+REC_DESC_OFF]
    lea rsi, [desc_backup]
    mov edx, eax
    call j_memeq wrt ..plt
    test eax, eax
    jnz .metachange
    ; nada mudou: sai do edit sem save (sem versão duplicada, sem evict)
    mov qword [edit_mode], 0
    mov qword [creating_sn], -1       ; criação sem conteúdo: assume o rec vazio
    call undo_reset
    lea rsi, [m_nochange]
    mov edx, m_nochange_len
    call set_msg
    jmp .ret
.codechanged:
    call now_ms wrt ..plt             ; ms Unix (fix #18); preserva rbx
    mov r10, rax                    ; epoch-ms
    ; shift versions i=min(vnum,7)..1
    mov eax, [rbx+REC_VNUM_OFF]
    cmp eax, 7
    jbe .shn
    mov eax, 7
.shn:
    mov ecx, eax
    jecxz .noshift
.sh: mov eax, ecx
    imul eax, eax, VER_SIZE
    lea rdi, [rbx+REC_VERS_OFF+rax]
    mov eax, ecx
    dec eax
    imul eax, eax, VER_SIZE
    lea rsi, [rbx+REC_VERS_OFF+rax]
    push rcx
    mov ecx, VER_SIZE
    rep movsb
    pop rcx
    dec ecx
    jnz .sh
.noshift:
    ; entry0 = backup (cap cheia: revisão nativa completa, fix #22) + at
    lea rsi, [edit_backup]
    lea rdi, [rbx+REC_VERS_OFF]
    mov eax, [backup_len]
    mov edx, VER_CODE_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov ecx, eax
    jecxz .vnon
    rep movsb
.vnon:
    mov byte [rdi], 0
    mov [rbx+REC_VERS_OFF+VER_AT_OFF], r10
    lea rdi, [rbx+REC_VERS_OFF+VER_NOTE_OFF]
    mov byte [rdi], 0               ; nota vazia (slot reciclado pode ter lixo)
    mov eax, [rbx+REC_VNUM_OFF]
    inc eax
    mov edx, MAX_VERSIONS
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_VNUM_OFF], eax
    mov [rbx+REC_UPDATED_OFF], r10
    jmp .dosave
.metachange:
    ; só metadados: sem shift/push de versão, mas carimba e persiste
    call now_ms wrt ..plt
    mov [rbx+REC_UPDATED_OFF], rax
    mov r10, rax
.dosave:
    call db_save wrt ..plt
    cmp rax, 0
    jl .cfail
    mov r12, rax
    mov qword [edit_mode], 0
    mov qword [creating_sn], -1       ; criação commitada: Esc futuro não remove
    call undo_reset
    lea rsi, [m_saved]
    mov edx, m_saved_len
    call set_msg
    mov eax, r12d
    lea rdi, [ibuf]
    call itoa
    lea rsi, [ibuf]
    mov edx, eax
    call append_msg
    jmp .ret
.cfail:
    call db_restore wrt ..plt
    lea rsi, [m_fail]
    mov edx, m_fail_len
    call set_msg
.ret:
    add rsp, 8
    pop r12
    pop rbx
    ret

; ---------- busca ----------

; contains_ci(rdi=hay, esi=hlen, rdx=needle, ecx=nlen) — eax 1 se contém
contains_ci:
    push rbp
    mov rbp, rsp
    push r12
    ; 2 pushes = 16B, alinhado
    test ecx, ecx
    jz .yes
    mov r8d, esi
    sub r8d, ecx
    jb .no
    xor r10d, r10d                  ; pos
.outer:
    cmp r10d, r8d
    ja .no
    xor r11d, r11d                  ; j
.inner:
    cmp r11d, ecx
    jae .yes
    mov r9, r10
    add r9, r11
    mov al, [rdi+r9]
    cmp al, 'A'
    jb .h1
    cmp al, 'Z'
    ja .h1
    add al, 32
.h1:
    mov r12b, [rdx+r11]
    cmp r12b, 'A'
    jb .h2
    cmp r12b, 'Z'
    ja .h2
    add r12b, 32
.h2:
    cmp al, r12b
    jne .next
    inc r11d
    jmp .inner
.next:
    inc r10d
    jmp .outer
.yes:
    mov eax, 1
    jmp .done
.no:
    xor eax, eax
.done:
    pop r12
    pop rbp
    ret

; match_rec(rbx=rec) — eax 1 se passa no filtro atual (libsel + query)
match_rec:
    push rbp
    mov rbp, rsp
    ; sem pushes extras — calls ok; rbx preservado por contains_ci
    mov rax, [libsel]
    test rax, rax
    jz .libok
    cmp rax, 1
    je .libfav
    cmp rax, 2
    je .libunf
    sub rax, 3                      ; k da coleção
    cmp rax, [coll_count]
    jae .no
    call cid_match
    test eax, eax
    jz .no
    jmp .libok
.libfav:
    cmp byte [rbx+REC_FAV_OFF], 0
    je .no
    jmp .libok
.libunf:
    cmp byte [rbx+REC_CID_OFF], 0   ; sem coleção
    jne .no
.libok:
    mov rax, [qlen]
    test rax, rax
    jz .yes
    lea rdx, [qbuf]
    mov ecx, [qlen]
    lea rdi, [rbx+REC_TITLE_OFF]
    mov esi, [rbx+REC_TLEN_OFF]
    call contains_ci
    test eax, eax
    jnz .yes
    lea rdi, [rbx+REC_LANG_OFF]
    mov esi, [rbx+REC_LLEN_OFF]
    call contains_ci
    test eax, eax
    jnz .yes
    lea rdi, [rbx+REC_TAGS_OFF]
    mov esi, [rbx+REC_GLEN_OFF]
    call contains_ci
    test eax, eax
    jnz .yes
    lea rdi, [rbx+REC_CODE_OFF]
    mov esi, [rbx+REC_CLEN_OFF]
    call contains_ci
    test eax, eax
    jnz .yes
    ; descrição (fix #32, paridade com a busca global do web): sem célula de
    ; len no rec — strlen_cap (≤511B). Recarrega a agulha (edx era o cap).
    lea rsi, [rbx+REC_DESC_OFF]
    mov edx, REC_DESC_LEN
    call strlen_cap wrt ..plt
    mov esi, eax
    lea rdi, [rbx+REC_DESC_OFF]
    lea rdx, [qbuf]
    mov ecx, [qlen]
    call contains_ci
    test eax, eax
    jnz .yes
.no:
    xor eax, eax
    pop rbp
    ret
.yes:
    mov eax, 1
    pop rbp
    ret

; filter_rebuild — refaz filt_idx/filt_n a partir de sn_recs + query
; O limite é RECARREGADO a cada iteração: match_rec não preserva rcx/rdx.
filter_rebuild:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    ; 3 pushes = 24B, alinhado
    mov qword [filt_n], 0
    xor r12d, r12d
.loop:
    mov rcx, [sn_count]
    mov rdx, MAX_SNIPPETS
    cmp rcx, rdx
    cmova rcx, rdx
    cmp r12, rcx
    jae .done
    mov rax, r12
    imul rax, rax, REC_SIZE
    lea rbx, [sn_recs+rax]
    call match_rec                   ; preserva rbx? usa rbx como arg; r12 intacto
    test eax, eax
    jz .next
    mov rax, [filt_n]
    mov [filt_idx+rax], r12b
    inc rax
    mov [filt_n], rax
.next:
    inc r12
    jmp .loop
.done:
    pop r12
    pop rbx
    pop rbp
    ret

; id_sn_taken(rsi=candidate, ecx=len) — eax 1 se o ID já existe.
; 4 pushes + sub 8: calls alinhados (fix #19).
id_sn_taken:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov r12, rsi
    mov r13d, ecx
    xor r10d, r10d
.loop:
    mov rax, [sn_count]
    mov rdx, MAX_SNIPPETS
    cmp rax, rdx
    cmova rax, rdx
    cmp r10, rax
    jae .free
    mov rax, r10
    imul rax, rax, REC_SIZE
    lea rbx, [sn_recs+rax]
    lea rsi, [rbx+REC_ID_OFF]
    mov edx, REC_ID_LEN
    call strlen_cap wrt ..plt
    cmp eax, r13d
    jne .next
    lea rsi, [rbx+REC_ID_OFF]
    mov rdi, r12
    mov edx, r13d
    call j_memeq wrt ..plt
    test eax, eax
    jz .taken
.next:
    inc r10
    jmp .loop
.free:
    xor eax, eax
    jmp .ret
.taken:
    mov eax, 1
.ret:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; id_coll_taken(rsi=candidate, ecx=len) — eax 1 se o ID já existe.
id_coll_taken:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r11
    mov r12, rsi
    mov r13d, ecx
    xor r10d, r10d
.loop:
    mov rax, [coll_count]
    mov rdx, MAX_COLLS
    cmp rax, rdx
    cmova rax, rdx
    cmp r10, rax
    jae .free
    mov rax, r10
    imul rax, rax, COLL_ID_LEN
    lea r11, [coll_ids+rax]
    mov rsi, r11
    mov edx, COLL_ID_LEN
    call strlen_cap wrt ..plt
    cmp eax, r13d
    jne .next
    mov rsi, r11
    mov rdi, r12
    mov edx, r13d
    call j_memeq wrt ..plt
    test eax, eax
    jz .taken
.next:
    inc r10
    jmp .loop
.free:
    xor eax, eax
    jmp .ret
.taken:
    mov eax, 1
.ret:
    pop r11
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; id_stamp — r12=epoch-ms u64, r13=pid. now_ms preserva r12/r13 do caller?
; NÃO: now_ms usa r8/r9 internos mas preserva r12/r13? now_ms salva só
; rsi/rdx/r8/r9/r11 — r12/r13 do CALLER sobrevivem (não tocados). Aqui r12/r13
; são SAÍDA, então sem conflito. getpid suja só rax/rcx/r11.
id_stamp:
    sub rsp, 8                        ; alinha p/ call (fix #19; só GP/scratch)
    call now_ms wrt ..plt             ; ms Unix (fix #18; granularidade p/ ids)
    mov r12, rax
    mov eax, 39                     ; sys_getpid
    syscall
    mov r13, rax
    add rsp, 8
    ret

; make_unique_id(rdi=dst, al=prefix, r10=taken_fn) — eax=len com NUL.
; Formato curto e único: P-epoch-pid-seq, com retry na colisão.
make_unique_id:
    push rbp
    mov rbp, rsp
    push rbx
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    ; 8 pushes (64B) + sub 8: na entrada rsp%16==8 -> agora 0: calls ok (fix #19)
    mov rbx, rdi
    mov [rbx], al
    mov byte [rbx+1], '-'
    call id_stamp
.next:
    inc qword [id_seq]
    mov r14, [id_seq]
    lea rdi, [id_tmp]
    mov rax, r12
    call itoa
    mov r15d, eax
    mov byte [id_tmp+r15], '-'
    inc r15d
    lea rdi, [id_tmp+r15]
    mov rax, r13
    call itoa
    add r15d, eax
    mov byte [id_tmp+r15], '-'
    inc r15d
    lea rdi, [id_tmp+r15]
    mov rax, r14
    call itoa
    add r15d, eax
    lea rsi, [id_tmp]
    mov ecx, r15d
    call r10
    test eax, eax
    jnz .next
    lea rsi, [id_tmp]
    lea rdi, [rbx+2]
    mov ecx, r15d
    rep movsb
    mov byte [rdi], 0
    mov eax, r15d
    add eax, 2
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop rbx
    pop rbp
    ret

; make_sn_id(rdi=dst) — eax=len com NUL; único entre snippets.
make_sn_id:
    push rbp
    mov rbp, rsp
    lea r10, [id_sn_taken]
    mov al, 'n'
    call make_unique_id
    pop rbp
    ret

; make_coll_id(rdi=dst) — eax=len com NUL; único entre coleções.
make_coll_id:
    push rbp
    mov rbp, rsp
    lea r10, [id_coll_taken]
    mov al, 'c'
    call make_unique_id
    pop rbp
    ret

; itoa(rax=u64, rdi=buf[>=20]) — decimal sem NUL; retorna eax=len
; Leaf (sem calls): preserva rbx; usa r8/r9/caller-saved livremente.
; 64 bits (fix #18): timestamps em ms (~1.7e12) excedem u32; valores de 32 bits
; continuam convertendo igual (upper zerado).
itoa:
    push rbp
    mov rbp, rsp
    push rbx
    mov r8, rdi                     ; r8 = buf
    lea rcx, [rdi+20]
    mov rsi, rcx                    ; escreve de trás p/ frente
    test rax, rax
    jnz .loop
    dec rsi
    mov byte [rsi], '0'
    jmp .copy
.loop:
    mov rbx, 10
    xor edx, edx
    div rbx                         ; rax=quociente, rdx=dígito
    add dl, '0'
    dec rsi
    mov [rsi], dl
    test rax, rax
    jnz .loop
.copy:
    mov r9, rcx
    sub r9, rsi                     ; r9 = len
    mov rdi, r8                     ; dst = buf
    mov rcx, r9
    jrcxz .done
.cp:
    mov al, [rsi]
    mov [rdi], al
    inc rsi
    inc rdi
    dec rcx
    jnz .cp
.done:
    mov eax, r9d
    pop rbx
    pop rbp
    ret

; ---------- desenho ----------

; void ui_draw(void) — repinta tudo a partir do filtro atual
; rbx=rec, r12d=x cursor, r13d=len tmp, r14d=row/lines, r15d=top/y
ui_draw:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    call filter_rebuild

    ; clamp sel/scroll
    mov rax, [filt_n]
    test rax, rax
    jz .nosel
    mov rdx, [sel]
    cmp rdx, rax
    jb .selok
    mov rdx, rax
    dec rdx
    mov [sel], rdx
.selok:
    ; teto do scroll: max(filt_n-ROWS_VISIBLE,0) — sem ele, filtro que encolhe
    ; deixa linhas em branco (fix #31); depois reaplica a visibilidade.
    mov rcx, rax
    sub rcx, ROWS_VISIBLE
    jae .capok
    xor ecx, ecx
.capok:
    mov rdx, [scroll]
    cmp rdx, rcx
    jbe .vis
    mov [scroll], rcx
.vis:
    mov rcx, [scroll]
    mov rdx, [sel]
    cmp rdx, rcx
    jae .scrok
    mov [scroll], rdx
    jmp .draw
.scrok:
    sub rdx, ROWS_VISIBLE - 1
    ja .scadj
    xor edx, edx
    jmp .scset
.scadj:
    ; rdx = sel-10
.scset:
    cmp rdx, rcx
    jbe .draw
    mov [scroll], rdx
    jmp .draw
.nosel:
    mov qword [sel], 0
    mov qword [scroll], 0

.draw:
    ; --- fundo + moldura ---
    FILL 0, 0, 1280, 800, C_BG
    FILL 0, 0, 1280, 36, C_PANEL
    FILL 0, 36, 1280, 1, C_BORDER
    FILL 0, 764, 1280, 36, C_PANEL
    FILL 0, 763, 1280, 1, C_BORDER
    FILL 0, 36, 240, 727, C_PANEL
    ; destaque da sidebar: no modo 4 mostra o cursor do seletor
    ; (0=Unfiled y=126; 1+k -> y=194+28k), senão o filtro libsel
    cmp qword [edit_mode], 4
    je .sbpick
    mov eax, [libsel]
    cmp eax, 3
    jb .sblib
    sub eax, 3
    imul eax, eax, 28
    add eax, 194
    jmp .sbdraw
.sbpick:
    mov eax, [pick_sel]
    test eax, eax
    jz .sbunf
    dec eax
    imul eax, eax, 28
    add eax, 194
    jmp .sbdraw
.sbunf:
    mov eax, 126
    jmp .sbdraw
.sblib:
    imul eax, eax, 28
    add eax, 70
.sbdraw:
    mov r12d, eax
    mov edi, 4
    mov esi, r12d
    mov edx, 232
    mov ecx, 28
    mov r8d, C_SEL
    call platform_fill_rect wrt ..plt
    mov edi, 4
    mov esi, r12d
    mov edx, 2
    mov ecx, 28
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
    FILL 253, 48, 335, 30, C_BOX
    FILL 253, 48, 335, 1, C_BORDER
    FILL 253, 77, 335, 1, C_BORDER
    FILL 253, 48, 1, 30, C_BORDER
    FILL 587, 48, 1, 30, C_BORDER
    FILL 240, 36, 1, 727, C_BORDER
    FILL 600, 36, 1, 727, C_BORDER
    FILL 621, 123, 639, 1, C_BORDER

.hintdone:
    DTEXT 16, 60, C_DIM, t_library
    DTEXT 16, 90, C_TEXT, t_all
    DTEXT 16, 118, C_DIM, t_fav
    DTEXT 16, 146, C_DIM, t_unfiled
    DTEXT 16, 184, C_DIM, t_colls
    ; coleções dinâmicas (até MAX_COLLS; sidebar comporta: 194+16*28=642<772)
    mov rax, [coll_count]
    mov rdx, MAX_COLLS
    cmp rax, rdx
    cmova rax, rdx
    mov r15, rax
    xor r14d, r14d
.kloop:
    cmp r14, r15
    jae .kdone
    mov eax, r14d
    imul eax, eax, 28
    add eax, 214                        ; baseline = topo da linha+20 (igual LIBRARY)
    mov r12d, eax
    mov rax, r14
    imul rax, rax, COLL_NAME_LEN
    lea rcx, [coll_names+rax]
    mov rdx, r14
    mov r13d, [coll_lens+rdx*4]
    cmp r13d, 23
    jbe .kok
    mov r13d, 23
.kok:
    mov edi, 16
    mov esi, r12d
    mov edx, C_DIM
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    cmp qword [edit_mode], 3
    jne .kcont
    mov eax, [libsel]                   ; esta linha é a renomeada?
    sub eax, 3
    cmp r14d, eax
    jne .kcont
    mov eax, [coll_cursor]
    cmp eax, 23
    jbe .kcur
    mov eax, 23
.kcur:
    mov ecx, eax                    ; caret em CÉLULAS (fix #37)
    mov eax, r14d
    imul eax, eax, COLL_NAME_LEN
    lea rsi, [coll_names+rax]
    call charcount
    imul eax, eax, 9
    add eax, 16
    mov edi, eax
    mov esi, r12d
    sub esi, 16
    mov edx, 2
    mov ecx, 20
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
.kcont:
    inc r14
    jmp .kloop
.kdone:

    ; --- busca: borda de foco + texto/placeholder + caret ---
    cmp qword [q_focus], 0
    je .sb_noborder
    FILL 253, 48, 335, 1, C_ACCENT
    FILL 253, 77, 335, 1, C_ACCENT
    FILL 253, 48, 1, 30, C_ACCENT
    FILL 587, 48, 1, 30, C_ACCENT
.sb_noborder:
    mov rax, [qlen]
    test rax, rax
    jz .ph
    mov r13, rax
    cmp r13d, 36
    jbe .qlok
    mov r13d, 36
.qlok:
    mov edi, 263
    mov esi, 68
    mov edx, C_TEXT
    lea rcx, [qbuf]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    jmp .caret
.ph:
    ; com a busca focada o placeholder some (fica só o caret); digitando ele
    ; já não apareceria porque a query ocupa o lugar.
    cmp qword [q_focus], 0
    jne .ph_hidden
    mov edi, 263
    mov esi, 68
    mov edx, C_DIM
    lea rcx, [t_search]
    mov r8d, t_search_len
    call platform_draw_text wrt ..plt
.ph_hidden:
    xor r13d, r13d
.caret:
    cmp qword [q_focus], 0
    je .rows
    lea rsi, [qbuf]                 ; caret em CÉLULAS (fix #37)
    mov ecx, r13d
    call charcount
    imul eax, eax, 9
    add eax, 263
    mov edi, eax
    mov esi, 52
    mov edx, 2
    mov ecx, 20
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt

    ; --- linhas da lista ---
.rows:
    xor r14d, r14d
.row:
    cmp r14d, ROWS_VISIBLE
    jae .rowsdone
    mov rax, [scroll]
    add rax, r14
    cmp rax, [filt_n]
    jae .rowsdone
    mov r13, rax                    ; idx absoluto
    mov eax, r14d
    imul eax, eax, 58
    add eax, 84
    mov r15d, eax                   ; top
    cmp r13, [sel]
    jne .noselrow
    cmp qword [side_focus], 0
    jne .selrow_dim
    mov edi, 245
    mov esi, r15d
    add esi, 2
    mov edx, 351
    mov ecx, 54
    mov r8d, C_SEL
    call platform_fill_rect wrt ..plt
    mov edi, 245
    mov esi, r15d
    add esi, 2
    mov edx, 2
    mov ecx, 54
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
    jmp .noselrow
.selrow_dim:
    ; sidebar com foco: seleção da lista esmaece (sem barra de acento)
    mov edi, 245
    mov esi, r15d
    add esi, 2
    mov edx, 351
    mov ecx, 54
    mov r8d, C_BOX
    call platform_fill_rect wrt ..plt
.noselrow:
    movzx eax, byte [filt_idx+r13]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    ; título (+ estrela âmbar se fav)
    mov r13d, [rbx+REC_TLEN_OFF]
    mov edi, 261
    cmp byte [rbx+REC_FAV_OFF], 0
    je .tcap36
    mov esi, r15d
    add esi, 24
    mov edx, C_ACCENT
    lea rcx, [t_star]
    mov r8d, t_star_len
    call platform_draw_text wrt ..plt
    mov r13d, [rbx+REC_TLEN_OFF]
    cmp r13d, 34
    jbe .tt2
    mov r13d, 34
.tt2:
    mov edi, 279
    jmp .tdraw
.tcap36:
    cmp r13d, 36
    jbe .tdraw
    mov r13d, 36
.tdraw:
    mov esi, r15d
    add esi, 24
    mov edx, C_TEXT
    lea rcx, [rbx+REC_TITLE_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    ; lang (cap 14: 261+14*9+27+20*9=594 não cruza o divisor 600)
    mov r13d, [rbx+REC_LLEN_OFF]
    cmp r13d, 14
    jbe .llok
    mov r13d, 14
.llok:
    mov edi, 261
    mov esi, r15d
    add esi, 44
    mov edx, C_ACCENT
    lea rcx, [rbx+REC_LANG_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    ; " - " + tags (cap 20): x após o lang em CÉLULAS (fix #37)
    lea rsi, [rbx+REC_LANG_OFF]
    mov ecx, r13d
    call charcount
    imul eax, eax, 9
    add eax, 261
    mov r12d, eax
    mov edi, r12d
    mov esi, r15d
    add esi, 44
    mov edx, C_DIM
    lea rcx, [t_sep]
    mov r8d, t_sep_len
    call platform_draw_text wrt ..plt
    add r12d, 27
    mov r13d, [rbx+REC_GLEN_OFF]
    cmp r13d, 20
    jbe .glok
    mov r13d, 20
.glok:
    mov edi, r12d
    mov esi, r15d
    add esi, 44
    mov edx, C_DIM
    lea rcx, [rbx+REC_TAGS_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    inc r14d
    jmp .row
.rowsdone:

    cmp qword [filt_n], 0
    je .empty
    ; --- detail: usa o rec fixo durante a edição; senão o selecionado ---
    mov rax, [edit_mode]
    cmp rax, 1
    je .dpin
    cmp rax, 2
    je .dpin
    cmp rax, 5
    je .dpin
    cmp rax, 6
    je .dpin
    cmp rax, 7
    je .dpin
    jmp .dcur
.dpin:
    mov rbx, [edit_rec]
    test rbx, rbx
    jz .empty
    jmp .ddraw
.dcur:
    mov rax, [sel]
    movzx eax, byte [filt_idx+rax]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
.ddraw:
    mov r13d, [rbx+REC_TLEN_OFF]
    cmp r13d, 70
    jbe .dtlok
    mov r13d, 70
.dtlok:
    mov edi, 621
    mov esi, 89
    mov edx, C_TEXT
    lea rcx, [rbx+REC_TITLE_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    cmp qword [edit_mode], 2
    jne .tnocur
    mov eax, [title_cursor]
    cmp eax, 70
    jbe .tcok
    mov eax, 70
.tcok:
    mov ecx, eax                    ; caret em CÉLULAS (fix #37)
    lea rsi, [rbx+REC_TITLE_OFF]
    call charcount
    imul eax, eax, 9
    add eax, 621
    mov edi, eax
    mov esi, 74
    mov edx, 2
    mov ecx, 23
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
.tnocur:
    mov r13d, [rbx+REC_LLEN_OFF]
    cmp r13d, LANG_DISP_MAX          ; mesma largura do hit-test/caret (#25)
    jbe .dllok
    mov r13d, LANG_DISP_MAX
.dllok:
    mov edi, 621
    mov esi, 111
    mov edx, C_ACCENT
    lea rcx, [rbx+REC_LANG_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    lea rsi, [rbx+REC_LANG_OFF]     ; x do " - " em CÉLULAS (fix #37)
    mov ecx, r13d
    call charcount
    imul eax, eax, 9
    add eax, 621
    mov r12d, eax
    mov edi, r12d
    mov esi, 111
    mov edx, C_DIM
    lea rcx, [t_sep]
    mov r8d, t_sep_len
    call platform_draw_text wrt ..plt
    add r12d, 27
    mov r13d, [rbx+REC_GLEN_OFF]
    cmp r13d, TAGS_DISP_MAX
    jbe .dglok
    mov r13d, TAGS_DISP_MAX
.dglok:
    mov edi, r12d
    mov esi, 111
    mov edx, C_DIM
    lea rcx, [rbx+REC_TAGS_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    cmp byte [rbx+REC_FAV_OFF], 0
    je .descrow
    lea rsi, [rbx+REC_TAGS_OFF]     ; x do "- fav" em CÉLULAS (fix #37)
    mov ecx, r13d
    call charcount
    imul eax, eax, 9
    add eax, r12d
    mov edi, eax
    mov esi, 111
    mov edx, C_ACCENT
    lea rcx, [t_favtag]
    mov r8d, t_favtag_len
    call platform_draw_text wrt ..plt
.descrow:
    ; linha da descrição (fix #32): rótulo + texto truncado em DESC_DISP_MAX.
    ; Fonte: strlen (NUL é mantido pelos fld_* e pelo parser).
    mov edi, DESC_LBL_X
    mov esi, DESC_BASE_Y
    mov edx, C_DIM
    lea rcx, [t_desc]
    mov r8d, t_desc_len
    call platform_draw_text wrt ..plt
    lea rsi, [rbx+REC_DESC_OFF]
    mov edx, REC_DESC_LEN
    call strlen_cap wrt ..plt
    cmp eax, DESC_DISP_MAX
    jbe .ddescok
    mov eax, DESC_DISP_MAX
.ddescok:
    test eax, eax
    jz .curblock
    mov edi, DESC_TXT_X
    mov esi, DESC_BASE_Y
    mov edx, C_TEXT
    lea rcx, [rbx+REC_DESC_OFF]
    mov r8d, eax
    call platform_draw_text wrt ..plt
.curblock:
    ; cursor de campo 1-linha (lang/tags/desc): barra fina, não cobre o texto
    cmp qword [edit_mode], 5
    je .cur_lang
    cmp qword [edit_mode], 6
    je .cur_tags
    cmp qword [edit_mode], 7
    je .cur_desc
    jmp .codestart
.cur_lang:
    ; caret na largura EXIBIDA (fix #25): min(cursor, min(llen,24)), em CÉLULAS
    mov eax, [rbx+REC_LLEN_OFF]
    cmp eax, LANG_DISP_MAX
    jbe .cl_lenok
    mov eax, LANG_DISP_MAX
.cl_lenok:
    mov ecx, [lang_cursor]
    cmp ecx, eax
    jbe .cl_ok
    mov ecx, eax
.cl_ok:
    lea rsi, [rbx+REC_LANG_OFF]     ; (fix #37)
    call charcount
    imul eax, eax, 9
    add eax, 621
    mov r12d, eax
    jmp .cur_draw
.cur_tags:
    ; base das tags na largura exibida do lang + coluna truncada em 36
    mov eax, [rbx+REC_LLEN_OFF]
    cmp eax, LANG_DISP_MAX
    jbe .ct_lenok
    mov eax, LANG_DISP_MAX
.ct_lenok:
    mov ecx, eax                    ; base em CÉLULAS (fix #37)
    lea rsi, [rbx+REC_LANG_OFF]
    call charcount
    imul eax, eax, 9
    add eax, 648                    ; 621 + 27 (após " - ")
    mov r11d, eax                   ; base salva (charcount não toca r11)
    mov ecx, [rbx+REC_GLEN_OFF]
    cmp ecx, TAGS_DISP_MAX
    jbe .ct_glok
    mov ecx, TAGS_DISP_MAX
.ct_glok:
    mov edx, [tags_cursor]
    cmp edx, ecx
    jbe .ct_ok
    mov edx, ecx
.ct_ok:
    mov ecx, edx
    lea rsi, [rbx+REC_TAGS_OFF]
    call charcount
    imul eax, eax, 9
    add eax, r11d
    mov r12d, eax
    jmp .cur_draw
.cur_desc:
    ; caret da descrição: 675 + min(cursor, min(strlen,64)) na linha da desc
    lea rsi, [rbx+REC_DESC_OFF]
    mov edx, REC_DESC_LEN
    call strlen_cap wrt ..plt
    cmp eax, DESC_DISP_MAX
    jbe .cd_lenok
    mov eax, DESC_DISP_MAX
.cd_lenok:
    mov ecx, [desc_cursor]
    cmp ecx, eax
    jbe .cd_ok
    mov ecx, eax
.cd_ok:
    lea rsi, [rbx+REC_DESC_OFF]     ; caret em CÉLULAS (fix #37)
    call charcount
    imul eax, eax, 9
    add eax, DESC_TXT_X
    mov edi, eax
    mov esi, DESC_BASE_Y - 15
    mov edx, 2
    mov ecx, 23
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
    jmp .codestart
.cur_draw:
    mov edi, r12d
    mov esi, 96
    mov edx, 2
    mov ecx, 23
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
.codestart:
    ; cartão do editor: fundo + hairline + cantoneiras de acento (2px, 14px).
    ; Caixa: 621,171,647,552 — termina em 723 (41px de ar acima do título,
    ; 40px abaixo da caixa), bloco centralizado na área útil 36..762.
    FILL 621, 171, 647, 552, C_BOX
    FILL 621, 171, 647, 1, C_ACCENT_DIM
    FILL 621, 723, 647, 1, C_ACCENT_DIM
    FILL 621, 171, 1, 552, C_ACCENT_DIM
    FILL 1267, 171, 1, 552, C_ACCENT_DIM
    ; cantoneiras: 2px de espessura, 14px de lado, cor de acento
    FILL 621, 171, 14, 2, C_ACCENT
    FILL 621, 171, 2, 14, C_ACCENT
    FILL 1254, 171, 14, 2, C_ACCENT
    FILL 1266, 171, 2, 14, C_ACCENT
    FILL 621, 722, 14, 2, C_ACCENT
    FILL 621, 710, 2, 14, C_ACCENT
    FILL 1254, 722, 14, 2, C_ACCENT
    FILL 1266, 710, 2, 14, C_ACCENT
    ; linhas de código (pula code_scroll; máx CODE_ROWS)
    ; fix #23: scroll SÓ vale editando código (modo 1, rec fixo); detail
    ; somente-leitura sempre rende da linha zero — sem vazar scroll entre recs.
    ; fix #32: código começa em CODE_TOP_Y (linha da desc em 124).
    lea r12, [rbx+REC_CODE_OFF]
    mov r13d, [rbx+REC_CLEN_OFF]
    mov r15d, CODE_TOP_Y
    xor r14d, r14d
    cmp qword [edit_mode], 1
    je .usecroll
    xor eax, eax
    jmp .skipln
.usecroll:
    mov eax, [code_scroll]
.skipln:
    test eax, eax
    jz .cloop
    test r13d, r13d
    jz .codedone
.skip1:
    test r13d, r13d
    jz .codedone
    mov cl, [r12]
    inc r12
    dec r13d
    cmp cl, 10
    jne .skip1
    dec eax
    jmp .skipln
.cloop:
    cmp r14d, CODE_ROWS
    jae .codedone
    test r13d, r13d
    jz .codedone
    xor eax, eax
.scan:
    cmp eax, r13d
    jae .eol
    mov cl, [r12+rax]
    cmp cl, 10
    je .eol
    cmp cl, 13
    jne .snext
    ; CR: só termina linha se seguido de LF (CRLF = 1 terminador, igual à
    ; navegação/edição que só reconhece LF — fix #24). CR solitário é char.
    lea edx, [rax+1]
    cmp edx, r13d
    jae .snext
    cmp byte [r12+rdx], 10
    je .eol
.snext:
    inc eax
    jmp .scan
.eol:
    mov [rsp], eax                  ; full len (sobrevive às calls; acesso dword)
    ; sel overlap da LINHA (bytes, sem clamp de faixa): wrap_os/oe
    cmp qword [sel_active], 0
    je .chnosel
    cmp rbx, [sel_rec]
    jne .chnosel
    lea rdx, [rbx+REC_CODE_OFF]
    mov r10, r12
    sub r10, rdx                   ; r10 = abs_start da linha
    mov r11d, [rsp]                ; full len
    add r11, r10                   ; r11 = abs_end
    mov r8, [sel_a]
    mov r9, [sel_b]
    cmp r8, r9
    jbe .chord
    xchg r8, r9
.chord:
    cmp r11, r8
    jbe .chnosel                   ; linha inteira antes da seleção
    cmp r10, r9
    jae .chnosel                    ; linha inteira depois da seleção
    mov rdx, r8
    cmp rdx, r10
    cmovb rdx, r10                 ; rdx = max(s, abs_start)
    sub rdx, r10                   ; off_s (coords da linha)
    mov rcx, r9
    cmp rcx, r11
    cmova rcx, r11                 ; rcx = min(e, abs_end)
    sub rcx, r10                   ; off_e
    mov [wrap_os], edx
    mov [wrap_oe], ecx
    jmp .chloop0
.chnosel:
    mov dword [wrap_os], 0
    mov dword [wrap_oe], 0
.chloop0:
    mov qword [wrap_chunk], 0
.chunk:
    cmp r14d, CODE_ROWS
    jae .codedone
    mov rax, [wrap_chunk]
    test rax, rax
    jnz .chcb0
    xor eax, eax                    ; faixa 0 começa no byte 0
    jmp .chcb0have
.chcb0:
    imul rax, rax, CODE_WRAP
    lea rsi, [r12]
    mov ecx, [rsp]                  ; full len (maxlen)
    mov edx, eax
    call bytecol                    ; cb0 (sem partir UTF-8)
.chcb0have:
    mov [wrap_cb0], eax
    cmp eax, [rsp]
    jb .chhave
    cmp qword [wrap_chunk], 0
    je .chhave                      ; linha vazia: faixa vazia (só avança y)
    jmp .chadv
.chhave:
    mov rax, [wrap_chunk]
    inc rax
    imul rax, rax, CODE_WRAP
    lea rsi, [r12]
    mov ecx, [rsp]
    mov edx, eax
    call bytecol                    ; cb1 (clampa no fim da linha)
    mov [wrap_cb1], eax
    ; vis = [os,oe) ∩ [cb0,cb1):
    mov eax, [wrap_os]
    cmp eax, [wrap_cb0]
    jae .chvs
    mov eax, [wrap_cb0]
.chvs:
    mov [sel_o1], eax               ; vs (reusa tmp existente)
    mov edx, [wrap_oe]
    cmp edx, [wrap_cb1]
    jbe .chve
    mov edx, [wrap_cb1]
.chve:
    mov [sel_o2], edx               ; ve
    cmp eax, edx
    jae .chplain                    ; sem interseção
    ; trecho 1: [cb0, vs) normal (x=638: faixa sempre começa na borda)
    mov eax, [wrap_cb0]
    cmp eax, [sel_o1]
    jae .chsel
    lea rsi, [r12+rax]              ; ptr = line+cb0
    mov ecx, [sel_o1]
    sub ecx, eax                    ; len = vs-cb0
    mov r8d, ecx
    mov rcx, rsi
    mov edi, 638
    mov esi, r15d
    mov edx, C_CODE
    call platform_draw_text wrt ..plt
.chsel:
    ; trecho 2: [vs, ve) selecionado (fundo + texto claro)
    ; x = 638 + cells(chunk_ptr, vs-cb0)*9:
    mov eax, [wrap_cb0]
    lea rsi, [r12+rax]              ; chunk_ptr
    mov eax, [sel_o1]
    sub eax, [wrap_cb0]             ; rel
    mov ecx, eax
    call charcount
    imul edi, eax, 9
    add edi, 638                    ; x do trecho
    mov eax, [sel_o1]
    lea rsi, [r12+rax]              ; ptr = line+vs
    mov eax, [sel_o2]
    sub eax, [sel_o1]               ; selen
    mov r10d, eax                   ; salvo (charcount preserva r10)
    mov ecx, eax
    call charcount
    imul edx, eax, 9                ; w em px
    mov esi, r15d
    sub esi, 13
    mov ecx, 17
    mov r8d, C_SEL
    call platform_fill_rect wrt ..plt
    ; texto claro: mesmo x, ptr=line+vs, len=selen:
    mov eax, [wrap_cb0]
    lea rsi, [r12+rax]
    mov eax, [sel_o1]
    sub eax, [wrap_cb0]
    mov ecx, eax
    call charcount
    imul edi, eax, 9
    add edi, 638
    mov esi, r15d
    mov eax, [sel_o1]
    lea rcx, [r12+rax]
    mov eax, [sel_o2]
    sub eax, [sel_o1]
    mov r8d, eax
    mov edx, C_TEXT
    call platform_draw_text wrt ..plt
    ; trecho 3: [ve, cb1) normal
    mov eax, [sel_o2]
    cmp eax, [wrap_cb1]
    jae .chnext
    mov ecx, [wrap_cb0]
    lea rsi, [r12+rcx]              ; chunk_ptr
    mov eax, [sel_o2]
    sub eax, [wrap_cb0]             ; rel = ve-cb0
    mov ecx, eax
    call charcount
    imul edi, eax, 9
    add edi, 638
    mov esi, r15d
    mov eax, [sel_o2]
    lea rcx, [r12+rax]              ; ptr = line+ve
    mov eax, [wrap_cb1]
    sub eax, [sel_o2]               ; len
    mov r8d, eax
    mov edx, C_CODE
    call platform_draw_text wrt ..plt
    jmp .chnext
.chplain:
    mov eax, [wrap_cb0]
    cmp eax, [wrap_cb1]
    jae .chnext                     ; faixa vazia
    mov ecx, [wrap_cb1]
    sub ecx, eax                    ; len
    mov r8d, ecx                    ; len primeiro (rcx vira str)
    lea rcx, [r12+rax]              ; str = line+cb0
    mov edi, 638
    mov esi, r15d
    mov edx, C_CODE
    call platform_draw_text wrt ..plt
.chnext:
    add r15d, 18
    inc r14d
    inc qword [wrap_chunk]
    jmp .chunk
.chadv:
    mov eax, [rsp]
    cmp eax, r13d
    jae .chnomore
    cmp byte [r12+rax], 13
    jne .cha1
    add r12, 2                      ; CRLF: pula os 2 bytes
    sub r13d, 2
    jmp .cha2
.cha1:
    inc r12                         ; LF: pula 1
    dec r13d
.cha2:
    add r12, rax
    sub r13d, eax
    jmp .cloop
.chnomore:
    xor r13d, r13d
    jmp .cloop
.codedone:
    cmp qword [edit_mode], 1
    jne .status
    ; caret via wrap: faixa visual relativa + coluna na faixa (CODE_WRAP).
    ; Linha lógica longa ocupa várias faixas; o caret desce junto.
    lea rsi, [rbx+REC_CODE_OFF]
    mov ecx, [rbx+REC_CLEN_OFF]
    mov edx, [edit_cursor]
    mov r8d, [code_scroll]
    call wrap_vrow                   ; eax=rel (signed), edx=col
    test eax, eax
    js .status                        ; acima da vista
    cmp eax, CODE_ROWS
    jae .status
    ; x = 638+col*9 (r12d), y = TOP+rel*18 (r13d)
    imul edx, edx, 9
    add edx, 638
    mov r12d, edx
    imul eax, eax, 18
    add eax, CODE_TOP_Y
    mov r13d, eax
    mov edi, r12d
    mov esi, r13d
    sub esi, 15
    mov edx, 2
    mov ecx, 20
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
    jmp .status
.empty:
    DTEXT 375, 430, C_DIM, t_nomatch   ; centro da coluna (241..600): 10ch
    cmp qword [qlen], 0
    jne .empty_query
    DTEXT 334, 454, C_DIM, t_emptynew  ; vista vazia: criar ajuda; limpar, não
    jmp .status
.empty_query:
    DTEXT 330, 454, C_DIM, t_emptyclear ; filtro sem match: limpar resolve

.status:
    ; contador "N/M" dentro da caixa da lista, no canto inferior direito.
    ; (o rodapé fica só com mensagens transitórias)
    lea rdi, [ibuf]
    mov eax, [filt_n]
    call itoa
    mov r13d, eax                   ; len do mostrado
    mov byte [ibuf+r13], '/'
    inc r13d
    mov eax, [sn_count]
    lea rdi, [ibuf+r13]
    call itoa
    add r13d, eax                   ; len total ("N/M")
    mov eax, r13d
    imul eax, eax, 9
    mov edi, 600 - 12
    sub edi, eax                    ; alinhado à direita da coluna da lista
    mov esi, 750                    ; acima da borda inferior (763)
    mov edx, C_DIM
    lea rcx, [ibuf]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
.taildone:
    ; estado atual no canto inferior esquerdo ([EDITANDO]/[MOVER])
    mov rax, [edit_mode]
    test rax, rax
    jz .st_none
    cmp rax, 4
    je .st_pick
    DTEXT 16, 787, C_ACCENT, t_edittag
    jmp .st_done
.st_pick:
    DTEXT 16, 787, C_ACCENT, t_picktag
.st_none:
.st_done:
    ; mensagem de ação à direita (copiado/salvo/fav)
    mov rax, [msg_len]
    test rax, rax
    jz .drawdone
    mov r12d, eax
    imul r12d, r12d, 9
    mov eax, 1280 - 16
    sub eax, r12d
    mov edi, eax
    mov esi, 787
    mov edx, C_ACCENT
    lea rcx, [msg_buf]
    mov r8d, [msg_len]
    call platform_draw_text wrt ..plt
.drawdone:
    cmp qword [help_open], 0
    je .nohelp
    call help_draw
.nohelp:

    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
