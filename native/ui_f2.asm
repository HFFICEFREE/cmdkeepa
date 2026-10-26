; ui_f2.asm — UI interativa F2: busca digitável, setas, dados do db.asm.
; Estado: query, sel, scroll, filtro. Desenho usa lens reais dos registros.
; ASCII na busca; UTF-8 do JSON passa cru (limitação conhecida F2).
default rel
%include "rec.inc"

global ui_draw
global app_on_key

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
extern db_save
extern sn_recs
extern sn_count
extern coll_names
extern coll_lens
extern coll_count
extern coll_ids
extern coll_cats

%define C_BG     0x191817
%define C_PANEL  0x201E1C
%define C_SEL    0x2E2A27
%define C_BOX    0x2A2724
%define C_BORDER 0x332F2B
%define C_TEXT   0xECE7DF
%define C_DIM    0xA8A29E
%define C_ACCENT 0xE0AF68
%define C_CODE   0xD6D0C7

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
    t_title:   db "CmdKeepa"
t_title_len equ $ - t_title
    ; única dica permanente: Ctrl+H abre a tabela (nada de ensinar teclas na UI)
    t_helpkey: db "Ctrl+H ajuda"
t_helpkey_len equ $ - t_helpkey
    t_helptitle: db "Comandos"
t_helptitle_len equ $ - t_helptitle
    t_helpclose: db "Esc / Ctrl+H fecha"
t_helpclose_len equ $ - t_helpclose
    hk_up:      db "Up / Down", 0
    hd_up:      db "navega na lista (e no seletor de colecao)", 0
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
    hk_clear:   db "Ctrl+U", 0
    hd_clear:   db "limpa a busca", 0
    hk_move:    db "Ctrl+L", 0
    hd_move:    db "move o snippet p/ uma colecao", 0
    hk_newc:    db "Ctrl+G", 0
    hd_newc:    db "nova colecao", 0
    hk_renc:    db "Ctrl+R", 0
    hd_renc:    db "renomeia a colecao OU atribui o snippet (picker)", 0
    hk_delc:    db "Ctrl+X", 0
    hd_delc:    db "apaga a colecao (2x confirma)", 0
    hk_del:     db "Del / Ctrl+D", 0
    hd_del:     db "apaga o snippet (2x confirma)", 0
    hk_help:    db "Ctrl+H", 0
    hd_help:    db "esta tabela", 0
    hk_esc:     db "Esc", 0
    hd_esc:     db "cancela / fecha (2x sai do app)", 0
    ; pares (ptr_chave, ptr_desc), NUL-terminadas
    help_rows:
        dq hk_up, hd_up
        dq hk_enter, hd_enter
        dq hk_tab, hd_tab
        dq hk_save, hd_save
        dq hk_new, hd_new
        dq hk_fav, hd_fav
        dq hk_copy, hd_copy
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
    t_nomatch: db "No matches"
t_nomatch_len equ $ - t_nomatch
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
    m_saved:   db "salvo "
m_saved_len equ $ - m_saved
    m_fail:    db "falha ao salvar"
m_fail_len equ $ - m_fail
    m_favon:   db "fav: "
m_favon_len equ $ - m_favon
    m_favoff:  db "unfav: "
m_favoff_len equ $ - m_favoff
    m_cancel:  db "edicao cancelada"
m_cancel_len equ $ - m_cancel
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
    m_moved:   db "movido p/ "
m_moved_len equ $ - m_moved
    m_unfiled2: db "sem colecao"
m_unfiled2_len equ $ - m_unfiled2
    m_nocolls: db "sem colecoes (Ctrl+G cria)"
m_nocolls_len equ $ - m_nocolls
    t_picktag: db "[MOVER]"
t_picktag_len equ $ - t_picktag
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

section .bss
    qbuf:     resb 128
    qlen:     resq 1
    sel:      resq 1
    scroll:   resq 1
    filt_idx: resb MAX_SNIPPETS
    filt_n:   resq 1
    ibuf:     resb 24
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

section .text

; ---------- entrada ----------

; int app_on_key(void) — eax 1 = sair, 0 = continuar
app_on_key:
    push rbp
    mov rbp, rsp
    ; mensagens do canto inferior direito valem SÓ para o evento atual: ao
    ; "resetar" um estado (Esc armado, Del armado, edição), o texto de ajuda
    ; não pode ficar órfão na tela. Handlers que querem avisar re-setam abaixo.
    mov qword [msg_len], 0
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
    cmp eax, 18
    je .mkcoll
    cmp eax, 19
    je .rencoll
    cmp eax, 20
    je .delcoll
    cmp eax, 21
    je .movecoll
    jmp .cont0
.print:
    mov qword [q_focus], 1          ; digitar mantém a busca focada (caret visível)
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
    mov rax, [qlen]
    test rax, rax
    jz .ret
    dec rax
    mov [qlen], rax
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.up:
    mov rax, [sel]
    test rax, rax
    jz .ret
    dec rax
    mov [sel], rax
    jmp .ret
.down:
    mov rax, [sel]
    inc rax
    mov [sel], rax
    jmp .ret
.clearq:
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
    mov rax, [sel]
    movzx eax, byte [filt_idx+rax]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    lea rax, [rbx+REC_CODE_OFF]
    mov [clip_ptr], rax
    mov eax, [rbx+REC_CLEN_OFF]
    mov [clip_len], eax
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
    mov qword [esc_armed], 1
    lea rsi, [m_blur]
    mov edx, m_blur_len
    call set_msg
    jmp .ret
.quitapp:
    mov qword [esc_armed], 0
    mov eax, 1
    pop rbp
    ret
.mouse:
    mov eax, [ev_btn]
    cmp eax, 4
    je .m_wheelup
    cmp eax, 5
    je .m_wheeldown
    cmp eax, 1
    jne .ret
    mov qword [q_focus], 0          ; clique fora da busca tira o foco
    mov eax, [ev_mx]
    mov ecx, [ev_my]
    cmp eax, 240
    jb .m_side
    cmp eax, 601
    jae .m_detail
    ; faixa central: caixa de busca (y<90) ou lista
    cmp ecx, 90
    jb .m_searchfocus
    sub ecx, 90
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
    mov qword [sel], 0
    mov qword [scroll], 0
    jmp .ret
.m_detail:
    cmp qword [filt_n], 0
    je .ret
    cmp ecx, 60
    jb .ret
    cmp ecx, 86
    jb .m_title
    cmp ecx, 110
    jb .m_langtags
    mov edi, 1
    call begin_edit
    test eax, eax
    jz .ret
    call click_to_cursor
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
    ; title_cursor pela coluna do click
    mov eax, [ev_mx]
    sub eax, 621
    jge .m_txok
    xor eax, eax
.m_txok:
    mov ecx, 9
    xor edx, edx
    div ecx                         ; eax = col
    mov r11d, eax                   ; salva (cur_rec retorna em eax)
    call cur_rec
    test eax, eax
    jz .ret
    mov eax, r11d
    mov ecx, [rbx+REC_TLEN_OFF]
    cmp eax, ecx
    cmova eax, ecx
    mov [title_cursor], rax
    jmp .ret
.mknew:
    mov eax, 201                    ; sys_time (clobber rcx,r11 — livres)
    xor edi, edi
    syscall
    mov r10, rax                    ; epoch
    mov rax, [sn_count]
    cmp rax, MAX_SNIPPETS
    jae .m_maxmsg
    mov eax, r10d
    lea rdi, [ibuf]
    call itoa                        ; clobber rbx! rbx recalculado abaixo
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
    mov byte [rbx+REC_ID_OFF], 'n'
    mov byte [rbx+REC_ID_OFF+1], '-'
    lea rsi, [ibuf]
    lea rdi, [rbx+REC_ID_OFF+2]
    mov ecx, r11d
    rep movsb
    mov byte [rdi], 0
    mov [rbx+REC_CREATED_OFF], r10
    mov [rbx+REC_UPDATED_OFF], r10
    inc qword [sn_count]
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
    lea rsi, [m_fail]
    mov edx, m_fail_len
    call set_msg
    jmp .ret
.mkcoll:
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .m_cmax
    mov eax, 201                    ; sys_time (clobber rcx,r11 — livres)
    xor edi, edi
    syscall
    mov r10, rax                    ; epoch
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .m_cmax
    mov r11d, eax                   ; k (sobrevive a itoa: usa r8/r9/rbx)
    imul eax, eax, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    lea rsi, [t_cnew]
    mov ecx, t_cnew_len
    rep movsb
    mov byte [rdi], 0
    mov dword [coll_lens+r11*4], t_cnew_len
    imul eax, r11d, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    mov byte [rdi], 'c'
    mov byte [rdi+1], '-'
    mov eax, r10d
    lea rdi, [ibuf]
    call itoa
    mov ecx, eax
    lea rsi, [ibuf]
    imul eax, r11d, COLL_ID_LEN
    lea rdi, [coll_ids+rax+2]
    rep movsb
    mov byte [rdi], 0
    mov [coll_cats+r11*8], r10
    inc qword [coll_count]
    mov qword [qlen], 0
    mov qword [sel], 0
    mov qword [scroll], 0
    mov rax, r11
    add rax, 3
    mov [libsel], rax
    call coll_snapshot              ; cursor=fim; filtro nem existia p/ ela
    mov qword [edit_mode], 3
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
    ; Ctrl+R é contextual: com coleção selecionada renomeia; com snippet
    ; selecionado abre o seletor de coleção (mesmo caminho do Ctrl+L), que é
    ; o que o usuário espera ("relacionar este snippet com uma coleção").
    cmp qword [libsel], 3
    jb .movecoll
    call coll_snapshot
    test eax, eax
    jz .renone
    mov qword [edit_mode], 3
    jmp .ret
.renone:
    lea rsi, [m_nocoll]
    mov edx, m_nocoll_len
    call set_msg
    jmp .ret
.delcoll:
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
    mov qword [msg_len], 0          ; hint fica só no topbar ([MOVER])
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
    jmp .cont0
.e_ins:
    mov al, [ev_char]
    cmp qword [edit_mode], 2
    je .e_tins
    call edit_insert
    jmp .ret
.e_tins:
    call title_insert
    jmp .ret
.e_nl:
    cmp qword [edit_mode], 2
    je .e_to_code
    cmp qword [edit_mode], 5
    je .e_lang2tags
    cmp qword [edit_mode], 6
    je .e_tags2title
    mov al, 10
    call edit_insert
    jmp .ret
.e_lang2tags:
    mov qword [edit_mode], 6
    jmp .ret
.e_tags2title:
    mov qword [edit_mode], 1
    call ensure_vis
    jmp .ret
.e_to_code:
    ; Enter no título -> vai p/ edição do código (cursor no fim)
    call cur_rec
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
    cmp qword [edit_mode], 2
    je .e_tbs
    call edit_backspace
    jmp .ret
.e_tbs:
    call title_backspace
    jmp .ret
.e_up:
    call edit_up
    jmp .ret
.e_down:
    call edit_down
    jmp .ret
.e_left:
    cmp qword [edit_mode], 2
    je .e_tleft
    call edit_left
    jmp .ret
.e_tleft:
    call title_left
    jmp .ret
.e_right:
    cmp qword [edit_mode], 2
    je .e_tright
    call edit_right
    jmp .ret
.e_tright:
    call title_right
    jmp .ret
.e_delfwd:
    cmp qword [edit_mode], 2
    je .e_tdelfwd
    call edit_delfwd
    jmp .ret
.e_tdelfwd:
    call title_delfwd
    jmp .ret
.e_tab:
    ; ciclo de campos: titulo(2) -> codigo(1) -> lang(5) -> tags(6) -> titulo
    mov rax, [edit_mode]
    cmp rax, 2
    je .e_tab2code
    cmp rax, 1
    je .e_tab_lang
    cmp rax, 5
    je .e_tab_tags
    ; 6 -> título
    mov qword [edit_mode], 2
    jmp .ret
.e_tab_lang:
    mov qword [edit_mode], 5
    jmp .ret
.e_tab_tags:
    mov qword [edit_mode], 6
    jmp .ret
.e_tab2code:
    mov qword [edit_mode], 1
    call ensure_vis
    jmp .ret
.e_mouse:
    mov eax, [ev_btn]
    cmp eax, 1
    jne .ret
    mov eax, [ev_mx]
    mov ecx, [ev_my]
    cmp eax, 601
    jb .ret
    cmp ecx, 60
    jb .ret
    cmp ecx, 86
    jb .e_mtitle
    cmp ecx, 110
    jb .e_mlangtags
    mov qword [edit_mode], 1
    call click_to_cursor
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
    mov qword [edit_mode], 2
    jmp .ret
; .edit3 — modo 3: renomeando coleção (libsel-3). Só teclas de texto.
.edit3:
    mov eax, [ev_kind]
    cmp eax, 1
    je .e3_ins
    cmp eax, 2
    je .e3_bs
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
    jmp .cont0
.e3_ins:
    mov al, [ev_char]
    call coll_insert
    jmp .ret
.e3_bs:
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
    jmp .ret
.e4_cancel:
    mov qword [edit_mode], 0
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
; .edit56 — campos 1-linha: language (modo 5) e tags (modo 6).
; Insere/apaga/navega via helpers genéricos; Enter/Tab trocam de campo;
; Esc restaura os 4 campos do snapshot; Ctrl+S commita.
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
    cmp eax, 16
    je .e5_delfwd
    cmp eax, 17
    je .e_tab
    jmp .cont0
.e5_ins:
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
    call field_setup
    test eax, eax
    jz .ret
    call fld_delfwd
    jmp .ret
.e_cancel:
    ; restaura backup (código + título + language + tags)
    mov rax, [sel]
    movzx eax, byte [filt_idx+rax]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
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
    mov qword [edit_mode], 0
    lea rsi, [m_cancel]
    mov edx, m_cancel_len
    call set_msg
    jmp .ret
.e_commit:
    call edit_commit_save
    jmp .ret
.ret:
    xor eax, eax
    pop rbp
    ret

; click_to_cursor — posiciona edit_cursor pelo click (ev_mx/ev_my).
; col=(mx-621)/9, linha=(my-130)/18+code_scroll. Clampa no fim do código.
; Preserva rbx/r12/r13 do chamador.
click_to_cursor:
    push rbx
    push r12
    push r13
    sub rsp, 8
    call cur_rec
    test eax, eax
    jz .ret
    mov eax, [ev_my]
    sub eax, 130
    jge .yok
    xor eax, eax
.yok:
    mov ecx, 18
    xor edx, edx
    div ecx
    mov ecx, [code_scroll]
    add eax, ecx                    ; eax = linha abs alvo
    mov r12d, eax
    mov eax, [ev_mx]
    sub eax, 621
    jge .xok
    xor eax, eax
.xok:
    mov ecx, 9
    xor edx, edx
    div ecx
    mov r13d, eax                   ; col
    lea rsi, [rbx+REC_CODE_OFF]
    mov ecx, [rbx+REC_CLEN_OFF]
    xor eax, eax                    ; pos
    xor edx, edx                    ; linha atual
.cl:
    cmp edx, r12d
    jae .got
    cmp eax, ecx
    jae .got
    cmp byte [rsi+rax], 10
    jne .nadv
    inc edx
.nadv:
    inc eax
    jmp .cl
.got:
    push rax
    call linelen                    ; eax=len (rbx/r12/r13 intactos)
    mov ecx, r13d
    cmp ecx, eax
    cmova ecx, eax
    pop rax
    add eax, ecx
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
.ret:
    add rsp, 8
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
    sub rsp, 8
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
    mov eax, 201
    xor edi, edi
    syscall                         ; epoch (clobber rcx,r11 — mortos)
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
    lea rsi, [m_fail]
    mov edx, m_fail_len
    call set_msg
.asdone:
    add rsp, 8
    pop rbx
    ret

; ---------- campos 1-linha genéricos (lang/tags) ----------
; Convenção: rdi=base, rsi=&len(dword), rdx=&cursor(qword), ecx=capacidade
; (inclui NUL; máx = cap-1). Clobbers scratch; preserva rbx/r12-r15.
; Todos os loads de len são dword (mov e..): ver contract.md §2.

; field_setup — rbx=rec via cur_rec; aponta o campo do edit_mode (5=lang,
; 6=tags). eax 1 ok / 0 inválido. Deixa rdi/rsi/rdx/ecx prontos.
field_setup:
    push rbx
    call cur_rec
    test eax, eax
    jz .bad
    cmp qword [edit_mode], 5
    je .lang
    cmp qword [edit_mode], 6
    je .tags
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
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    cmp qword [r14], 0
    je .ret
    dec qword [r14]
    mov rcx, [r14]
    mov edx, [r13]                  ; dword!
.mv: cmp rcx, rdx
    jae .out
    mov r10b, [r12+rcx+1]
    mov [r12+rcx], r10b
    inc rcx
    jmp .mv
.out:
    dec dword [r13]
    mov eax, [r13]
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
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov rcx, [r14]
    mov edx, [r13]                  ; dword!
    cmp rcx, rdx
    jae .ret
.mv: cmp rcx, rdx
    jae .out
    mov r10b, [r12+rcx+1]
    mov [r12+rcx], r10b
    inc rcx
    jmp .mv
.out:
    dec dword [r13]
    mov eax, [r13]
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
    dec qword [rdx]
.ret:
    ret

fld_right:
    mov rax, [rdx]
    cmp eax, [rsi]                  ; dword!
    jae .ret
    inc qword [rdx]
.ret:
    ret

; lt_pick — decide language(5)/tags(6) e a coluna a partir de ev_mx.
; eax = modo (0 = sem seleção), edx = coluna clampada. rbx=rec (via cur_rec).
; Geometria: lang em 621; " - " 27px; tags em 621+llen*9+27; coluna = 9px.
; Limiar lang/tags = 621+llen*9+13 (meio do separador).
lt_pick:
    push rbx
    call cur_rec
    test eax, eax
    jz .bad
    mov r8d, [rbx+REC_LLEN_OFF]
    mov eax, r8d
    imul eax, eax, 9
    add eax, 634
    mov edx, [ev_mx]
    cmp edx, eax
    jb .lang
    mov eax, r8d
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
    div ecx
    mov ecx, [rbx+REC_GLEN_OFF]
    cmp eax, ecx
    cmova eax, ecx
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
    div ecx
    cmp eax, r8d
    cmova eax, r8d
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
    mov r12d, edi
    call cur_rec
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
    FILL 300, 140, 680, 520, C_BG
    FILL 300, 140, 680, 1, C_ACCENT
    FILL 300, 659, 680, 1, C_ACCENT
    FILL 300, 140, 1, 520, C_ACCENT
    FILL 979, 140, 1, 520, C_ACCENT
    DTEXT 324, 180, C_TEXT, t_helptitle
    DTEXT 700, 180, C_DIM, t_helpclose
    FILL 324, 196, 630, 1, C_BORDER
    lea rbx, [help_rows]
    mov r14d, 222
.hloop:
    lea rax, [help_rows_end]
    cmp rbx, rax
    jae .hdone
    mov rdi, [rbx]
    call hstrlen
    mov r13d, eax
    mov edi, 324
    mov esi, r14d
    mov edx, C_ACCENT
    mov rcx, [rbx]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    mov rdi, [rbx+8]
    call hstrlen
    mov r13d, eax
    mov edi, 540
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
    sub rsp, 8
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
    add rsp, 8
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

; begin_edit(edi=1 código, 2 título) — snapshot código+título, entra no edit.
; eax 1 ok / 0 vazio. Preserva rbx do chamador.
begin_edit:
    push rbx
    sub rsp, 8
    mov r10d, edi                   ; r10d=modo (mov r32 zera o alto)
    call cur_rec
    test eax, eax
    jz .ret
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
    ; tags (modo 6) — string "a, b" (o writer explode em array)
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
    mov qword [code_scroll], 0
    mov [edit_mode], r10
    call ensure_vis
    mov eax, 1
.ret:
    add rsp, 8
    pop rbx
    ret

; col_of_cursor — rbx=rec; eax = coluna do cursor
col_of_cursor:
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
    sub rax, rcx
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

; linelen(eax=start) — rbx=rec; eax = tamanho da linha (sem \n)
linelen:
    mov r8d, eax
    mov ecx, [rbx+REC_CLEN_OFF]
    lea rdi, [rbx+REC_CODE_OFF]
    mov edx, r8d
.ll: cmp edx, ecx
    jae .done
    cmp byte [rdi+rdx], 10
    je .done
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

; ensure_vis — ajusta code_scroll p/ cursor visível
ensure_vis:
    ; auto-suficiente: resolve o rec via cur_rec. Antes assumia rbx=rec, e os
    ; atalhos de troca de campo (Enter nas tags / Tab titulo->codigo) chamavam
    ; com rbx=lixo -> line_index lia [2+256] e segfaultava (si_addr=0x102).
    call cur_rec
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
    ret

; edit_insert(al=char)
edit_insert:
    push rbx
    sub rsp, 8
    mov dl, al                      ; ch (cur_rec preserva rdx? usa só rax — ok)
    call cur_rec
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
    add rsp, 8
    pop rbx
    ret

; edit_backspace — apaga char antes do cursor
edit_backspace:
    push rbx
    sub rsp, 8
    call cur_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    test rax, rax
    jz .ret
    dec rax
    mov [edit_cursor], rax
    lea rdi, [rbx+REC_CODE_OFF]
    mov rcx, rax
    mov edx, [rbx+REC_CLEN_OFF]     ; dword! (r64 leria fav/id junto)
.mv: cmp rcx, rdx
    jae .mvout
    mov r10b, [rdi+rcx+1]
    mov [rdi+rcx], r10b
    inc rcx
    jmp .mv
.mvout:
    dec dword [rbx+REC_CLEN_OFF]
    mov eax, [rbx+REC_CLEN_OFF]
    mov byte [rdi+rax], 0
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
.ret:
    add rsp, 8
    pop rbx
    ret

; edit_left / edit_right
edit_left:
    call cur_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    test rax, rax
    jz .ret
    dec rax
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
.ret:
    ret

edit_right:
    call cur_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    cmp eax, [rbx+REC_CLEN_OFF]     ; eax==cursor (pequeno); cmp r64 leria 8B
    jae .ret
    inc rax
    mov [edit_cursor], rax
    call col_of_cursor
    mov [edit_goal], rax
.ret:
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
    ret
.bad:
    xor eax, eax
    ret

; title_insert(al=char) — insere no título (cap 95). Edição ao vivo no rec
; (cancel restaura via title_backup).
title_insert:
    push rbx
    sub rsp, 8
    mov dl, al
    call cur_rec
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
    add rsp, 8
    pop rbx
    ret

; title_backspace — apaga antes do cursor do título
title_backspace:
    push rbx
    sub rsp, 8
    call cur_rec
    test eax, eax
    jz .ret
    mov rax, [title_cursor]
    test rax, rax
    jz .ret
    dec rax
    mov [title_cursor], rax
    lea rdi, [rbx+REC_TITLE_OFF]
    mov rcx, rax
    mov edx, [rbx+REC_TLEN_OFF]
.mv: cmp rcx, rdx
    jae .mvout
    mov r10b, [rdi+rcx+1]
    mov [rdi+rcx], r10b
    inc rcx
    jmp .mv
.mvout:
    dec dword [rbx+REC_TLEN_OFF]
    mov eax, [rbx+REC_TLEN_OFF]
    mov byte [rdi+rax], 0
.ret:
    add rsp, 8
    pop rbx
    ret

; title_delfwd — apaga sob o cursor do título
title_delfwd:
    push rbx
    sub rsp, 8
    call cur_rec
    test eax, eax
    jz .ret
    mov rax, [title_cursor]
    mov edx, [rbx+REC_TLEN_OFF]
    cmp rax, rdx
    jae .ret
    lea rdi, [rbx+REC_TITLE_OFF]
    mov rcx, rax
.mv: cmp rcx, rdx
    jae .mvout
    mov r10b, [rdi+rcx+1]
    mov [rdi+rcx], r10b
    inc rcx
    jmp .mv
.mvout:
    dec dword [rbx+REC_TLEN_OFF]
    mov eax, [rbx+REC_TLEN_OFF]
    mov byte [rdi+rax], 0
.ret:
    add rsp, 8
    pop rbx
    ret

; title_left / title_right
title_left:
    call cur_rec
    test eax, eax
    jz .ret
    mov rax, [title_cursor]
    test rax, rax
    jz .ret
    dec rax
    mov [title_cursor], rax
.ret:
    ret

title_right:
    call cur_rec
    test eax, eax
    jz .ret
    mov rax, [title_cursor]
    cmp eax, [rbx+REC_TLEN_OFF]
    jae .ret
    inc rax
    mov [title_cursor], rax
.ret:
    ret

; coll_insert(al=char) — insere no nome da coll (cap 63). Ao vivo em coll_names.
; O char vai p/ pilha: coll_cur suja rax/rdx (scratch não sobrevive a call).
coll_insert:
    sub rsp, 8
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
    call coll_cur
    cmp eax, 0
    jl .ret
    mov r11d, eax
    mov rax, [coll_cursor]
    test rax, rax
    jz .ret
    dec rax
    mov [coll_cursor], rax
    mov ecx, [coll_lens+r11*4]
.mv: cmp rax, rcx
    jae .mvout
    mov r10b, [rdi+rax+1]
    mov [rdi+rax], r10b
    inc rax
    jmp .mv
.mvout:
    dec dword [coll_lens+r11*4]
    mov ecx, [coll_lens+r11*4]
    mov byte [rdi+rcx], 0
.ret:
    ret

; coll_delfwd — apaga sob o cursor do nome
coll_delfwd:
    call coll_cur
    cmp eax, 0
    jl .ret
    mov r11d, eax
    mov rax, [coll_cursor]
    mov ecx, [coll_lens+r11*4]
    cmp rax, rcx
    jae .ret
.mv: cmp rax, rcx
    jae .mvout
    mov r10b, [rdi+rax+1]
    mov [rdi+rax], r10b
    inc rax
    jmp .mv
.mvout:
    dec dword [coll_lens+r11*4]
    mov ecx, [coll_lens+r11*4]
    mov byte [rdi+rcx], 0
.ret:
    ret

; coll_left / coll_right
coll_left:
    call coll_cur
    cmp eax, 0
    jl .ret
    mov rax, [coll_cursor]
    test rax, rax
    jz .ret
    dec rax
    mov [coll_cursor], rax
.ret:
    ret

coll_right:
    call coll_cur
    cmp eax, 0
    jl .ret
    mov r11d, eax
    mov rax, [coll_cursor]
    cmp eax, [coll_lens+r11*4]
    jae .ret
    inc rax
    mov [coll_cursor], rax
.ret:
    ret

; coll_commit_save — sai do modo 3 + db_save + msg
coll_commit_save:
    call coll_cur
    cmp eax, 0
    jl .ret
    mov qword [edit_mode], 0
    call do_save
.ret:
    ret

; coll_cancel — restaura nome do backup + sai do modo 3
coll_cancel:
    call coll_cur
    cmp eax, 0
    jl .out
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
    lea rsi, [m_cancel]
    mov edx, m_cancel_len
    call set_msg
    ret

; edit_delfwd — apaga char sob o cursor do código (tecla Delete)
edit_delfwd:
    push rbx
    sub rsp, 8
    call cur_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    mov edx, [rbx+REC_CLEN_OFF]     ; dword! (r64 leria fav/id junto)
    cmp rax, rdx
    jae .ret
    lea rdi, [rbx+REC_CODE_OFF]
    mov rcx, rax
.mv: cmp rcx, rdx
    jae .mvout
    mov r10b, [rdi+rcx+1]
    mov [rdi+rcx], r10b
    inc rcx
    jmp .mv
.mvout:
    dec dword [rbx+REC_CLEN_OFF]
    mov eax, [rbx+REC_CLEN_OFF]
    mov byte [rdi+rax], 0
    call col_of_cursor
    mov [edit_goal], rax
    call ensure_vis
.ret:
    add rsp, 8
    pop rbx
    ret

; edit_up / edit_down (preservam r12/r13 p/ ps)
edit_up:
    push r12
    push r13
    call cur_rec
    test eax, eax
    jz .ret
    mov rax, [edit_cursor]
    call line_start
    test eax, eax
    jz .top
    call prev_start
    mov r12d, eax
    call linelen
    mov ecx, [edit_goal]
    cmp ecx, eax
    cmova ecx, eax
    mov eax, r12d
    add eax, ecx
    mov [edit_cursor], rax
    call ensure_vis
    jmp .ret
.top:
    mov qword [edit_cursor], 0
    mov qword [edit_goal], 0
.ret:
    pop r13
    pop r12
    ret

edit_down:
    push r12
    push r13
    call cur_rec
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
    call linelen
    mov ecx, [edit_goal]
    cmp ecx, eax
    cmova ecx, eax
    mov eax, r12d
    add eax, ecx
    mov [edit_cursor], rax
    call ensure_vis
.ret:
    pop r13
    pop r12
    ret

; edit_commit_save — push versions + updatedAt + sai do edit + db_save + msg
edit_commit_save:
    push rbx
    sub rsp, 8
    call cur_rec
    test eax, eax
    jz .ret
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
    mov eax, 201                    ; sys_time (clobber rcx,r11 — mortos)
    xor edi, edi
    syscall
    mov r10, rax                    ; epoch
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
    ; entry0 = backup (cap 2047) + at
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
    mov [rbx+REC_VERS_OFF+2048], r10
    mov eax, [rbx+REC_VNUM_OFF]
    inc eax
    mov edx, MAX_VERSIONS
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_VNUM_OFF], eax
    mov [rbx+REC_UPDATED_OFF], r10
    mov qword [edit_mode], 0
    call do_save
.ret:
    add rsp, 8
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

; itoa(eax=u32, rdi=buf[>=12]) — decimal sem NUL; retorna eax=len
; Leaf (sem calls): usa r8/r9/caller-saved livremente.
itoa:
    push rbp
    mov rbp, rsp
    mov r8, rdi                     ; r8 = buf
    lea rcx, [rdi+16]
    mov rsi, rcx                    ; escreve de trás p/ frente
    test eax, eax
    jnz .loop
    dec rsi
    mov byte [rsi], '0'
    jmp .copy
.loop:
    mov ebx, 10
    xor edx, edx
    div ebx                         ; eax=quociente, edx=dígito
    add dl, '0'
    dec rsi
    mov [rsi], dl
    test eax, eax
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
    mov rcx, [scroll]
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
    FILL 0, 772, 1280, 28, C_PANEL
    FILL 0, 36, 240, 736, C_PANEL
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
    mov edi, 0
    mov esi, eax
    mov edx, 240
    mov ecx, 28
    mov r8d, C_SEL
    call platform_fill_rect wrt ..plt
    FILL 253, 48, 335, 30, C_BOX
    FILL 240, 36, 1, 736, C_BORDER
    FILL 600, 36, 1, 736, C_BORDER
    FILL 621, 106, 639, 1, C_BORDER

    DTEXT 16, 23, C_TEXT, t_title
    ; dica única no topo (os comandos ficam na tabela do Ctrl+H)
    DTEXT 1129, 23, C_DIM, t_helpkey
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
    imul eax, eax, 9
    add eax, 16
    mov edi, eax
    mov esi, r12d
    sub esi, 16
    mov edx, 8
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
    mov eax, r13d                   ; caret após o texto (ou no início)
    imul eax, eax, 9
    add eax, 263
    mov edi, eax
    mov esi, 52
    mov edx, 8
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
    add eax, 90
    mov r15d, eax                   ; top
    cmp r13, [sel]
    jne .noselrow
    mov edi, 241
    mov esi, r15d
    mov edx, 359
    mov ecx, 58
    mov r8d, C_SEL
    call platform_fill_rect wrt ..plt
.noselrow:
    movzx eax, byte [filt_idx+r13]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    ; título (+ estrela âmbar se fav)
    mov r13d, [rbx+REC_TLEN_OFF]
    mov edi, 261
    cmp byte [rbx+REC_FAV_OFF], 0
    je .tcap37
    mov esi, r15d
    add esi, 24
    mov edx, C_ACCENT
    lea rcx, [t_star]
    mov r8d, t_star_len
    call platform_draw_text wrt ..plt
    mov r13d, [rbx+REC_TLEN_OFF]
    cmp r13d, 35
    jbe .tt2
    mov r13d, 35
.tt2:
    mov edi, 279
    jmp .tdraw
.tcap37:
    cmp r13d, 37
    jbe .tdraw
    mov r13d, 37
.tdraw:
    mov esi, r15d
    add esi, 24
    mov edx, C_TEXT
    lea rcx, [rbx+REC_TITLE_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    ; lang (cap 18, ACCENT)
    mov r13d, [rbx+REC_LLEN_OFF]
    cmp r13d, 18
    jbe .llok
    mov r13d, 18
.llok:
    mov edi, 261
    mov esi, r15d
    add esi, 44
    mov edx, C_ACCENT
    lea rcx, [rbx+REC_LANG_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    ; " - " + tags (cap 20)
    mov eax, r13d
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
    ; --- detail do selecionado ---
    mov rax, [sel]
    movzx eax, byte [filt_idx+rax]
    imul eax, eax, REC_SIZE
    lea rbx, [sn_recs+rax]
    mov r13d, [rbx+REC_TLEN_OFF]
    cmp r13d, 70
    jbe .dtlok
    mov r13d, 70
.dtlok:
    mov edi, 621
    mov esi, 72
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
    imul eax, eax, 9
    add eax, 621
    mov edi, eax
    mov esi, 60
    mov edx, 8
    mov ecx, 20
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
.tnocur:
    mov r13d, [rbx+REC_LLEN_OFF]
    cmp r13d, 24
    jbe .dllok
    mov r13d, 24
.dllok:
    mov edi, 621
    mov esi, 94
    mov edx, C_ACCENT
    lea rcx, [rbx+REC_LANG_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    mov eax, r13d
    imul eax, eax, 9
    add eax, 621
    mov r12d, eax
    mov edi, r12d
    mov esi, 94
    mov edx, C_DIM
    lea rcx, [t_sep]
    mov r8d, t_sep_len
    call platform_draw_text wrt ..plt
    add r12d, 27
    mov r13d, [rbx+REC_GLEN_OFF]
    cmp r13d, 40
    jbe .dglok
    mov r13d, 40
.dglok:
    mov edi, r12d
    mov esi, 94
    mov edx, C_DIM
    lea rcx, [rbx+REC_TAGS_OFF]
    mov r8d, r13d
    call platform_draw_text wrt ..plt
    cmp byte [rbx+REC_FAV_OFF], 0
    je .curblock
    mov eax, r13d
    imul eax, eax, 9
    add eax, r12d
    mov edi, eax
    mov esi, 94
    mov edx, C_ACCENT
    lea rcx, [t_favtag]
    mov r8d, t_favtag_len
    call platform_draw_text wrt ..plt
.curblock:
    ; cursor de campo 1-linha (lang/tags): barra fina, não cobre o texto
    cmp qword [edit_mode], 5
    je .cur_lang
    cmp qword [edit_mode], 6
    je .cur_tags
    jmp .codestart
.cur_lang:
    mov eax, [rbx+REC_LLEN_OFF]
    mov ecx, [lang_cursor]
    cmp ecx, eax
    jbe .cl_ok
    mov ecx, eax
.cl_ok:
    imul ecx, ecx, 9
    add ecx, 621
    mov r12d, ecx
    jmp .cur_draw
.cur_tags:
    mov eax, [rbx+REC_LLEN_OFF]
    imul eax, eax, 9
    add eax, 648                    ; 621 + 27 (após " - ")
    mov ecx, [rbx+REC_GLEN_OFF]
    mov edx, [tags_cursor]
    cmp edx, ecx
    jbe .ct_ok
    mov edx, ecx
.ct_ok:
    imul edx, edx, 9
    add eax, edx
    mov r12d, eax
.cur_draw:
    mov edi, r12d
    mov esi, 82
    mov edx, 2
    mov ecx, 20
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
.codestart:
    ; linhas de código (pula code_scroll; máx CODE_ROWS)
    lea r12, [rbx+REC_CODE_OFF]
    mov r13d, [rbx+REC_CLEN_OFF]
    mov r15d, 130
    xor r14d, r14d
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
    cmp byte [r12+rax], 10
    je .eol
    cmp byte [r12+rax], 13
    je .eol
    inc eax
    jmp .scan
.eol:
    mov [rsp], eax                  ; full len (sobrevive à call)
    cmp eax, 70
    jbe .dd
    mov eax, 70
.dd:
    test eax, eax
    jz .adv
    mov edi, 621
    mov esi, r15d
    mov edx, C_CODE
    mov rcx, r12
    mov r8d, eax
    call platform_draw_text wrt ..plt
.adv:
    mov eax, [rsp]
    cmp eax, r13d
    jae .nomore
    add r12, rax
    inc r12                         ; pula \n (ou \r)
    sub r13d, eax
    dec r13d
    jmp .cnext
.nomore:
    xor r13d, r13d
.cnext:
    add r15d, 18
    inc r14d
    jmp .cloop
.codedone:
    cmp qword [edit_mode], 1
    jne .status
    ; cursor: linha = nº de \n em code[0..cursor)
    lea rsi, [rbx+REC_CODE_OFF]
    mov rcx, [edit_cursor]
    xor eax, eax
    xor edx, edx
.ciline:
    cmp edx, ecx
    jae .cilend
    cmp byte [rsi+rdx], 10
    jne .cili
    inc eax
.cili:
    inc edx
    jmp .ciline
.cilend:
    ; rel = line - scroll (guard: visível?)
    mov ecx, [code_scroll]
    sub eax, ecx
    jb .status
    cmp eax, CODE_ROWS
    jae .status
    ; col: recua do cursor até \n
    mov rcx, [edit_cursor]
.ccback:
    test rcx, rcx
    jz .ccdone
    cmp byte [rsi+rcx-1], 10
    je .ccdone
    dec rcx
    jmp .ccback
.ccdone:
    mov edx, [edit_cursor]
    sub edx, ecx
    cmp edx, 70
    jbe .cok70
    mov edx, 70
.cok70:
    ; x = 621+col*9 (r12d), y = 130+rel*18 (r13d)
    imul edx, edx, 9
    add edx, 621
    mov r12d, edx
    imul eax, eax, 18
    add eax, 130
    mov r13d, eax
    mov edi, r12d
    mov esi, r13d
    sub esi, 12
    mov edx, 9
    mov ecx, 15
    mov r8d, C_ACCENT
    call platform_fill_rect wrt ..plt
    ; char sob o cursor (ou nada se EOL)
    mov rcx, [edit_cursor]
    cmp ecx, [rbx+REC_CLEN_OFF]     ; dword (r64 leria fav/id junto)
    jae .status
    lea rdx, [rbx+REC_CODE_OFF]
    cmp byte [rdx+rcx], 10
    je .status
    lea rcx, [rdx+rcx]
    mov edi, r12d
    mov esi, r13d
    mov edx, C_BG
    mov r8d, 1
    call platform_draw_text wrt ..plt
    jmp .status
.empty:
    DTEXT 375, 430, C_DIM, t_nomatch   ; centro do painel da lista

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
    mov esi, 760                    ; acima da borda inferior (772)
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
    DTEXT 16, 791, C_ACCENT, t_edittag
    jmp .st_done
.st_pick:
    DTEXT 16, 791, C_ACCENT, t_picktag
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
    mov esi, 791
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
