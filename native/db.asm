; db.asm — carrega o export JSON do CmdKeepa web e parseia snippets.
; Uso: db_load(path) -> rax = nº snippets (0пат? usa seed builtin se falhar).
; Registros em sn_recs (layout em rec.inc), contagem em sn_count.
; Parser propositalmente mínimo: extrai title/language/code/tags[] de
; {"snippets":[{...}]}; ignora o resto (skip_value com nesting + strings).
; Convenção interna: r12 = cursor, r15 = fim. rbx/r13-r15 preservados
; pelos helpers; r11 TAMBÉM preservado (índice de loops chamadores).
; Scratch: rax,rcx,rdx,rsi,rdi,r8-r10.
default rel
%include "rec.inc"

global db_load
global db_count
global db_default_path
global db_save
global db_error
global db_readonly
global db_snapshot
global db_restore
global strlen_cap
global j_memeq
global now_ms
global sn_recs
global sn_count
global coll_names
global coll_lens
global coll_count
global coll_ids
global coll_cats

extern getenv

%define FILE_MAX 1048576
%define PATH_MAX 512

section .data
    home_var:    db "HOME", 0
    home_suffix: db "/.cmdkeepa/db.json", 0
    rel_path:    db "db.json", 0
    k_snip:      db "snippets", 0
    k_coll:      db "collections", 0
    k_title:     db 'title"', 0
    k_code:      db 'code"', 0
    k_tags:      db 'tags"', 0
    k_lang:      db 'language"', 0
    k_fav:       db 'favorite"', 0
    k_name:      db 'name"', 0
    k_id:        db 'id"', 0
    k_desc:      db 'description"', 0
    k_collid:    db 'collectionId"', 0
    k_created:   db 'createdAt"', 0
    k_updated:   db 'updatedAt"', 0
    k_views:     db 'views"', 0
    k_versions:  db 'versions"', 0
    k_at:        db 'at"', 0
    k_note:      db 'note"', 0
    hexdig:      db "0123456789abcdef"
    tmp_suffix:  db ".tmp", 0
    bak_suffix:  db ".bak", 0
    ; peças do writer JSON (subset round-trip p/ web)
    j_open:  db '{"app":"cmdkeepa","version":1,"exportedAt":'
j_open_len equ $ - j_open
    j_mid1:  db ',"snippets":['
j_mid1_len equ $ - j_mid1
    j_sopen: db '{"id":"'
j_sopen_len equ $ - j_sopen
    j_sopen2: db '","title":"'
j_sopen2_len equ $ - j_sopen2
    j_l1:    db '","code":"'
j_l1_len equ $ - j_l1
    j_l2:    db '","language":"'
j_l2_len equ $ - j_l2
    j_l3a:   db '","description":"'
j_l3a_len equ $ - j_l3a
    j_l3b:   db '","tags":['
j_l3b_len equ $ - j_l3b
    j_l4a:   db '],"collectionId":'
j_l4a_len equ $ - j_l4a
    j_null:  db 'null'
j_null_len equ $ - j_null
    j_l4b:   db ',"favorite":'
j_l4b_len equ $ - j_l4b
    j_l5a:   db ',"createdAt":'
j_l5a_len equ $ - j_l5a
    j_l5b:   db ',"updatedAt":'
j_l5b_len equ $ - j_l5b
    j_l5c:   db ',"views":'
j_l5c_len equ $ - j_l5c
    j_l5d:   db ',"versions":['
j_l5d_len equ $ - j_l5d
    j_vopen: db '{"code":"'
j_vopen_len equ $ - j_vopen
    j_vmid:  db '","at":'
j_vmid_len equ $ - j_vmid
    j_vnote: db ',"note":"'
j_vnote_len equ $ - j_vnote
    j_vclose: db '"}'
j_vclose_len equ $ - j_vclose
    j_l5e:   db ']}'
j_l5e_len equ $ - j_l5e
    j_true:  db 'true'
j_true_len equ $ - j_true
    j_false: db 'false'
j_false_len equ $ - j_false
    j_l5:    db ',"createdAt":0,"updatedAt":0,"views":0,"versions":[]}'
j_l5_len equ $ - j_l5
    j_mid2:  db '],"collections":['
j_mid2_len equ $ - j_mid2
    j_copen: db '{"id":"'
j_copen_len equ $ - j_copen
    j_cmid:  db '","name":"'
j_cmid_len equ $ - j_cmid
    j_ccat:  db '","createdAt":'
j_ccat_len equ $ - j_ccat
    j_cclose: db '}'
j_cclose_len equ $ - j_cclose
    j_end:   db ']}'
j_end_len equ $ - j_end
    d_untitled:  db "Untitled"
    d_plain:     db "plaintext"

    ; --- seed builtin (usado quando o arquivo falta ou parse dá 0) ---
    b1t: db "postgres docker"
b1t_len equ $ - b1t
    b1l: db "bash"
b1l_len equ $ - b1l
    b1g: db "docker,postgres"
b1g_len equ $ - b1g
    b1c: db "# postgres local (builtin)", 10
         db "docker run -d --name pg \", 10
         db "  -e POSTGRES_PASSWORD=secret \", 10
         db "  -p 5432:5432 postgres:16", 10
         db "psql -h localhost -U postgres"
b1c_len equ $ - b1c
    b2t: db "k8s port-forward"
b2t_len equ $ - b2t
    b2l: db "bash"
b2l_len equ $ - b2l
    b2g: db "k8s,net"
b2g_len equ $ - b2g
    b2c: db "kubectl port-forward svc/api 8080:80", 10
         db "curl localhost:8080/healthz"
b2c_len equ $ - b2c
    b3t: db "jq filter users"
b3t_len equ $ - b3t
    b3l: db "jq"
b3l_len equ $ - b3l
    b3g: db "json,cli"
b3g_len equ $ - b3g
    b3c: db "curl -s localhost:3000/users | jq '.[] | .name'"
b3c_len equ $ - b3c
    b_id1: db "s1"
b_id1_len equ $ - b_id1
    b_id2: db "s2"
b_id2_len equ $ - b_id2
    b_id3: db "s3"
b_id3_len equ $ - b_id3
    b_c1: db "dotfiles"
b_c1_len equ $ - b_c1
    b_c2: db "docker"
b_c2_len equ $ - b_c2
    b_c3: db "sql"
b_c3_len equ $ - b_c3
    b_cid1: db "c1"
b_cid1_len equ $ - b_cid1
    b_cid2: db "c2"
b_cid2_len equ $ - b_cid2
    b_cid3: db "c3"
b_cid3_len equ $ - b_cid3

section .bss
    file_buf:  resb FILE_MAX
    file_len:  resq 1
    sn_recs:   resb REC_SIZE * MAX_SNIPPETS
    sn_count:  resq 1
    cur_rec:   resq 1
    path_buf:  resb PATH_MAX
    load_path_buf: resb PATH_MAX
    save_path_buf: resb PATH_MAX + 64
    dir_buf:   resb PATH_MAX
    parent_buf: resb PATH_MAX
    tag_tmp:   resb 256
    tag_len:   resd 1
    coll_names: resb MAX_COLLS * COLL_NAME_LEN
    coll_lens:  resd MAX_COLLS
    coll_count: resq 1
    coll_ids:   resb MAX_COLLS * COLL_ID_LEN
    coll_cats:  resq MAX_COLLS
    fk_ptr:    resq 1
    fk_len:    resd 1
    save_fd:   resd 1
    num_tmp:   resb 24
    alignb 8
    db_error:    resq 1          ; 0=ok 1=open 2=read 3=oversize 4=parse 5=lossy 6=save
    db_errno:    resq 1          ; raw negative syscall status for 1/2/6
    db_readonly: resq 1          ; 1 = in-memory state must not overwrite source
    db_lossy:    resq 1          ; 1 = valid data was dropped by fixed limits
    db_parse_err: resq 1         ; 1 = malformed/unexpected trailing input
    db_arr_open: resq 1          ; 1 = a snippets/collections array was opened
    db_doc_end: resq 1           ; cursor after parse_doc
    db_coll_end: resq 1          ; cursor after parse_colls
    overflow_probe: resb 1       ; one-byte lookahead for exact FILE_MAX reads
    save_failed: resq 1          ; 1 = an emitter hit FILE_MAX during db_save
    undo_sn_count: resq 1
    undo_coll_count: resq 1
    undo_sn:    resb REC_SIZE * MAX_SNIPPETS
    undo_coll_names: resb MAX_COLLS * COLL_NAME_LEN
    undo_coll_lens:  resd MAX_COLLS
    undo_coll_ids:   resb MAX_COLLS * COLL_ID_LEN
    undo_coll_cats:  resq MAX_COLLS
    ts_buf:   resq 2              ; timespec p/ now_ms (sec, nsec)

section .text

; u64 db_count(void)
db_count:
    mov rax, [sn_count]
    ret

; u64 now_ms(void) — milissegundos Unix via clock_gettime (fix #18).
; Unidade única p/ created/updated/exported/at, compatível com Date.now() do web.
; Preserva rbx,rsi,rdx,r8,r9,r11-r15 (syscall suja rcx,r11: r11 salvo aqui;
; rsi/rdx/r8/r9 salvos por conveniência dos callers seed/UI). Scratch: rax,rcx.
now_ms:
    push rsi
    push rdx
    push r8
    push r9
    push r11
    mov eax, 228                    ; sys_clock_gettime
    xor edi, edi                    ; CLOCK_REALTIME
    lea rsi, [ts_buf]
    syscall
    cmp rax, 0
    jne .fallback
    mov rax, [ts_buf]               ; tv_sec
    imul rax, rax, 1000             ; sec -> ms
    mov r8, rax
    mov rax, [ts_buf+8]             ; tv_nsec
    xor edx, edx
    mov ecx, 1000000
    div rcx                         ; rax = nsec/1e6 (edx=resto)
    add rax, r8
    pop r11
    pop r9
    pop r8
    pop rdx
    pop rsi
    ret
.fallback:
    mov eax, 201                    ; sys_time (s) -> ms
    xor edi, edi
    syscall
    imul rax, rax, 1000
    pop r11
    pop r9
    pop r8
    pop rdx
    pop rsi
    ret

; char *db_default_path(void) — $HOME/.cmdkeepa/db.json ou "db.json"
db_default_path:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8                      ; 2 pushes + sub 8: entrada rsp%16==8 -> 0, calls ok
    lea rdi, [home_var]
    call getenv wrt ..plt
    test rax, rax
    jz .rel
    mov rbx, rax
    lea rdi, [path_buf]
    xor ecx, ecx
.cp1:
    cmp ecx, PATH_MAX - 24
    jae .rel
    mov al, [rbx+rcx]
    mov [rdi+rcx], al
    inc ecx
    test al, al
    jnz .cp1
    dec ecx                         ; volta ao NUL
    lea rsi, [home_suffix]
.cp2:
    mov al, [rsi]
    mov [rdi+rcx], al
    inc rsi
    inc ecx
    test al, al
    jnz .cp2
    lea rax, [path_buf]
    jmp .done
.rel:
    lea rax, [rel_path]
.done:
    add rsp, 8
    pop rbx
    pop rbp
    ret

; db_prepare_dir(rdi=path const) — cria o diretório de path (mkdir de 1 nível,
; ignora EEXIST/erro). O default $HOME/.cmdkeepa pode não existir no 1o uso;
; sem isso o save falharia silenciosamente. Não cria cadeia (um nível basta).
; NUNCA modifica o buffer do chamador (fix #15): copia para dir_buf e opera
; apenas no armazenamento gravável. rax=0 ok, -1 se path overlong (sem NUL em
; PATH_MAX bytes). Não chama libc (pode rodar antes de tudo).
db_prepare_dir:
    push r12
    push r13
    mov r12, rdi
    xor ecx, ecx
.copy:
    cmp ecx, PATH_MAX
    jae .toolong
    mov al, [r12+rcx]
    mov [dir_buf+rcx], al
    inc ecx
    test al, al
    jnz .copy
    ; dir_buf agora é cópia NUL-terminada; acha a última '/'
    mov r8, -1
    xor ecx, ecx
.find:
    mov al, [dir_buf+rcx]
    test al, al
    jz .end
    cmp al, '/'
    jne .nx
    mov r8, rcx
.nx:
    inc ecx
    jmp .find
.end:
    cmp r8, 0
    jle .ok                          ; sem '/' ou raiz: nada a criar
    lea r13, [dir_buf]
    mov byte [r13+r8], 0
    mov eax, 83                     ; sys_mkdir
    mov rdi, r13
    mov esi, 493                    ; 0755
    syscall
    xor eax, eax
    jmp .ret
.ok:
    xor eax, eax
    jmp .ret
.toolong:
    mov eax, -1
.ret:
    pop r13
    pop r12
    ret

; db_clear_state — zeroes all loaded records/collections (never error flags).
db_clear_state:
    mov qword [sn_count], 0
    mov qword [coll_count], 0
    ; A stale slot from a previous load must not leak into omitted fields.
    lea rdi, [sn_recs]
    mov ecx, REC_SIZE * MAX_SNIPPETS
    xor eax, eax
    rep stosb
    lea rdi, [coll_names]
    mov ecx, MAX_COLLS * COLL_NAME_LEN
    rep stosb
    lea rdi, [coll_lens]
    mov ecx, MAX_COLLS
    rep stosd
    lea rdi, [coll_ids]
    mov ecx, MAX_COLLS * COLL_ID_LEN
    rep stosb
    lea rdi, [coll_cats]
    mov ecx, MAX_COLLS
    rep stosq
    ret

; u64 db_load(const char *path)
; Returns the snippet count, or -1 when an existing database cannot be used.
; Only a missing file seeds builtin data. Existing open/read/oversize/parse or
; lossy inputs are preserved on disk and exposed through db_error/db_readonly.
db_load:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    ; 6 pushes (par) + sub 8: entrada rsp%16==8 -> 0, calls ok (fix #19)
    mov r14, rdi                    ; path (const: nunca modificado, fix #15)
    ; valida o comprimento ANTES de mudar qualquer estado (fix #15): precisa
    ; de NUL dentro de PATH_MAX bytes, senão o save posterior falharia mudo.
    xor ecx, ecx
.pathlen:
    cmp ecx, PATH_MAX
    jae .pathfail
    mov al, [r14+rcx]
    inc ecx
    test al, al
    jnz .pathlen
    ; garante o diretório do DB (ex. ~/.cmdkeepa no 1o uso); opera em cópia
    mov rdi, r14
    call db_prepare_dir
    ; guarda cópia NUL-terminada: db_save regrava NESTE caminho (é o banco)
    mov rsi, r14
    lea rdi, [load_path_buf]
    xor ecx, ecx
.cppath:
    mov al, [rsi+rcx]
    mov [rdi+rcx], al
    inc ecx
    test al, al
    jnz .cppath

    mov qword [db_error], 0
    mov qword [db_errno], 0
    mov qword [db_readonly], 0
    mov qword [db_lossy], 0
    mov qword [db_parse_err], 0
    mov qword [db_arr_open], 0
    mov qword [db_doc_end], 0
    mov qword [db_coll_end], 0
    mov qword [sn_count], 0
    mov qword [coll_count], 0
    call db_clear_state

.open:
    mov eax, 2                      ; sys_open
    mov rdi, r14
    xor esi, esi                    ; O_RDONLY
    xor edx, edx
    syscall
    cmp rax, -4                     ; EINTR: retry open
    je .open
    cmp rax, -2                     ; ENOENT: first run, seed below
    je .seed
    cmp rax, 0
    jl .openfail
    mov ebx, eax                    ; fd

    xor r13d, r13d                  ; total
    xor r10d, r10d                  ; 1 = one-byte overflow probe
.rd:
    cmp r13, FILE_MAX
    jae .probe
    lea rsi, [file_buf]
    add rsi, r13
    mov rdx, FILE_MAX
    sub rdx, r13
    mov r10d, 0
    jmp .do
.probe:
    lea rsi, [overflow_probe]
    mov edx, 1
    mov r10d, 1
.do:
    xor eax, eax                    ; sys_read
    mov edi, ebx
    syscall
    cmp rax, 0
    jg .got
    jl .rerr
    jmp .eof
.got:
    test r10d, r10d
    jnz .toolarge
    add r13, rax
    jmp .rd
.rerr:
    cmp rax, -4                     ; EINTR: retry read
    je .rd
    mov r9, rax
    mov eax, 3                      ; sys_close
    mov edi, ebx
    syscall
    mov [db_errno], r9
    mov qword [db_error], 2
    mov qword [db_readonly], 1
    mov rax, -1
    jmp .done
.toolarge:
    mov eax, 3                      ; sys_close
    mov edi, ebx
    syscall
    mov qword [db_error], 3
    mov qword [db_readonly], 1
    mov rax, -1
    jmp .done
.eof:
    mov eax, 3                      ; sys_close
    mov edi, ebx
    syscall
    mov [file_len], r13

    lea r12, [file_buf]
    lea r15, [file_buf]             ; r15=fim LÓGICO (fix: sem isto, skip_ws
    add r15, r13                    ; usava r15 obsoleto + resto de load anterior;
                                    ; arquivo vazio lia lixo e não dava erro 4)
    call skip_ws
    cmp r12, r15
    jae .badinput
    cmp byte [r12], '{'
    jne .badinput
    lea r12, [file_buf]
    lea r15, [file_buf]
    add r15, r13
    call parse_doc
    lea r12, [file_buf]             ; collections: recomeça do início
    call parse_colls
    mov r12, [db_doc_end]
    mov rax, [db_coll_end]
    cmp rax, r12
    cmova r12, rax
    call skip_ws
    cmp r12, r15
    je .stateok
    cmp byte [r12], '}'
    jne .badinput
    inc r12
    call skip_ws
    cmp r12, r15
    jne .badinput
.stateok:
    cmp qword [db_parse_err], 0
    jne .badinput
    cmp qword [db_lossy], 0
    jne .badlossy
    mov rax, [sn_count]
    jmp .done
.openfail:
    mov [db_errno], rax
    mov qword [db_error], 1
    mov qword [db_readonly], 1
    mov rax, -1
    jmp .done
.pathfail:
    ; path overlong: nenhum estado foi mudado ainda (além de mkdir tentativo);
    ; garante buffers zerados e reporta erro de open sem tocar no disco.
    call db_clear_state
    mov byte [load_path_buf], 0
    mov qword [db_errno], -36       ; -ENAMETOOLONG
    mov qword [db_error], 1
    mov qword [db_readonly], 1
    mov rax, -1
    jmp .done
.badinput:
    call db_clear_state
    mov qword [db_error], 4
    mov qword [db_readonly], 1
    mov rax, -1
    jmp .done
.badlossy:
    call db_clear_state
    mov qword [db_error], 5
    mov qword [db_readonly], 1
    mov rax, -1
    jmp .done
.seed:
    call db_seed_builtin
    ; materializa o seed no DB já no 1o start: sem isso, ids/datas nasceriam
    ; de novo a cada abertura e o arquivo só existiria após alguma mutação.
    call db_save
    cmp rax, 0
    jge .seedok
    mov [db_errno], rax
    mov qword [db_error], 6
    mov qword [db_readonly], 1
    mov rax, -1
    jmp .done
.seedok:
    mov rax, [sn_count]
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; db_snapshot — saves active records/collections for rollback if db_save fails.
db_snapshot:
    mov rax, [sn_count]
    mov rdx, MAX_SNIPPETS
    cmp rax, rdx
    cmova rax, rdx
    mov [undo_sn_count], rax
    imul rcx, rax, REC_SIZE
    lea rsi, [sn_recs]
    lea rdi, [undo_sn]
    test rcx, rcx
    jz .colls
    rep movsb
.colls:
    mov rax, [coll_count]
    mov rdx, MAX_COLLS
    cmp rax, rdx
    cmova rax, rdx
    mov [undo_coll_count], rax
    imul rcx, rax, COLL_NAME_LEN
    lea rsi, [coll_names]
    lea rdi, [undo_coll_names]
    test rcx, rcx
    jz .lens
    rep movsb
.lens:
    mov ecx, eax
    lea rsi, [coll_lens]
    lea rdi, [undo_coll_lens]
    test ecx, ecx
    jz .ids
    rep movsd
.ids:
    imul rcx, rax, COLL_ID_LEN
    lea rsi, [coll_ids]
    lea rdi, [undo_coll_ids]
    test rcx, rcx
    jz .cats
    rep movsb
.cats:
    mov ecx, eax
    lea rsi, [coll_cats]
    lea rdi, [undo_coll_cats]
    test ecx, ecx
    jz .ret
    rep movsq
.ret:
    ret

; db_restore — restores the most recent db_snapshot after a failed db_save.
db_restore:
    mov rax, [undo_sn_count]
    mov [sn_count], rax
    imul rcx, rax, REC_SIZE
    lea rsi, [undo_sn]
    lea rdi, [sn_recs]
    test rcx, rcx
    jz .colls
    rep movsb
.colls:
    mov rax, [undo_coll_count]
    mov [coll_count], rax
    imul rcx, rax, COLL_NAME_LEN
    lea rsi, [undo_coll_names]
    lea rdi, [coll_names]
    test rcx, rcx
    jz .lens
    rep movsb
.lens:
    mov ecx, eax
    lea rsi, [undo_coll_lens]
    lea rdi, [coll_lens]
    test ecx, ecx
    jz .ids
    rep movsd
.ids:
    imul rcx, rax, COLL_ID_LEN
    lea rsi, [undo_coll_ids]
    lea rdi, [coll_ids]
    test rcx, rcx
    jz .cats
    rep movsb
.cats:
    mov ecx, eax
    lea rsi, [undo_coll_cats]
    lea rdi, [coll_cats]
    test ecx, ecx
    jz .ret
    rep movsq
.ret:
    ret

; ---------- helpers de parse ----------

; skip_ws — avança r12 sobre espaço/tab/LF/CR
skip_ws:
.sw:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, ' '
    je .adv
    cmp al, 9
    je .adv
    cmp al, 10
    je .adv
    cmp al, 13
    je .adv
    ret
.adv:
    inc r12
    jmp .sw
.ret:
    ret

; j_memeq(rdi=a, rsi=b, edx=len) — eax 0 se iguais
j_memeq:
    test edx, edx
    jz .eq
    xor ecx, ecx
.lp:
    mov al, [rdi+rcx]
    cmp al, [rsi+rcx]
    jne .ne
    inc ecx
    cmp ecx, edx
    jb .lp
.eq:
    xor eax, eax
    ret
.ne:
    mov eax, 1
    ret

; key_eq(rdi=a, rsi=b, edx=len) — eax 0 se iguais e dentro de [rdi,r15).
; Evita ler além do fim lógico do JSON em chaves próximas do EOF.
key_eq:
    cmp rdi, r15
    jae .no
    mov rcx, r15
    sub rcx, rdi
    cmp rcx, rdx
    jb .no
    jmp j_memeq
.no:
    mov eax, 1
    ret

; parse_u64 — r12=cursor (ws já pulado). rax=u64, cursor após dígitos, CF=0.
; Only unsigned decimal digits are valid JSON here; signs and empty numbers set CF.
; Bounded (fix #14): overflow, fração/expoente e token incompleto rejeitados
; via db_parse_err+CF em vez de wrap/transformação silenciosa.
parse_u64:
    xor eax, eax
    mov r10, r12
    cmp r12, r15
    jae .bad
    cmp byte [r12], '-'
    je .bad
    cmp byte [r12], '+'
    je .bad
.lp:
    cmp r12, r15
    jae .tokend
    movzx ecx, byte [r12]
    sub ecx, '0'
    cmp ecx, 9
    ja .tokend
    ; overflow check: rax > (2^64-1-d)/10 ?
    mov rdx, 1844674407370955161
    cmp rax, rdx
    ja .ovf
    jb .ok
    cmp ecx, 5
    ja .ovf
.ok:
    imul rax, rax, 10
    add rax, rcx
    inc r12
    jmp .lp
.tokend:
    cmp r10, r12
    je .bad
    ; complete-token: rejeita fração/expoente e continuação alfanumérica
    ; ("12.3", "1e5", "123abc" não são u64 JSON válidos aqui)
    cmp r12, r15
    jae .ret
    movzx ecx, byte [r12]
    cmp cl, '.'
    je .badtrail
    cmp cl, 'e'
    je .badtrail
    cmp cl, 'E'
    je .badtrail
    cmp cl, '0'
    jb .ret
    cmp cl, '9'
    jbe .badtrail
    cmp cl, 'A'
    jb .ret
    cmp cl, 'Z'
    jbe .badtrail
    cmp cl, 'a'
    jb .ret
    cmp cl, 'z'
    jbe .badtrail
    cmp cl, '_'
    je .badtrail
    jmp .ret
.badtrail:
    mov qword [db_parse_err], 1
    stc
    ret
.ovf:
    mov qword [db_parse_err], 1
    stc
    ret
.ret:
    cmp r10, r12
    je .bad
    clc
    ret
.bad:
    mov qword [db_parse_err], 1
    stc
    ret

; strlen_cap(rsi=ptr, edx=cap) — eax=len até NUL ou cap
strlen_cap:
    xor eax, eax
.lp:
    cmp eax, edx
    jae .ret
    cmp byte [rsi+rax], 0
    je .ret
    inc eax
    jmp .lp
.ret:
    ret

; parse_hex4 — r12=hex digits. eax=value, r12 after 4 digits, CF=0 ok.
; Preserves r11. On failure, r12 stays at the offending digit and CF=1.
parse_hex4:
    push r11
    xor eax, eax
    mov r11d, 4
.loop:
    cmp r12, r15
    jae .fail
    movzx edx, byte [r12]
    cmp dl, '0'
    jb .fail
    cmp dl, '9'
    jbe .dig
    cmp dl, 'a'
    jb .up
    cmp dl, 'f'
    ja .fail
    sub edx, 'a' - 10
    jmp .got
.up:
    cmp dl, 'A'
    jb .fail
    cmp dl, 'F'
    ja .fail
    sub edx, 'A' - 10
    jmp .got
.dig:
    sub edx, '0'
.got:
    shl eax, 4
    or eax, edx
    inc r12
    dec r11d
    jnz .loop
    pop r11
    clc
    ret
.fail:
    pop r11
    stc
    ret

; emit_codepoint — eax=code point to [rdi+ecx], cap=esi. Returns ecx updated.
; Emits UTF-8, preserves r8/rdi/rsi, and counts unwritten bytes on overflow.
emit_codepoint:
    push r8
    mov r8d, eax
    cmp r8d, 0x7F
    jbe .one
    cmp r8d, 0x7FF
    jbe .two
    cmp r8d, 0xFFFF
    jbe .three
    cmp r8d, 0x10FFFF
    ja .repl
    jmp .four
.repl:
    mov r8d, 0xFFFD
    jmp .three
.one:
    mov eax, ecx
    inc eax
    cmp eax, esi
    ja .onefull
    mov [rdi+rcx], r8b
    inc ecx
    jmp .done
.onefull:
    inc ecx
    jmp .done
.two:
    mov eax, ecx
    add eax, 2
    cmp eax, esi
    ja .twofull
    mov eax, r8d
    shr eax, 6
    or eax, 0xC0
    mov [rdi+rcx], al
    mov eax, r8d
    and eax, 0x3F
    or eax, 0x80
    mov [rdi+rcx+1], al
    add ecx, 2
    jmp .done
.twofull:
    add ecx, 2
    jmp .done
.three:
    mov eax, ecx
    add eax, 3
    cmp eax, esi
    ja .threefull
    mov eax, r8d
    shr eax, 12
    or eax, 0xE0
    mov [rdi+rcx], al
    mov eax, r8d
    shr eax, 6
    and eax, 0x3F
    or eax, 0x80
    mov [rdi+rcx+1], al
    mov eax, r8d
    and eax, 0x3F
    or eax, 0x80
    mov [rdi+rcx+2], al
    add ecx, 3
    jmp .done
.threefull:
    add ecx, 3
    jmp .done
.four:
    mov eax, ecx
    add eax, 4
    cmp eax, esi
    ja .fourfull
    mov eax, r8d
    shr eax, 18
    or eax, 0xF0
    mov [rdi+rcx], al
    mov eax, r8d
    shr eax, 12
    and eax, 0x3F
    or eax, 0x80
    mov [rdi+rcx+1], al
    mov eax, r8d
    shr eax, 6
    and eax, 0x3F
    or eax, 0x80
    mov [rdi+rcx+2], al
    mov eax, r8d
    and eax, 0x3F
    or eax, 0x80
    mov [rdi+rcx+3], al
    add ecx, 4
    jmp .done
.fourfull:
    add ecx, 4
.done:
    pop r8
    ret

; parse_str_field(rdi=dst, esi=cap, r8=lenstore dword*)
; r12 deve apontar para '"'. Consome até após a aspa final, com unescape.
parse_str_field:
    cmp r12, r15
    jae .abort
    cmp byte [r12], '"'
    jne .abort
    inc r12
    xor ecx, ecx
.loop:
    cmp r12, r15
    jae .abort
    mov al, [r12]
    cmp al, '"'
    je .done
    cmp al, '\'
    je .esc
    cmp ecx, esi
    jae .skip1
    mov [rdi+rcx], al
.skip1:
    inc rcx
    inc r12
    jmp .loop
.esc:
    inc r12
    cmp r12, r15
    jae .abort
    mov al, [r12]
    inc r12
    cmp al, '"'
    je .emit
    cmp al, '\'
    je .emit
    cmp al, '/'
    je .emit
    cmp al, 'n'
    jne .e_r
    mov al, 10
    jmp .emit
.e_r:
    cmp al, 'r'
    jne .e_t
    mov al, 13
    jmp .emit
.e_t:
    cmp al, 't'
    jne .e_b
    mov al, 9
    jmp .emit
.e_b:
    cmp al, 'b'
    jne .e_f
    mov al, 8
    jmp .emit
.e_f:
    cmp al, 'f'
    jne .e_u
    mov al, 12
    jmp .emit
.e_u:
    cmp al, 'u'
    jne .emit                       ; escape desconhecido: usa o char cru
    push r9                         ; hex usa r9/r10 (tags loop os usa!)
    push r10
    sub rsp, 8                      ; 2 pushes + sub: calls alinhados (fix #19)
    call parse_hex4
    jc .baduni
    mov r9d, eax
    cmp r9d, 0xD800
    jb .uni
    cmp r9d, 0xDBFF
    jbe .high
    cmp r9d, 0xDFFF
    jbe .baduni
    jmp .uni
.high:
    mov r10d, r9d
    mov rax, r15
    sub rax, r12
    cmp rax, 6
    jb .baduni
    cmp byte [r12], '\'
    jne .baduni
    cmp byte [r12+1], 'u'
    jne .baduni
    add r12, 2
    call parse_hex4
    jc .baduni
    cmp eax, 0xDC00
    jb .baduni
    cmp eax, 0xDFFF
    ja .baduni
    and r10d, 0x3FF
    shl r10d, 10
    and eax, 0x3FF
    or r10d, eax
    add r10d, 0x10000
    mov r9d, r10d
    jmp .uni
.baduni:
    mov r9d, 0xFFFD
.uni:
    mov eax, r9d
    cmp eax, 0                      ; NUL cannot live in NUL-terminated fields
    jne .nonzero
    mov eax, 0xFFFD
.nonzero:
    call emit_codepoint
    add rsp, 8
    pop r10
    pop r9
    jmp .loop
.emit:
    cmp ecx, esi
    jae .skip2
    mov [rdi+rcx], al
.skip2:
    inc rcx
    jmp .loop
.done:
    inc r12
    mov eax, ecx
    cmp ecx, esi
    jbe .store
    mov qword [db_lossy], 1
    mov eax, esi
.store:
    mov [r8], eax
    mov byte [rdi+rax], 0
    ret
.abort:
    mov qword [db_parse_err], 1
    xor eax, eax
    mov [r8], eax
    mov byte [rdi], 0
    ret

; skip_value — pula string/objeto/array/literal a partir de r12
skip_value:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call skip_ws
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, '"'
    je .str
    cmp al, '{'
    je .bra
    cmp al, '['
    je .bra
.lit:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    cmp al, ','
    je .ret
    cmp al, '}'
    je .ret
    cmp al, ']'
    je .ret
    inc r12
    jmp .lit
.str:
    inc r12
.strlp:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    inc r12
    cmp al, '\'
    jne .nsq
    cmp r12, r15
    jae .ret
    inc r12
    jmp .strlp
.nsq:
    cmp al, '"'
    jne .strlp
    add rsp, 8
    ret
.bra:
    inc r12
    mov edx, 1
.bloop:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    inc r12
    cmp al, '"'
    je .inner
    cmp al, '{'
    je .open
    cmp al, '['
    je .open
    cmp al, '}'
    je .close
    cmp al, ']'
    je .close
    jmp .bloop
.open:
    inc edx
    jmp .bloop
.close:
    dec edx
    jnz .bloop
    add rsp, 8
    ret
.inner:
.il:
    cmp r12, r15
    jae .ret
    mov al, [r12]
    inc r12
    cmp al, '\'
    jne .iq
    cmp r12, r15
    jae .ret
    inc r12
    jmp .il
.iq:
    cmp al, '"'
    jne .il
    jmp .bloop
.ret:
    add rsp, 8
    ret

; expect_colon — ws ':' ws. CF=0 ok.
expect_colon:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    call skip_ws
    cmp r12, r15
    jae .fail
    cmp byte [r12], ':'
    jne .fail
    inc r12
    call skip_ws
    clc
    add rsp, 8
    ret
.fail:
    mov qword [db_parse_err], 1
    stc
    add rsp, 8
    ret

; find_key_array — fk_ptr/fk_len = chave SEM aspas. Posiciona r12 após '['. eax 1/0.
; Só aceita a chave como membro DIRETO do objeto raiz (fix #12): rastreia a
; profundidade fora de strings e ignora chaves aninhadas ("snippets" dentro de
; sub-objetos/arrays) e chaves dentro de strings. Profundidade 1 = raiz.
find_key_array:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    xor r9d, r9d                      ; depth (r9 = scratch dos callers)
.scan:
    cmp r12, r15
    jae .fail
    mov al, [r12]
    cmp al, '"'
    je .maybe
    cmp al, '{'
    je .open
    cmp al, '['
    je .open
    cmp al, '}'
    je .close
    cmp al, ']'
    je .close
    inc r12
    jmp .scan
.open:
    inc r9d
    inc r12
    jmp .scan
.close:
    test r9d, r9d
    jz .nextclose
    dec r9d
.nextclose:
    inc r12
    jmp .scan
.maybe:
    cmp r9d, 1
    jne .skipstr                     ; não é membro direto da raiz: pula a string
    mov eax, [fk_len]
    lea edx, [rax+2]              ; '"' + chave + '"' a partir de r12
    mov rcx, r15
    sub rcx, r12
    cmp rcx, rdx
    jb .fail
    lea rdi, [r12+1]
    mov rsi, [fk_ptr]
    mov edx, [fk_len]
    call key_eq
    test eax, eax
    jnz .skipstr
    mov eax, [fk_len]
    lea rcx, [r12+1]
    cmp byte [rcx+rax], '"'
    jne .skipstr
    lea r12, [rcx+rax+1]
    call skip_ws
    cmp r12, r15
    jae .fail
    cmp byte [r12], ':'
    jne .scan                       ; falso positivo — segue scan
    inc r12
    call skip_ws
    cmp r12, r15
    jae .fail
    cmp byte [r12], '['
    jne .scan
    inc r12
    mov eax, 1
    add rsp, 8
    ret
.skipstr:
    ; pula a string atual e segue
    inc r12
.sstr:
    cmp r12, r15
    jae .fail
    mov al, [r12]
    inc r12
    cmp al, '\'
    jne .sstrq
    cmp r12, r15
    jae .fail
    inc r12
    jmp .sstr
.sstrq:
    cmp al, '"'
    jne .sstr
    jmp .scan
.next:
    inc r12
    jmp .scan
.fail:
    xor eax, eax
    add rsp, 8
    ret

; parse_tags_array — r12 em '['; junta strings com escape reversível em rec+TAGS.
; Formato interno (fix #11): tags unidas por ',' cru; dentro de cada tag,
; '\' -> '\\' e ',' -> '\,'. Espaços preservados verbatim; tags vazias
; preservadas (vírgulas adjacentes/líderes/finais). R11d = first-tag (1=primeira:
; pula o separador), independente do comprimento acumulado (o bug antigo usava
; r10d==0, quebrando separators com tags vazias). Writer desfaz com a mesma regra.
; Corner conhecido: [] e [""] colidem em string vazia (lê-se como []).
parse_tags_array:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    cmp r12, r15
    jae .ret
    cmp byte [r12], '['
    jne .notarr
    inc r12
    xor r10d, r10d                  ; curlen (bytes gravados)
    mov r9d, REC_TAGS_LEN - 1       ; cap
    mov r11d, 1                     ; first=1
.tloop:
    call skip_ws
    cmp r12, r15
    jae .eof
    mov al, [r12]
    cmp al, ']'
    je .close
    cmp al, ','
    je .comma
    cmp al, '"'
    je .str
    call skip_value
    jmp .tloop
.comma:
    inc r12
    jmp .tloop
.close:
    inc r12
    jmp .fin
.str:
    lea rdi, [tag_tmp]
    mov esi, 255
    lea r8, [tag_len]
    call parse_str_field
    ; separador ',' cru antes de toda tag não-primeira (mesmo vazia)
    test r11d, r11d
    jnz .first
    cmp r10d, r9d
    jae .lossy
    lea rdi, [rbx+REC_TAGS_OFF]
    mov eax, r10d
    mov byte [rdi+rax], ','
    inc r10d
    jmp .content
.first:
    mov r11d, 0
.content:
    ; append tag_tmp com escape: '\'->'\\', ','->'\,'
    mov ecx, [tag_len]
    test ecx, ecx
    jz .tloop
    lea rsi, [tag_tmp]
    lea rdi, [rbx+REC_TAGS_OFF]
.cp:
    mov al, [rsi]
    cmp al, '\'
    je .esb
    cmp al, ','
    je .esc
    cmp r10d, r9d
    jae .trunc
    mov [rdi+r10], al
    inc r10d
    jmp .next
.esb:
    cmp r10d, r9d
    jae .trunc
    mov byte [rdi+r10], '\'
    inc r10d
    cmp r10d, r9d
    jae .trunc
    mov [rdi+r10], al               ; segunda metade do par ('\')
    inc r10d
    jmp .next
.esc:
    cmp r10d, r9d
    jae .trunc
    mov byte [rdi+r10], '\'
    inc r10d
    cmp r10d, r9d
    jae .trunc
    mov byte [rdi+r10], ','
    inc r10d
    jmp .next
.next:
    inc rsi
    dec ecx
    jnz .cp
    jmp .tloop
.lossy:
    mov qword [db_lossy], 1
    jmp .content                    ; content marcará lossy de novo; segue parse
.trunc:
    mov qword [db_lossy], 1
    ; resto da entrada é descartado (1 byte de entrada = 1 iteração)
    inc rsi
    dec ecx
    jnz .trunc
    jmp .tloop
.eof:
    mov qword [db_parse_err], 1
.fin:
    lea rdi, [rbx+REC_TAGS_OFF]
    mov eax, r10d
    cmp eax, r9d
    cmova eax, r9d
    mov [rbx+REC_GLEN_OFF], eax
    mov byte [rdi+rax], 0
.ret:
    add rsp, 8
    ret
.notarr:
    call skip_value
    add rsp, 8
    ret

; parse_object — r12 em '{', rec em rbx. Consome até '}'.
parse_object:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    inc r12
.loop:
    call skip_ws
    cmp r12, r15
    jae .eof
    mov al, [r12]
    cmp al, '}'
    je .endok
    cmp al, ','
    je .comma
    cmp al, '"'
    jne .skip1
    ; tenta as 4 chaves ([r12+1], com aspa final inclusa)
    lea rdi, [r12+1]
    lea rsi, [k_title]
    mov edx, 6
    call key_eq
    test eax, eax
    jz .f_title
    lea rdi, [r12+1]
    lea rsi, [k_code]
    mov edx, 5
    call key_eq
    test eax, eax
    jz .f_code
    lea rdi, [r12+1]
    lea rsi, [k_tags]
    mov edx, 5
    call key_eq
    test eax, eax
    jz .f_tags
    lea rdi, [r12+1]
    lea rsi, [k_lang]
    mov edx, 9
    call key_eq
    test eax, eax
    jz .f_lang
    lea rdi, [r12+1]
    lea rsi, [k_fav]
    mov edx, 9
    call key_eq
    test eax, eax
    jz .f_fav
    lea rdi, [r12+1]
    lea rsi, [k_id]
    mov edx, 3
    call key_eq
    test eax, eax
    jz .f_id
    lea rdi, [r12+1]
    lea rsi, [k_desc]
    mov edx, 12
    call key_eq
    test eax, eax
    jz .f_desc
    lea rdi, [r12+1]
    lea rsi, [k_collid]
    mov edx, 13                         ; 'collectionId"' = 13 (pegava o ':' junto!)
    call key_eq
    test eax, eax
    jz .f_collid
    lea rdi, [r12+1]
    lea rsi, [k_created]
    mov edx, 10
    call key_eq
    test eax, eax
    jz .f_created
    lea rdi, [r12+1]
    lea rsi, [k_updated]
    mov edx, 10
    call key_eq
    test eax, eax
    jz .f_updated
    lea rdi, [r12+1]
    lea rsi, [k_views]
    mov edx, 6
    call key_eq
    test eax, eax
    jz .f_views
    lea rdi, [r12+1]
    lea rsi, [k_versions]
    mov edx, 9
    call key_eq
    test eax, eax
    jz .f_versions
    call skip_value                  ; chave desconhecida: pula a string + valor
    jmp .colon_val
.skip1:
    inc r12
    jmp .loop
.comma:
    inc r12
    jmp .loop
.f_title:
    add r12, 7
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_TITLE_OFF]
    mov esi, REC_TITLE_LEN - 1
    lea r8, [rbx+REC_TLEN_OFF]
    call parse_str_field
    jmp .loop
.f_code:
    add r12, 6
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_CODE_OFF]
    mov esi, REC_CODE_LEN - 1
    lea r8, [rbx+REC_CLEN_OFF]
    call parse_str_field
    jmp .loop
.f_tags:
    add r12, 6
    call expect_colon
    jc .loop
    call parse_tags_array
    jmp .loop
.f_lang:
    add r12, 10
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_LANG_OFF]
    mov esi, REC_LANG_LEN - 1
    lea r8, [rbx+REC_LLEN_OFF]
    call parse_str_field
    jmp .loop
.f_fav:
    add r12, 10
    call expect_colon
    jc .loop
    mov rax, r15
    sub rax, r12
    cmp rax, 5
    jb .fav0
    cmp dword [r12], 0x65757274     ; "true"
    jne .favchk
    add r12, 4
    mov byte [rbx+REC_FAV_OFF], 1
    jmp .loop
.favchk:
    cmp dword [r12], 0x736C6166     ; "fals"
    jne .favskip
    cmp byte [r12+4], 'e'
    jne .favskip
    add r12, 5
.fav0:
    mov byte [rbx+REC_FAV_OFF], 0
    jmp .loop
.favskip:
    call skip_value
    mov byte [rbx+REC_FAV_OFF], 0
    jmp .loop
.f_id:
    add r12, 4
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_ID_OFF]
    mov esi, REC_ID_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_desc:
    add r12, 13
    call expect_colon
    jc .loop
    lea rdi, [rbx+REC_DESC_OFF]
    mov esi, REC_DESC_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_collid:
    add r12, 14                         ; '"collectionId"' = 14 chars
    call expect_colon
    jc .loop
    cmp r12, r15
    jae .loop
    cmp byte [r12], 'n'             ; null -> vazio
    jne .cidstr
    call skip_value
    mov byte [rbx+REC_CID_OFF], 0
    jmp .loop
.cidstr:
    lea rdi, [rbx+REC_CID_OFF]
    mov esi, REC_CID_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_created:
    add r12, 11
    call expect_colon
    jc .loop
    call parse_u64
    mov [rbx+REC_CREATED_OFF], rax
    jmp .loop
.f_updated:
    add r12, 11
    call expect_colon
    jc .loop
    call parse_u64
    mov [rbx+REC_UPDATED_OFF], rax
    jmp .loop
.f_views:
    add r12, 7
    call expect_colon
    jc .loop
    call parse_u64
    jc .loop                        ; parse_err já marcado; load falhará
    mov edx, 0xFFFFFFFF             ; mov r32 zera o alto: rdx=4294967295
    cmp rax, rdx                    ; (cmp rax,0xFFFFFFFF sign-estenderia p/ -1!)
    ja .viewsbig                    ; views é u32 (fix #14): acima disso rejeita
    mov [rbx+REC_VIEWS_OFF], eax
    jmp .loop
.viewsbig:
    mov qword [db_parse_err], 1
    mov dword [rbx+REC_VIEWS_OFF], 0xFFFFFFFF
    jmp .loop
.f_versions:
    add r12, 10
    call expect_colon
    jc .loop
    cmp r12, r15
    jae .loop
    cmp byte [r12], '['
    jne .vskip
    inc r12
.vloop:
    call skip_ws
    cmp r12, r15
    jae .veof
    mov al, [r12]
    cmp al, ']'
    je .vclosed
    cmp al, ','
    je .vcomma
    cmp al, '{'
    jne .vskip1
    mov eax, [rbx+REC_VNUM_OFF]
    cmp eax, MAX_VERSIONS
    jae .vskipobj
    ; rbx(rec) salvo em cur_rec; após o call, recarrega (sem push: 1 push
    ; quebraria o alinhamento antes do call — fix #19)
    imul rax, rax, VER_SIZE
    lea rbx, [rbx+REC_VERS_OFF+rax]
    call parse_ver_obj
    mov rbx, [cur_rec]
    mov eax, [rbx+REC_VNUM_OFF]
    inc eax
    mov [rbx+REC_VNUM_OFF], eax
    jmp .vloop
.vskipobj:
    mov qword [db_lossy], 1
    call skip_value
    jmp .vloop
.vcomma:
    inc r12
    jmp .vloop
.vclosed:
    inc r12
    jmp .loop
.veof:
    mov qword [db_parse_err], 1
    jmp .loop
.vskip1:
    inc r12
    jmp .vloop
.vskip:
    call skip_value
    jmp .loop
.colon_val:
    ; após pular chave desconhecida (string), pula : valor
    call expect_colon
    jc .loop
    call skip_value
    jmp .loop
.endok:
    inc r12
    jmp .end
.eof:
    mov qword [db_parse_err], 1
.end:
    ; defaults: title vazio -> "Untitled", lang vazia -> "plaintext"
    ; NUL explícito (fix #13): não depende do zero prévio do BSS/clear.
    cmp dword [rbx+REC_TLEN_OFF], 0
    jne .havet
    mov rax, 0x64656C7469746E55     ; "Untitled"
    mov [rbx+REC_TITLE_OFF], rax
    mov byte [rbx+REC_TITLE_OFF+8], 0
    mov dword [rbx+REC_TLEN_OFF], 8
.havet:
    cmp dword [rbx+REC_LLEN_OFF], 0
    jne .ret
    mov rax, 0x7865746E69616C70     ; "plaint ex"? "plaintext"[0..7]
    mov [rbx+REC_LANG_OFF], rax
    mov byte [rbx+REC_LANG_OFF+8], 't'
    mov byte [rbx+REC_LANG_OFF+9], 0
    mov dword [rbx+REC_LLEN_OFF], 9
.ret:
    add rsp, 8
    ret

; parse_ver_obj — r12 em '{', rbx = slot versão (code+0, at+VER_AT_OFF,
; note+VER_NOTE_OFF). Sem lens: campos NUL-terminated.
; rbx(rec do chamador) preservado via [cur_rec] (aqui rbx é scratch permitido).
parse_ver_obj:
    push r10                        ; 1 push, sem sub: calls alinhados (fix #19)
    inc r12
.loop:
    call skip_ws
    cmp r12, r15
    jae .eof
    mov al, [r12]
    cmp al, '}'
    je .endok
    cmp al, ','
    je .comma
    cmp al, '"'
    jne .skip1
    lea rdi, [r12+1]
    lea rsi, [k_code]
    mov edx, 5
    call key_eq
    test eax, eax
    jz .f_code
    lea rdi, [r12+1]
    lea rsi, [k_at]
    mov edx, 3
    call key_eq
    test eax, eax
    jz .f_at
    lea rdi, [r12+1]
    lea rsi, [k_note]
    mov edx, 5
    call key_eq
    test eax, eax
    jz .f_note
    call skip_value
    jmp .cval
.skip1:
    inc r12
    jmp .loop
.comma:
    inc r12
    jmp .loop
.f_code:
    add r12, 6
    call expect_colon
    jc .loop
    mov rdi, rbx
    mov esi, VER_CODE_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_at:
    add r12, 4
    call expect_colon
    jc .loop
    call parse_u64
    mov [rbx+VER_AT_OFF], rax
    jmp .loop
.f_note:
    add r12, 6                        ; '"note"' = 6 chars
    call expect_colon
    jc .loop
    cmp r12, r15
    jae .loop
    cmp byte [r12], 'n'             ; null -> nota vazia (indistinguível de "")
    jne .notestr
    call skip_value
    jmp .loop
.notestr:
    lea rdi, [rbx+VER_NOTE_OFF]
    mov esi, VER_NOTE_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.cval:
    call expect_colon
    jc .loop
    call skip_value
    jmp .loop
.endok:
    inc r12
    jmp .done
.eof:
    mov qword [db_parse_err], 1
.done:
.ret:
    pop r10
    ret

; parse_doc — r12=início, r15=fim. Preenche sn_recs/sn_count.
parse_doc:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    mov qword [sn_count], 0
    lea rax, [k_snip]
    mov [fk_ptr], rax
    mov dword [fk_len], 8
    call find_key_array
    test eax, eax
    jz .ret
    mov qword [db_arr_open], 1
.arr:
    call skip_ws
    cmp r12, r15
    jae .eof
    mov al, [r12]
    cmp al, ']'
    je .closed
    cmp al, ','
    je .comma
    cmp al, '{'
    jne .skip1
    mov rax, [sn_count]
    cmp rax, MAX_SNIPPETS
    jae .skipobj
    imul rax, rax, REC_SIZE
    lea rbx, [sn_recs+rax]
    mov [cur_rec], rbx
    ; limpa o slot ANTES de parsear (fix #13): reload com campos omitidos não
    ; herda id/desc/timestamps/versions/coleção do documento anterior. O
    ; db_clear_state no início do load já zera tudo; isto protege também
    ; chamadas diretas a parse_doc e re-uso de slot.
    push rdi
    push rcx
    lea rdi, [rbx]
    mov ecx, REC_SIZE
    xor eax, eax
    rep stosb
    pop rcx
    pop rdi
    mov rax, [sn_count]
    imul rax, rax, REC_SIZE
    lea rbx, [sn_recs+rax]
    mov [cur_rec], rbx
    call parse_object
    mov rax, [sn_count]
    inc rax
    mov [sn_count], rax
    jmp .arr
.eof:
    mov qword [db_parse_err], 1
    jmp .ret
.skipobj:
    mov qword [db_lossy], 1
    call skip_value
    jmp .arr
.comma:
    inc r12
    jmp .arr
.closed:
    inc r12
    mov qword [db_arr_open], 0
    jmp .ret
.skip1:
    inc r12
    jmp .arr
.ret:
    mov [db_doc_end], r12
    add rsp, 8
    ret

; seed_one(tptr,tlen, lptr,llen, gptr,glen, cptr,clen, iptr,ilen, dptr,dlen)
; 12 args: 6 em regs + 6 na pilha (caller faz sub rsp,48). dptr/dlen =
; collectionId (NUL-terminated no rec; vazio = unfiled).
seed_one:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                      ; 6 pushes + sub 8: entrada rsp%16==8 -> 0, calls ok
    sub rsp, 32                     ; spill area reservada ANTES do branch de
                                    ; capacidade (fix #20: .ret inicial somava 32
                                    ; sem ter subtraído, corrompendo a pilha)
    mov rax, [sn_count]
    cmp rax, MAX_SNIPPETS
    jae .ret
    imul rax, rax, REC_SIZE
    lea rbx, [sn_recs+rax]
    mov r12, [rbp+16]               ; cptr
    mov r13d, [rbp+24]              ; clen
    mov r14, [rbp+32]               ; iptr
    mov r15d, [rbp+40]              ; ilen
    ; spill: rep movsb destrói rcx/rsi/rdi — salva args restantes
    mov [rsp], rdx                  ; lsrc
    mov [rsp+8], rcx                ; llen
    mov [rsp+16], r8                ; gsrc
    mov [rsp+24], r9                ; glen
    ; title: rdi=src esi=len
    mov r10, rdi
    mov r11d, esi
    lea rdi, [rbx+REC_TITLE_OFF]
    mov rsi, r10
    mov eax, r11d
    mov edx, REC_TITLE_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_TLEN_OFF], eax
    mov ecx, eax
    jecxz .t0
    rep movsb
.t0:
    mov byte [rdi], 0
    ; lang: lsrc/llen do spill
    mov r10, [rsp]
    mov r11d, [rsp+8]
    lea rdi, [rbx+REC_LANG_OFF]
    mov rsi, r10
    mov eax, r11d
    mov edx, REC_LANG_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_LLEN_OFF], eax
    mov ecx, eax
    jecxz .l0
    rep movsb
.l0:
    mov byte [rdi], 0
    ; tags: gsrc/glen do spill
    mov r10, [rsp+16]
    mov r11d, [rsp+24]
    lea rdi, [rbx+REC_TAGS_OFF]
    mov rsi, r10
    mov eax, r11d
    mov edx, REC_TAGS_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_GLEN_OFF], eax
    mov ecx, eax
    jecxz .g0
    rep movsb
.g0:
    mov byte [rdi], 0
    ; code: r12=src r13d=len
    lea rdi, [rbx+REC_CODE_OFF]
    mov rsi, r12
    mov eax, r13d
    mov edx, REC_CODE_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov [rbx+REC_CLEN_OFF], eax
    mov ecx, eax
    jecxz .c0
    rep movsb
.c0:
    mov byte [rdi], 0
    mov byte [rbx+REC_FAV_OFF], 0
    ; id
    lea rdi, [rbx+REC_ID_OFF]
    mov rsi, r14
    mov eax, r15d
    mov edx, REC_ID_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov ecx, eax
    jecxz .i0
    rep movsb
.i0:
    mov byte [rdi], 0
    ; resto zerado pelo BSS; datas = agora
    mov byte [rbx+REC_DESC_OFF], 0
    ; cid: r12/r13 (code) já mortos aqui
    mov r12, [rbp+48]
    mov r13d, [rbp+56]
    lea rdi, [rbx+REC_CID_OFF]
    mov rsi, r12
    mov eax, r13d
    mov edx, REC_CID_LEN - 1
    cmp eax, edx
    cmova eax, edx
    mov ecx, eax
    jecxz .cid0
    rep movsb
.cid0:
    mov byte [rdi], 0
    mov dword [rbx+REC_VIEWS_OFF], 0
    mov dword [rbx+REC_VNUM_OFF], 0
    call now_ms                       ; ms Unix (fix #18; preserva r11/rbx)
    mov [rbx+REC_CREATED_OFF], rax
    mov [rbx+REC_UPDATED_OFF], rax
    mov rax, [sn_count]
    inc rax
    mov [sn_count], rax
.ret:
    add rsp, 32
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

; db_seed_builtin — 3 snippets demo quando sem arquivo
db_seed_builtin:
    push rbp
    mov rbp, rsp
    mov qword [sn_count], 0
    mov qword [coll_count], 0
    ; seed_one recebe cptr/clen/iptr/ilen/dptr/dlen na pilha (48B)
    sub rsp, 48
    lea rdi, [b1t]
    mov esi, b1t_len
    lea rdx, [b1l]
    mov ecx, b1l_len
    lea r8, [b1g]
    mov r9d, b1g_len
    lea rax, [b1c]
    mov [rsp], rax
    mov qword [rsp+8], b1c_len
    lea rax, [b_id1]
    mov [rsp+16], rax
    mov qword [rsp+24], b_id1_len
    lea rax, [b_cid2]
    mov [rsp+32], rax
    mov qword [rsp+40], b_cid2_len
    call seed_one
    lea rdi, [b2t]
    mov esi, b2t_len
    lea rdx, [b2l]
    mov ecx, b2l_len
    lea r8, [b2g]
    mov r9d, b2g_len
    lea rax, [b2c]
    mov [rsp], rax
    mov qword [rsp+8], b2c_len
    lea rax, [b_id2]
    mov [rsp+16], rax
    mov qword [rsp+24], b_id2_len
    lea rax, [b_cid1]
    mov [rsp+32], rax
    mov qword [rsp+40], b_cid1_len
    call seed_one
    lea rdi, [b3t]
    mov esi, b3t_len
    lea rdx, [b3l]
    mov ecx, b3l_len
    lea r8, [b3g]
    mov r9d, b3g_len
    lea rax, [b3c]
    mov [rsp], rax
    mov qword [rsp+8], b3c_len
    lea rax, [b_id3]
    mov [rsp+16], rax
    mov qword [rsp+24], b_id3_len
    lea rax, [b_cid3]
    mov [rsp+32], rax
    mov qword [rsp+40], b_cid3_len
    call seed_one
    add rsp, 48
    lea rsi, [b_c1]
    mov edx, b_c1_len
    lea r8, [b_cid1]
    mov r9d, b_cid1_len
    call seed_coll_one
    lea rsi, [b_c2]
    mov edx, b_c2_len
    lea r8, [b_cid2]
    mov r9d, b_cid2_len
    call seed_coll_one
    lea rsi, [b_c3]
    mov edx, b_c3_len
    lea r8, [b_cid3]
    mov r9d, b_cid3_len
    call seed_coll_one
    pop rbp
    ret

; seed_coll_one(rsi=name, edx=namelen, r8=idptr, r9d=idlen) — leaf, sem calls
; syscall só clobbera rax/rcx/r11: args em rsi/rdx/r8/r9 sobrevivem.
seed_coll_one:
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .ret
    mov r10, rax                    ; idx
    push rax                        ; alinha p/ call (entrada rsp%16==8)
    call now_ms                     ; ms Unix, preserva rsi/rdx/r8/r9/r11
    mov [coll_cats+r10*8], rax
    pop rax
    imul rax, r10, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    mov eax, edx
    mov ecx, COLL_NAME_LEN - 1
    cmp eax, ecx
    cmova eax, ecx
    mov [coll_lens+r10*4], eax
    mov ecx, eax
    jecxz .noname
    rep movsb
.noname:
    mov byte [rdi], 0
    ; id
    imul rax, r10, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    mov rsi, r8
    mov eax, r9d
    mov ecx, COLL_ID_LEN - 1
    cmp eax, ecx
    cmova eax, ecx
    mov ecx, eax
    jecxz .noid
    rep movsb
.noid:
    mov byte [rdi], 0
    mov rax, [coll_count]
    inc rax
    mov [coll_count], rax
.ret:
    ret

; ---------- collections ----------

; parse_coll_obj — r12 em '{'. Extrai "name" p/ slot coll_count (ou descarta).
parse_coll_obj:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    inc r12
.loop:
    call skip_ws
    cmp r12, r15
    jae .eof
    mov al, [r12]
    cmp al, '}'
    je .endok
    cmp al, ','
    je .comma
    cmp al, '"'
    jne .skip1
    lea rdi, [r12+1]
    lea rsi, [k_name]
    mov edx, 5
    call key_eq
    test eax, eax
    jz .f_name
    lea rdi, [r12+1]
    lea rsi, [k_id]
    mov edx, 3
    call key_eq
    test eax, eax
    jz .f_id
    lea rdi, [r12+1]
    lea rsi, [k_created]
    mov edx, 10
    call key_eq
    test eax, eax
    jz .f_created
    call skip_value
    jmp .cval
.skip1:
    inc r12
    jmp .loop
.comma:
    inc r12
    jmp .loop
.f_name:
    add r12, 6
    call expect_colon
    jc .loop
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .discard
    mov rsi, rax
    imul rax, rax, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    lea r8, [coll_lens]
    lea r8, [r8+rsi*4]
    mov esi, COLL_NAME_LEN - 1
    call parse_str_field
    jmp .loop
.discard:
    mov qword [db_lossy], 1
    lea rdi, [tag_tmp]
    mov esi, 255
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_id:
    add r12, 4
    call expect_colon
    jc .loop
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .discard
    imul rax, rax, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    mov esi, COLL_ID_LEN - 1
    lea r8, [tag_len]
    call parse_str_field
    jmp .loop
.f_created:
    add r12, 11
    call expect_colon
    jc .loop
    call parse_u64
    mov rcx, [coll_count]
    cmp rcx, MAX_COLLS
    jae .loop
    mov [coll_cats+rcx*8], rax
    jmp .loop
.cval:
    call expect_colon
    jc .loop
    call skip_value
    jmp .loop
.endok:
    inc r12
    jmp .done
.eof:
    mov qword [db_parse_err], 1
.done:
.ret:
    add rsp, 8
    ret

; parse_colls — r12=início, r15=fim. Preenche coll_names/coll_lens/coll_count.
parse_colls:
    sub rsp, 8                      ; sem pushes: alinha p/ calls (fix #19)
    mov qword [coll_count], 0
    lea rax, [k_coll]
    mov [fk_ptr], rax
    mov dword [fk_len], 11
    call find_key_array
    test eax, eax
    jz .ret
    mov qword [db_arr_open], 1
.arr:
    call skip_ws
    cmp r12, r15
    jae .eof
    mov al, [r12]
    cmp al, ']'
    je .closed
    cmp al, ','
    je .comma
    cmp al, '{'
    jne .skip1
    mov rax, [coll_count]
    cmp rax, MAX_COLLS
    jae .skipobj
    ; limpa o slot ANTES de parsear (fix #13): nome/id/createdAt de um load
    ; anterior não vazam para registros com campos omitidos.
    mov r8, rax
    imul rax, rax, COLL_NAME_LEN
    lea rdi, [coll_names+rax]
    push rcx
    mov ecx, COLL_NAME_LEN
    xor eax, eax
    rep stosb
    pop rcx
    mov eax, r8d
    mov dword [coll_lens+rax*4], 0  ; garante 0 até o parse do nome
    imul rax, r8, COLL_ID_LEN
    lea rdi, [coll_ids+rax]
    push rcx
    mov ecx, COLL_ID_LEN
    xor eax, eax
    rep stosb
    pop rcx
    mov qword [coll_cats+r8*8], 0
    call parse_coll_obj
    mov rax, [coll_count]
    inc rax
    mov [coll_count], rax
    jmp .arr
.eof:
    mov qword [db_parse_err], 1
    jmp .ret
.skip1:
    inc r12
    jmp .arr
.skipobj:
    mov qword [db_lossy], 1
    call skip_value
    jmp .arr
.comma:
    inc r12
    jmp .arr
.closed:
    inc r12
    mov qword [db_arr_open], 0
.ret:
    mov [db_coll_end], r12
    add rsp, 8
    ret

; ---------- writer JSON (subset) ----------
; Cursor de saída: r12 sobre file_buf (reuso pós-parse). Preservados: rbx,r13-r15.
; Scratch dos helpers: rax,rcx,rdx,rsi,rdi,r8,r9,r11.

; emit_byte — al -> saída
emit_byte:
    cmp r12, FILE_MAX - 1
    jae .full
    lea rcx, [file_buf]
    mov [rcx+r12], al
    inc r12
    ret
.full:
    mov qword [save_failed], 1
    ret

; emit_raw(rsi=ptr, edx=len)
emit_raw:
    test edx, edx
    jz .ret
    lea rdi, [file_buf]
.loop:
    test edx, edx
    jz .ret
    cmp r12, FILE_MAX - 1
    jae .full
    mov al, [rsi]
    mov [rdi+r12], al
    inc rsi
    inc r12
    dec edx
    jmp .loop
.full:
    mov qword [save_failed], 1
.ret:
    ret

; emit_esc(rsi=ptr, edx=len) — string com escape JSON
emit_esc:
    test edx, edx
    jz .ret
    lea rdi, [file_buf]
.loop:
    test edx, edx
    jz .ret
    cmp r12, FILE_MAX - 8
    jae .full
    mov al, [rsi]
    inc rsi
    dec edx
    cmp al, '"'
    je .q
    cmp al, '\'
    je .bs
    cmp al, 10
    je .n
    cmp al, 13
    je .r
    cmp al, 9
    je .t
    cmp al, 8
    je .b
    cmp al, 12
    je .f
    cmp al, 0x20
    jae .raw
    push r11                        ; hex usa r11 (índice de loops chamadores!)
    mov byte [rdi+r12], '\'
    mov byte [rdi+r12+1], 'u'
    mov byte [rdi+r12+2], '0'
    mov byte [rdi+r12+3], '0'
    movzx r11d, al
    shr r11d, 4
    and al, 0x0F
    lea rcx, [hexdig]
    mov r11b, [rcx+r11]
    mov [rdi+r12+4], r11b
    movzx eax, al
    mov r11b, [rcx+rax]
    mov [rdi+r12+5], r11b
    pop r11
    add r12, 6
    jmp .loop
.q:  mov word [rdi+r12], 0x225C
    add r12, 2
    jmp .loop
.bs: mov word [rdi+r12], 0x5C5C
    add r12, 2
    jmp .loop
.n:  mov word [rdi+r12], 0x6E5C
    add r12, 2
    jmp .loop
.r:  mov word [rdi+r12], 0x725C
    add r12, 2
    jmp .loop
.t:  mov word [rdi+r12], 0x745C
    add r12, 2
    jmp .loop
.b:  mov word [rdi+r12], 0x625C
    add r12, 2
    jmp .loop
.f:  mov word [rdi+r12], 0x665C
    add r12, 2
    jmp .loop
.raw:
    mov [rdi+r12], al
    inc r12
    jmp .loop
.full:
    mov qword [save_failed], 1
.ret:
    ret

; emit_u64(rax=num) — decimal via num_tmp
; Preserva r11 (usado como índice por loops chamadores).
emit_u64:
    push r11
    lea rdi, [num_tmp]
    lea rcx, [num_tmp+20]
    mov rsi, rcx
    test rax, rax
    jnz .loop
    dec rsi
    mov byte [rsi], '0'
    jmp .out
.loop:
    mov r11, 10
    xor edx, edx
    div r11
    add dl, '0'
    dec rsi
    mov [rsi], dl
    test rax, rax
    jnz .loop
.out:
    mov rdx, rcx
    sub rdx, rsi
    call emit_raw
    pop r11
    ret

; i64 db_save(void) — grava o DB no MESMO caminho carregado (persistência
; real). Atômico: escreve temp único, fsync, rename -> <path>. Um crash no
; meio deixa o DB anterior intacto. Temp único por pid com O_EXCL|O_NOFOLLOW
; (fix #16): dois savers concorrentes nunca partilham o mesmo inode e symlink
; em diretório não-confiável não é seguido. Modo 0600 (seguro por padrão;
; rename preserva dono; não alarga um DB 0600 para 0644). Política single-writer:
; última rename vence; callers serializam via UI. Retorna n ou -1.
db_save:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    ; 6 pushes (par) + sub 8: entrada rsp%16==8 -> 0, calls ok (fix #19)

    cmp qword [db_readonly], 0
    jne .fail
    mov qword [save_failed], 0
    cmp byte [load_path_buf], 0
    je .fail
    ; constrói "<loadpath>.<pid>.tmp" em save_path_buf
    lea rsi, [load_path_buf]
    lea rdi, [save_path_buf]
    xor ecx, ecx
.cp:
    cmp ecx, PATH_MAX - 1
    jae .fail
    mov al, [rsi+rcx]
    mov [rdi+rcx], al
    inc ecx
    test al, al
    jnz .cp
    dec ecx                         ; ecx = len sem NUL
    ; espaço p/ "." + pid(<=10) + ".tmp"(4) + NUL dentro do buffer ampliado?
    mov eax, ecx
    add eax, 16
    cmp eax, PATH_MAX + 64
    jae .fail
    mov byte [rdi+rcx], '.'
    inc ecx
    push rcx                        ; syscall suja rcx/r11: ecx=len sobrevive
    mov eax, 39                      ; sys_getpid
    syscall
    pop rcx
    ; rax=pid -> decimal em num_tmp (reuso: emissão ainda não começou)
    lea rdi, [num_tmp]
    mov rsi, rax
    xor r9d, r9d                      ; ndig
    cmp rsi, 0
    jne .piddiv
    mov byte [rdi], '0'
    mov r9d, 1
    jmp .pidcopy
.piddiv:
    ; divide de trás p/ frente em num_tmp+20
    lea r8, [num_tmp+20]
    mov rax, rsi
.pidloop:
    xor edx, edx
    mov esi, 10
    div rsi                         ; rax=q, rdx=d
    add dl, '0'
    dec r8
    mov [r8], dl
    inc r9d
    test rax, rax
    jnz .pidloop
    ; copia os ndig de r8 p/ save_path_buf+ecx
    lea rdi, [save_path_buf]
    jmp .pidcopy2
.pidcopy:
    lea rdi, [save_path_buf]
    mov al, [num_tmp]
    mov [rdi+rcx], al
    inc ecx
    jmp .pidtmp
.pidcopy2:
    mov al, [r8]
    mov [rdi+rcx], al
    inc r8
    inc ecx
    dec r9d
    jnz .pidcopy2
.pidtmp:
    lea rsi, [tmp_suffix]           ; ".tmp" (com NUL)
.pt2:
    mov al, [rsi]
    mov [rdi+rcx], al
    inc rsi
    inc ecx
    test al, al
    jnz .pt2

    mov eax, 2                      ; sys_open
    lea rdi, [save_path_buf]
    mov esi, 131265                 ; O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW
    mov edx, 384                    ; 0600
    syscall
    cmp rax, -17                    ; -EEXIST: temp obsoleto do mesmo pid?
    jne .opencheck
    ; remove e tenta uma vez com O_EXCL de novo (crash anterior)
    mov eax, 87                     ; sys_unlink
    lea rdi, [save_path_buf]
    syscall
    mov eax, 2
    lea rdi, [save_path_buf]
    mov esi, 131265
    mov edx, 384
    syscall
.opencheck:
    cmp rax, 0
    jl .fail
    mov [save_fd], eax              ; fd em BSS: rbx vira ponteiro de rec na emissão!

    xor r12d, r12d                  ; cursor de saída
    lea rsi, [j_open]
    mov edx, j_open_len
    call emit_raw
    call now_ms                     ; exportedAt em ms (fix #18, par do Date.now)
    call emit_u64
    lea rsi, [j_mid1]
    mov edx, j_mid1_len
    call emit_raw

    mov rax, [sn_count]
    mov rdx, MAX_SNIPPETS
    cmp rax, rdx
    cmova rax, rdx
    mov r15, rax                    ; total
    xor r14d, r14d                  ; i
.sloop:
    cmp r14, r15
    jae .sdone
    test r14, r14
    jz .first
    mov al, ','
    call emit_byte
.first:
    mov rax, r14
    imul rax, rax, REC_SIZE
    lea rbx, [sn_recs+rax]
    lea rsi, [j_sopen]
    mov edx, j_sopen_len
    call emit_raw
    lea rsi, [rbx+REC_ID_OFF]
    mov edx, REC_ID_LEN
    call strlen_cap
    mov edx, eax
    call emit_esc
    lea rsi, [j_sopen2]
    mov edx, j_sopen2_len
    call emit_raw
    lea rsi, [rbx+REC_TITLE_OFF]
    mov edx, [rbx+REC_TLEN_OFF]
    cmp edx, REC_TITLE_LEN - 1
    jbe .titleok
    mov edx, REC_TITLE_LEN - 1
.titleok:
    call emit_esc
    lea rsi, [j_l1]
    mov edx, j_l1_len
    call emit_raw
    lea rsi, [rbx+REC_CODE_OFF]
    mov edx, [rbx+REC_CLEN_OFF]
    cmp edx, REC_CODE_LEN - 1
    jbe .codeok
    mov edx, REC_CODE_LEN - 1
.codeok:
    call emit_esc
    lea rsi, [j_l2]
    mov edx, j_l2_len
    call emit_raw
    lea rsi, [rbx+REC_LANG_OFF]
    mov edx, [rbx+REC_LLEN_OFF]
    cmp edx, REC_LANG_LEN - 1
    jbe .langok
    mov edx, REC_LANG_LEN - 1
.langok:
    call emit_esc
    lea rsi, [j_l3a]
    mov edx, j_l3a_len
    call emit_raw
    lea rsi, [rbx+REC_DESC_OFF]
    mov edx, REC_DESC_LEN
    call strlen_cap
    mov edx, eax
    call emit_esc
    lea rsi, [j_l3b]
    mov edx, j_l3b_len
    call emit_raw
    ; tags: formato interno com escape (fix #11) — divide em ',' NÃO-escapadas,
    ; desfaz '\,'->',' e '\\'->'\' (guardando em tag_tmp), emite cada tag como
    ; string JSON. r11d = first-tag (0 após a 1ª emitida, mesmo vazia): vírgula
    ; antes de toda tag exceto a primeira. Espaços são significativos (sem trim).
    ; Robusto: cada iteração consome >=1 byte de r10d ou emite a última -> termina.
    lea r13, [rbx+REC_TAGS_OFF]
    mov r10d, [rbx+REC_GLEN_OFF]
    cmp r10d, REC_TAGS_LEN - 1
    jbe .gok
    mov r10d, REC_TAGS_LEN - 1
.gok:
    mov r11d, 1                     ; first=1
    test r10d, r10d
    jz .tdone                       ; vazio -> []
.tloop:
    ; decodifica UM token em tag_tmp (ecx=len); consome até ',' crua ou fim
    xor ecx, ecx                    ; dlen
.tdec:
    test r10d, r10d
    jz .temit
    mov al, [r13]
    cmp al, '\'
    je .tesc
    cmp al, ','
    je .tsep
    cmp ecx, 255
    jae .trawskip
    mov [tag_tmp+rcx], al
    inc ecx
.trawskip:
    inc r13
    dec r10d
    jmp .tdec
.tesc:
    cmp r10d, 1
    jbe .trawlit                    ; '\' final solitária: literal
    mov dl, [r13+1]                 ; dl (não ah: ah+REX de r13 é inválido)
    cmp dl, ','
    je .tesc_comma
    cmp dl, '\'
    je .tesc_bs
    ; '\' + outro char (dado legado): emite '\' literal, avança 1; o char
    ; seguinte será processado na próxima iteração
.trawlit:
    cmp ecx, 255
    jae .trawskip
    mov [tag_tmp+rcx], al
    inc ecx
    jmp .trawskip
.tesc_comma:
    cmp ecx, 255
    jae .tesc_skip2
    mov byte [tag_tmp+rcx], ','
    inc ecx
.tesc_skip2:
    add r13, 2
    sub r10d, 2
    jmp .tdec
.tesc_bs:
    cmp ecx, 255
    jae .tesc_skip2
    mov byte [tag_tmp+rcx], '\'
    inc ecx
    jmp .tesc_skip2
.tsep:
    inc r13                         ; consome a ',' separadora
    dec r10d
    jmp .temit_next                 ; emite o token e continua (pode haver "" final)
.temit:
    ; fim da entrada: emite o token atual como ÚLTIMO
    ; (dlen vai p/ r8d: emit_byte/emit_esc usam rcx como scratch; push aqui
    ; quebraria o alinhamento antes dos calls — fix #19)
    mov r8d, ecx
    test r11d, r11d
    jnz .tfirst_last
    mov al, ','
    call emit_byte
.tfirst_last:
    mov r11d, 0
    mov al, '"'
    call emit_byte
    lea rsi, [tag_tmp]
    mov edx, r8d
    call emit_esc
    mov al, '"'
    call emit_byte
    jmp .tdone
.temit_next:
    ; separador encontrado: emite o token atual (não-último) e volta ao loop;
    ; se não resta nada, emite a tag vazia final ("a," -> ["a",""])
    mov r8d, ecx
    test r11d, r11d
    jnz .tfirst_mid
    mov al, ','
    call emit_byte
.tfirst_mid:
    mov r11d, 0
    mov al, '"'
    call emit_byte
    lea rsi, [tag_tmp]
    mov edx, r8d
    call emit_esc
    mov al, '"'
    call emit_byte
    test r10d, r10d
    jnz .tloop                      ; há mais entrada: decodifica a próxima
    ; entrada esgotada logo após separador: tag vazia final
    mov al, ','
    call emit_byte
    mov al, '"'
    call emit_byte
    mov al, '"'
    call emit_byte
    jmp .tdone
.tdone:
    lea rsi, [j_l4a]
    mov edx, j_l4a_len
    call emit_raw
    cmp byte [rbx+REC_CID_OFF], 0
    jne .cidstr
    lea rsi, [j_null]
    mov edx, j_null_len
    call emit_raw
    jmp .cidend
.cidstr:
    mov al, '"'
    call emit_byte
    lea rsi, [rbx+REC_CID_OFF]
    mov edx, REC_CID_LEN
    call strlen_cap
    mov edx, eax
    call emit_esc
    mov al, '"'
    call emit_byte
.cidend:
    lea rsi, [j_l4b]
    mov edx, j_l4b_len
    call emit_raw
    cmp byte [rbx+REC_FAV_OFF], 0
    je .ffalse
    lea rsi, [j_true]
    mov edx, j_true_len
    call emit_raw
    jmp .fend
.ffalse:
    lea rsi, [j_false]
    mov edx, j_false_len
    call emit_raw
.fend:
    lea rsi, [j_l5a]
    mov edx, j_l5a_len
    call emit_raw
    mov rax, [rbx+REC_CREATED_OFF]
    call emit_u64
    lea rsi, [j_l5b]
    mov edx, j_l5b_len
    call emit_raw
    mov rax, [rbx+REC_UPDATED_OFF]
    call emit_u64
    lea rsi, [j_l5c]
    mov edx, j_l5c_len
    call emit_raw
    mov eax, [rbx+REC_VIEWS_OFF]
    call emit_u64
    lea rsi, [j_l5d]
    mov edx, j_l5d_len
    call emit_raw
    ; versions
    mov r10d, [rbx+REC_VNUM_OFF]
    cmp r10d, MAX_VERSIONS
    jbe .vok
    mov r10d, MAX_VERSIONS
.vok:
    xor r11d, r11d                  ; i
.vloop:
    cmp r11d, r10d
    jae .vdone
    test r11d, r11d
    jz .vfirst
    mov al, ','
    call emit_byte
.vfirst:
    mov eax, r11d
    imul eax, eax, VER_SIZE
    lea rsi, [rbx+REC_VERS_OFF+rax]
    mov r13, rsi                    ; vcode ptr (r13 livre aqui? r13=write-total só DEPOIS — agora é scratch seguro)
    mov edx, VER_CODE_LEN
    call strlen_cap
    mov r9d, eax                    ; vlen
    lea rsi, [j_vopen]
    mov edx, j_vopen_len
    call emit_raw
    mov rsi, r13
    mov edx, r9d
    call emit_esc
    lea rsi, [j_vmid]
    mov edx, j_vmid_len
    call emit_raw
    mov rax, [r13+VER_AT_OFF]
    call emit_u64
    lea rsi, [j_vnote]
    mov edx, j_vnote_len
    call emit_raw
    lea rsi, [r13+VER_NOTE_OFF]
    mov edx, VER_NOTE_LEN
    call strlen_cap
    mov edx, eax
    call emit_esc
    lea rsi, [j_vclose]
    mov edx, j_vclose_len
    call emit_raw
    inc r11d
    jmp .vloop
.vdone:
    lea rsi, [j_l5e]
    mov edx, j_l5e_len
    call emit_raw
    inc r14
    jmp .sloop
.sdone:
    lea rsi, [j_mid2]
    mov edx, j_mid2_len
    call emit_raw
    mov rax, [coll_count]
    mov rdx, MAX_COLLS
    cmp rax, rdx
    cmova rax, rdx
    mov r15, rax
    xor r14d, r14d
.cloop:
    cmp r14, r15
    jae .cdone
    test r14, r14
    jz .cfirst
    mov al, ','
    call emit_byte
.cfirst:
    lea rsi, [j_copen]
    mov edx, j_copen_len
    call emit_raw
    mov rax, r14
    imul rax, rax, COLL_ID_LEN
    lea rsi, [coll_ids+rax]
    mov edx, COLL_ID_LEN
    call strlen_cap
    mov edx, eax
    call emit_esc
    lea rsi, [j_cmid]
    mov edx, j_cmid_len
    call emit_raw
    mov rax, r14
    imul rax, rax, COLL_NAME_LEN
    lea rsi, [coll_names+rax]
    mov rdx, r14
    mov edx, [coll_lens+rdx*4]
    cmp edx, COLL_NAME_LEN - 1
    jbe .ccok
    mov edx, COLL_NAME_LEN - 1
.ccok:
    call emit_esc
    lea rsi, [j_ccat]
    mov edx, j_ccat_len
    call emit_raw
    mov rdx, r14
    mov rax, [coll_cats+rdx*8]
    call emit_u64
    lea rsi, [j_cclose]
    mov edx, j_cclose_len
    call emit_raw
    inc r14
    jmp .cloop
.cdone:
    lea rsi, [j_end]
    mov edx, j_end_len
    call emit_raw

    mov r13, r12                    ; total a escrever
    cmp qword [save_failed], 0
    jne .fail_cleanup
    xor r14d, r14d                  ; feito
.wr:
    cmp r14, r13
    jae .ok
    mov eax, 1                      ; sys_write
    mov edi, [save_fd]
    lea rsi, [file_buf]
    add rsi, r14
    mov rdx, r13
    sub rdx, r14
    syscall
    cmp rax, 0
    jg .wrote
    cmp rax, -4                     ; EINTR: retry write
    je .wr
    jmp .fail_cleanup
.wrote:
    add r14, rax
    jmp .wr
.ok:
    ; fsync: garante os bytes no disco antes do rename (durabilidade)
.fsync:
    mov eax, 74                     ; sys_fsync
    mov edi, [save_fd]
    syscall
    cmp rax, 0
    jl .fsyncfail
    jmp .close
.fsyncfail:
    cmp rax, -4                     ; EINTR: retry fsync
    je .fsync
    jmp .fail_cleanup
.close:
    mov eax, 3                      ; sys_close
    mov edi, [save_fd]
    syscall
    cmp rax, -4                     ; EINTR: descriptor is already closed
    je .renamedone
    cmp rax, 0
    jl .fail_unlink
.renamedone:
    ; rename(tmp, db) — atômico: leitores vêem o DB antigo ou o novo, nunca
    ; um arquivo truncado
    mov eax, 82                     ; sys_rename
    lea rdi, [save_path_buf]
    lea rsi, [load_path_buf]
    syscall
    cmp rax, 0
    jl .fail_unlink
    ; fsync do diretório-pai: cobre a entrada do rename (fix #17, best-effort
    ; onde suportado; falha aqui não invalida o save já renomeado)
    ; copia load_path -> parent_buf e reduz ao diretório-pai
    lea rsi, [load_path_buf]
    lea rdi, [parent_buf]
    xor ecx, ecx
.pdcp:
    cmp ecx, PATH_MAX - 1
    jae .pdone
    mov al, [rsi+rcx]
    mov [rdi+rcx], al
    inc ecx
    test al, al
    jnz .pdcp
    ; acha a última '/' antes do NUL (ecx inclui NUL; última posição = ecx-2)
    mov r8d, ecx
    sub r8d, 2
.pdback:
    cmp r8d, 0
    jl .pdopen_dot
    cmp byte [rdi+r8], '/'
    je .pdfound
    dec r8d
    jmp .pdback
.pdfound:
    cmp r8d, 0
    jne .pdtrunc
    mov byte [rdi+1], 0             ; raiz "/": mantém a barra
    jmp .pdopen
.pdtrunc:
    mov byte [rdi+r8], 0
    jmp .pdopen
.pdopen_dot:
    mov word [rdi], 0x2E            ; "." + NUL
.pdopen:
    mov eax, 2                      ; sys_open
    mov rdi, rdi                    ; parent_buf (rdi já aponta)
    mov esi, 65536                  ; O_RDONLY|O_DIRECTORY
    xor edx, edx
    syscall
    cmp rax, 0
    jl .pdone
    mov edi, eax
    mov eax, 74                     ; sys_fsync
    syscall                         ; ignora resultado (best-effort)
    mov eax, 3                      ; sys_close
    syscall                         ; ignora resultado
.pdone:
    mov rax, [sn_count]
    jmp .done
.fail_cleanup:
    mov eax, 3
    mov edi, [save_fd]
    syscall
.fail_unlink:
    mov eax, 87                     ; sys_unlink
    lea rdi, [save_path_buf]
    syscall
.fail:
    mov rax, -1
.done:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
